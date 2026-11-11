# iQOO z9t SystemHelper Controller

面向 KernelSU **late-load（越狱模式）**的隐私加固模块：停用厂商遥测/广告组件，并通过 hosts 兜底阻断上报域名。全部操作可逆，不写系统分区、不依赖解锁 BL。

## 它做两件事

1. **`pm suspend` 停用组件**：状态写入 `/data`，重启后依然有效，不依赖 root；卸载模块时自动 `unsuspend` 恢复
2. **hosts bind mount**：把自带 hosts 挂到 `/system/etc/hosts`（bind mount，不改物理分区），阻断已验证的遥测域名；late-load 失效期间由 suspend 状态兜底

触发时机：`late-load.sh`（late-load 阶段）、`service.sh`（late_start 服务）、`boot-completed.sh`（开机完成后加固，防 OTA 恢复），三者都调用 `action.sh`。

## 版本历史

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

## 停用清单（packages-core.list）

| 包 | 作用 | 实测结果 |
|---|---|---|
| com.mobiletools.systemhelper | 运营商终端管理组件，反射隐藏 API 采集双 IMEI/基站/定位，30 分钟周期明文 HTTP 外发 | 独立 uid，suspend 有效，进程冻结、数据库停写 |
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
dumpsys package com.mobiletools.systemhelper | grep suspended   # 期望 suspended=true
mount | grep etc/hosts               # 期望 bind mount 存在
ping -c1 dm.wo.com.cn                # 期望解析到 127.0.0.1
```

## 恢复 / 卸载

- 单包恢复：`pm unsuspend <包名>`
- 完全恢复：KernelSU 管理器删除模块（自动 unsuspend + umount），或 root shell `ksud module uninstall privacy.guard.iqoo`
- 卸载脚本 `uninstall.sh` 会自动回滚全部改动

## 边界与注意

- **持久性分层**：suspend 状态在 /data，硬重启也保留；hosts 挂载与模块脚本依赖 late-load root，硬重启后需重新越狱才恢复域名屏蔽
- 共享 system uid(1000) 的系统包无法被 suspend，这是 Android 框架限制，非模块缺陷
- OTA 后请重新检查模块状态与组件是否被恢复
- hosts 只对走系统 DNS 的请求生效；建议叠加私人 DNS（AdGuard/NextDNS 等）覆盖开机窗口与 httpdns 场景
- 本模块不收集、不转发任何数据；所有逻辑可在脚本中直接审计
