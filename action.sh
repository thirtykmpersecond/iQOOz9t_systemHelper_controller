#!/system/bin/sh
# 公共执行逻辑，被 late-load.sh / service.sh / boot-completed.sh 调用
# 运行环境：KernelSU BusyBox ash 独立模式，root 权限
MODDIR=${0%/*}
LOG=/data/local/tmp/privacy-guard.log
HOSTS_SRC="$MODDIR/system/etc/hosts"
HOSTS_DST=/system/etc/hosts

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOG"; }

log INFO "===== privacy-guard run, mode=${KSU_RUNTIME_MODE:-unknown}, late=${KSU_LATE_LOAD:-0} ====="

# 1) 停用核心清单中的包（pm suspend：可恢复，状态持久化在 /data）
if [ -f "$MODDIR/packages-core.list" ]; then
  while IFS= read -r pkg; do
    case "$pkg" in ''|\#*) continue ;; esac
    if pm path "$pkg" >/dev/null 2>&1; then
      if pm suspend "$pkg" >/dev/null 2>&1; then
        log OK "suspend $pkg"
      else
        log WARN "suspend failed: $pkg"
      fi
    else
      log INFO "not installed, skip: $pkg"
    fi
  done < "$MODDIR/packages-core.list"
fi

# 2) hosts 兜底屏蔽（bind mount，不修改 /system 物理文件；late-load 前的开机窗口由 suspend 兜底）
if [ -f "$HOSTS_SRC" ]; then
  if ! mount | grep -q " $HOSTS_DST "; then
    chcon u:object_r:system_file:s0 "$HOSTS_SRC" 2>/dev/null
    if mount --bind "$HOSTS_SRC" "$HOSTS_DST" 2>/dev/null; then
      log OK "hosts bind-mounted"
    else
      log WARN "hosts bind mount failed（可改用私人 DNS/路由器屏蔽）"
    fi
  else
    log INFO "hosts already mounted"
  fi
fi

log INFO "===== done ====="
