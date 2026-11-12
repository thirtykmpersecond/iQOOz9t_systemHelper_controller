# iQOO z9t SystemHelper Controller

面向 KernelSU **late-load（越狱模式）**的隐私加固模块：卸载/停用厂商遥测组件，并通过 hosts 兜底阻断上报域名。全部操作可逆，不写系统分区、不依赖解锁 BL。

## 它做三件事

1. **`pm uninstall --user 0` 强制卸载**（`packages-uninstall.list`）：针对 suspend 无法阻止采集的系统包（实测 SystemHelper 挂起后仍每 30–60 分钟写库）。只对主用户标记卸载，系统分区 APK 保留；模块每次执行时检测，若被 OTA 恢复安装则自动再次卸载
2. **`pm suspend` 停用组件**（`packages-core.list`）：状态写入 `/data`，重启后依然有效；卸载模块时自动 `unsuspend` 恢复
3. **hosts bind mount**：把自带 hosts 挂到 `/system/etc/hosts`（bind mount，不改物理分区），阻断已验证的遥测域名；late-load 失效期间由卸载/挂起状态兜底

> **为什么不需要"模拟 adb"**：`adb shell` 只是一个 uid 2000 的 shell，`pm` 命令实际由系统 PackageManagerService 执行。KSU 模块脚本以 root（uid 0）运行，是 shell 的权限超集，`pm uninstall --user 0` 可直接调用。

触发时机：`late-load.sh`（late-load 阶段）、`service.sh`（late_start 服务）、`boot-completed.sh`（开机完成后加固，防 OTA 恢复），三者都调用 `action.sh`。

## 版本历史

### v2.1.0

- 新增 `packages-uninstall.list` 强制卸载机制：每次执行先检测清单内系统包是否对 user 0 安装，若被 OTA 等机制复活则自动 `pm uninstall --user 0`
- SystemHelper 从 suspend 清单移至卸载清单——11-12 实测证据：该包 `suspended=true` 期间 signalhelper 库仍持续写入整夜（30–60 分钟/条），OriginOS 仍向带 SYSTEM 标志的厂商包派发闹钟/广播，AOSP suspend 冻结不彻底；卸载后进程、闹钟、流量、appops 全部归零
- `uninstall.sh` 增加回滚：删除模块时自动 `cmd package install-existing --user 0` 恢复卸载清单中的包
- hosts 38 域名与其余 7 包的 suspend 逻辑不变

### v2.0.0

- 新增 21 个经代码级验证的遥测域名：
  - `stsdk.vivo.com.cn`（vivo analytics 基础端点，34 个系统包引用）
  - `vhs.wwstat.com` / `vhs.vivo.com.cn`（遥测 SDK 内嵌 httpdns 的统计/寻址主机，83/64 个系统包引用）
  - 海外 `vivoglobal.com` stsdk 监控族 18 个（asia/in/ru 三区的 commonitor、monitor、onrt/ort/pnrt/prt、exstsdk、stsdk-config）
- hosts 全部条目双写 IPv4/IPv6 回环，防 AAAA 绕过
- 注释标注共享 uid(1000) 包的 suspend 限制
- **经源码核查后明确排除**（名字有迷惑性，实际是功能域，阻断会伤功能）：
  - `usrsys.vivo.com.cn` —— vivo 账号 SSO 令牌认证（getOpenToken/validateVivoToken），封了会导致 60 个包的账号登录失败
  - `picanalysis.vivo.com.cn` —— AI 智慧视觉/商品识别功能端点
  - `vmd.*.vivo.com.cn` / `vivoglobal.com` —— 厂商推送令牌分发（/api/tkdist），封了断推送通道
  - `sysupgrade` / `appupgrade` —— 系统与应用更新
  - `account*` / `appstore*` / `vivopay` / `httpdns` / `resource-api` / `rommc` / `romsp` —— 账号、商店、支付、DNS、资源、配置等功能域

### v1.0.0

- suspend 8 个核心包；阻断联通 SystemHelper 明文上报 `dm.wo.com.cn` 与中国区 stsdk/onelog/ue 遥测族（17 个域名）

## 强制卸载清单（packages-uninstall.list）

| 包 | 作用 | 处置方式与实测 |
|---|---|---|
| com.mobiletools.systemhelper | 运营商终端管理组件，反射隐藏 API 采集双 IMEI/基站/定位，30 分钟周期外发（联通明文通道 + 内嵌百度定位 SDK 双通道） | `uninstall --user 0`；卸载后进程/闹钟归零、netstats 零记账、数据目录移除；系统分区 APK 保留可恢复 |

检测命令（模块内部使用，精确判断 user 0 安装态；不能用 `pm path`，系统包即使卸载仍可能返回分区路径）：

```sh
pm list packages --user 0 | grep -q "^package:com.mobiletools.systemhelper$"
```

## 停用清单（packages-core.list）

| 包 | 作用 | 实测结果 |
|---|---|---|
| com.vivo.hybrid | 快应用运行时（广告/静默安装载体） | 独立 uid，suspend 有效 |
| com.vivo.magazine | 锁屏杂志 | 独立 uid，suspend 有效 |
| com.vivo.upnpserver | 局域网 UPnP/DLNA | 独立 uid，suspend 有效 |
| com.bbk.iqoo.logsystem | 日志系统 | 独立 uid，suspend 有效 |
| com.vivo.abe | Smart Engine：电源/配置中枢 + 遥测/广告标识建档 | **uid 1000 共享，框架拒绝 suspend，靠 hosts 阻断外发** |
| com.android.bbklog | 日志采集回传 | uid 1000，同上 |
| com.vivo.daemonService | 45+ 系统小功能宿主（语音唤醒/查找手机/儿童模式等） | uid 1000，pm suspend 直接失败；**不建议 disable**，仅封遥测域 |

`packages-optional.list` 是有功能代价的可选项（推送/商店/浏览器/反诈/查找手机），默认全部注释，需要时自行启用。

## 安装

- KernelSU 管理器 → 模块 → 从本地安装 → 选择 release zip，然后执行一次 soft reboot（用户空间重启可保留 late-load root）
- 或 root shell：

```sh
mkdir -p /data/adb/modules/privacy.guard.iqoo
# 解压 zip 内容到该目录后
ksud late-load        # 或直接 sh /data/adb/modules/privacy.guard.iqoo/action.sh
```

## 验证

```sh
ksud module list                     # 期望 enabled=true, mount=true, update=false
cat /data/local/tmp/privacy-guard.log
pm list packages --user 0 | grep systemhelper   # 期望无输出（已对 user 0 卸载）
mount | grep etc/hosts               # 期望 bind mount 存在
ping -c1 dm.wo.com.cn                # 期望解析到 127.0.0.1
```

## 恢复 / 卸载

- 单包恢复（suspend）：`pm unsuspend <包名>`
- 单包恢复（卸载清单）：`cmd package install-existing --user 0 <包名>`
- 完全恢复：KernelSU 管理器删除模块（自动 unsuspend、恢复卸载清单中的包并 umount），或 root shell `ksud module uninstall privacy.guard.iqoo`
- 卸载脚本 `uninstall.sh` 会自动回滚全部改动

## 边界与注意

- **持久性分层**：卸载/suspend 状态在 /data，硬重启也保留；hosts 挂载与模块脚本依赖 late-load root，硬重启后需重新越狱才恢复域名屏蔽与 OTA 复活自动卸载
- 共享 system uid(1000) 的系统包无法被 suspend，这是 Android 框架限制，非模块缺陷
- OTA 后 SystemHelper 可能重新对 user 0 安装：重新越狱后模块会在 action.sh 阶段自动再次卸载；未越狱期间存在窗口期
- hosts 只对走系统 DNS 的请求生效；建议叠加私人 DNS（AdGuard/NextDNS 等）覆盖开机窗口与 httpdns 场景
- 本模块不收集、不转发任何数据；所有逻辑可在脚本中直接审计
