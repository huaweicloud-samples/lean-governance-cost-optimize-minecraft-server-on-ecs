#!/bin/bash
# ============================================================================
# 安全停止 Minecraft 服务器
#
# 职责：
#   - 通过 systemd socket 单元创建的 FIFO 向服务器控制台写入 /stop
#   - 服务器收到 /stop 后会自动保存世界数据并退出（比直接杀进程更安全）
#   - 若服务未运行（FIFO 不存在），直接停止服务单元，避免误触发 socket 激活
# ============================================================================

STDIN_FIFO="/run/minecraft.stdin"

if [ -p "$STDIN_FIFO" ]; then
    echo "/stop" > "$STDIN_FIFO"
    echo "[stop] 已向服务器控制台发送 /stop，等待世界保存……"
else
    echo "[stop] 服务器未运行，直接停止服务单元"
    systemctl stop minecraft.service
fi
