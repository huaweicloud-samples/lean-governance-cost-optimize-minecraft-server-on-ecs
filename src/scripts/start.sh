#!/bin/bash
# ============================================================================
# Minecraft Java 服务器启动入口（由 minecraft.service 调用）
#
# 职责：
#   - 从 /opt/minecraft/config 读取 RAM_MB（堆内存，单位 MB）
#   - 以前台进程方式启动 server.jar，标准输入/输出交由 systemd 托管
#     （控制台输入经 minecraft.socket 的 FIFO 注入，见 stop 脚本）
# ============================================================================

CONFIG_FILE="/opt/minecraft/config"
SERVER_DIR="/opt/minecraft/server"
DEFAULT_RAM_MB=2048

RAM_MB=$DEFAULT_RAM_MB
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi
if ! [[ "$RAM_MB" =~ ^[0-9]+$ ]] || [ "$RAM_MB" -le 0 ]; then
    RAM_MB=$DEFAULT_RAM_MB
fi

echo "[start] 启动 Minecraft 服务器：堆内存 -Xmx${RAM_MB}M -Xms${RAM_MB}M"
exec java -Xmx${RAM_MB}M -Xms${RAM_MB}M -jar "$SERVER_DIR/server.jar" nogui
