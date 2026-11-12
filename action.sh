#!/system/bin/sh
# 公共执行逻辑，被 late-load.sh / service.sh / boot-completed.sh 调用
# 运行环境：KernelSU BusyBox ash 独立模式，root 权限
MODDIR=${0%/*}
LOG=/data/local/tmp/privacy-guard.log
HOSTS_SRC="$MODDIR/system/etc/hosts"
HOSTS_DST=/system/etc/hosts

# 双写：文件留底（供 adb 取日志），stdout 回显（供 KSU 管理器「执行」按钮展示）
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOG"; echo "[$1] $2"; }

CNT_UNINST=0; CNT_SUSP=0; CNT_WARN=0; CNT_CLEAN=0

log INFO "===== privacy-guard run, mode=${KSU_RUNTIME_MODE:-unknown}, late=${KSU_LATE_LOAD:-0} ====="

# 0) 强制卸载清单（针对 suspend 无法阻止采集的系统包，如 SystemHelper）
# 仅对 user 0 标记卸载，系统分区 APK 保留；OTA 后若复活，此处自动再次卸载
if [ -f "$MODDIR/packages-uninstall.list" ]; then
  while IFS= read -r pkg; do
    case "$pkg" in ''|\#*) continue ;; esac
    if pm list packages --user 0 2>/dev/null | grep -q "^package:$pkg$"; then
      # 先清历史 suspend 标记再卸载：shell(uid2000) 身份 unsuspend 是空操作，
      # 本脚本以 root 运行才生效；否则卸载后 restrictions 会残留 suspended=true 脏标记
      pm unsuspend "$pkg" >/dev/null 2>&1
      if pm uninstall --user 0 "$pkg" >/dev/null 2>&1; then
        log OK "uninstall-user0 $pkg"
        CNT_UNINST=$((CNT_UNINST + 1))
      else
        log WARN "uninstall failed: $pkg"
        CNT_WARN=$((CNT_WARN + 1))
      fi
    else
      CNT_CLEAN=$((CNT_CLEAN + 1))
    fi
  done < "$MODDIR/packages-uninstall.list"
fi

# 1) 停用核心清单中的包（pm suspend：可恢复，状态持久化在 /data）
if [ -f "$MODDIR/packages-core.list" ]; then
  while IFS= read -r pkg; do
    case "$pkg" in ''|\#*) continue ;; esac
    if pm path "$pkg" >/dev/null 2>&1; then
      if pm suspend "$pkg" >/dev/null 2>&1; then
        log OK "suspend $pkg"
        CNT_SUSP=$((CNT_SUSP + 1))
      else
        log WARN "suspend failed: $pkg"
        CNT_WARN=$((CNT_WARN + 1))
      fi
    else
      log INFO "not installed, skip: $pkg"
    fi
  done < "$MODDIR/packages-core.list"
fi

# 2) hosts 兜底屏蔽（bind mount，不修改 /system 物理文件；late-load 前的开机窗口由 suspend 兜底）
HOSTS_STATE=skip
if [ -f "$HOSTS_SRC" ]; then
  if mount | grep -q " $HOSTS_DST "; then
    log INFO "hosts already mounted"
    HOSTS_STATE=mounted
  else
    chcon u:object_r:system_file:s0 "$HOSTS_SRC" 2>/dev/null
    if mount --bind "$HOSTS_SRC" "$HOSTS_DST" 2>/dev/null; then
      log OK "hosts bind-mounted"
      HOSTS_STATE=mounted
    else
      log WARN "hosts bind mount failed（可改用私人 DNS/路由器屏蔽）"
      HOSTS_STATE=failed
      CNT_WARN=$((CNT_WARN + 1))
    fi
  fi
fi

# 3) 执行摘要（KSU 管理器「执行」按钮的终端里可直接看到，同时写入日志文件）
log INFO "----------------------------------------"
log INFO "Privacy Guard 执行完成："
log INFO "  本次卸载 $CNT_UNINST 个（卸载清单另有 $CNT_CLEAN 个本就处于卸载态）"
log INFO "  suspend 处理 $CNT_SUSP 个包（幂等，含已挂起）；警告 $CNT_WARN 条"
log INFO "  hosts 屏蔽：$HOSTS_STATE"
log INFO "  详细日志：$LOG"
log INFO "===== done ====="
