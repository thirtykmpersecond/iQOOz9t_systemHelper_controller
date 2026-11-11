#!/system/bin/sh
# late_start 服务阶段执行（非阻塞），标准模式与 late-load 模式都会走到这里
MODDIR=${0%/*}
# 等待系统服务就绪，避免 pm 命令过早调用失败
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 10
sh "$MODDIR/action.sh"
