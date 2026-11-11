#!/system/bin/sh
# 开机完成后再加固一次，防 OTA/应用更新恢复组件状态
MODDIR=${0%/*}
sleep 30
sh "$MODDIR/action.sh"
