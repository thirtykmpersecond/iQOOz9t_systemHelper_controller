#!/system/bin/sh
# 模块卸载时恢复一切
MODDIR=${0%/*}
LOG=/data/local/tmp/privacy-guard.log
echo "$(date) uninstall: restoring" >> "$LOG"

# 恢复被停用的包
if [ -f "$MODDIR/packages-core.list" ]; then
  while IFS= read -r pkg; do
    case "$pkg" in ''|\#*) continue ;; esac
    pm unsuspend "$pkg" >/dev/null 2>&1
  done < "$MODDIR/packages-core.list"
fi

# 恢复被强制 user 0 卸载的系统包（APK 仍在系统分区，重新安装给 user 0 即可）
if [ -f "$MODDIR/packages-uninstall.list" ]; then
  while IFS= read -r pkg; do
    case "$pkg" in ''|\#*) continue ;; esac
    cmd package install-existing --user 0 "$pkg" >/dev/null 2>&1
  done < "$MODDIR/packages-uninstall.list"
fi

# 卸载 hosts bind mount
if mount | grep -q ' /system/etc/hosts '; then
  umount /system/etc/hosts 2>/dev/null
fi
echo "$(date) uninstall: done" >> "$LOG"
