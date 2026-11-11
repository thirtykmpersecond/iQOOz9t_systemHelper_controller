#!/system/bin/sh
# late-load 模式专用：替代标准模式的 post-fs-data.sh，在 ksud late-load 阶段阻塞执行
MODDIR=${0%/*}
sh "$MODDIR/action.sh"
