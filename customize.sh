# KernelSU 模块安装脚本（BusyBox ash）
ui_print "- Privacy Guard for iQOO"
ui_print "- 模式检测: KSU_RUNTIME_MODE=$KSU_RUNTIME_MODE KSU_LATE_LOAD=$KSU_LATE_LOAD"
ui_print "- 将停用 packages-core.list 中的组件并挂载 hosts 屏蔽"
ui_print "- 全部可逆：卸载模块即恢复，日志见 /data/local/tmp/privacy-guard.log"

# 脚本权限
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/late-load.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/boot-completed.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/system/etc/hosts" 0 0 0644 u:object_r:system_file:s0

ui_print "- 安装完成。late-load 模式下重新执行一次 ksud late-load 或重启后重新越狱即生效"
