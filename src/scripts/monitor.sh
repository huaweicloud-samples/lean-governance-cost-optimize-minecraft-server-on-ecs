#!/bin/bash
# ============================================================================
# Minecraft 服务器连接监控与空闲自动关机
#
# 职责（每 CHECK_INTERVAL 秒循环一次）：
#   1. 统计 25565 端口处于 ESTABLISHED 状态的连接数（即在线玩家）
#   2. 有玩家在线：重置空闲计时器
#   3. 全部玩家断开：开始计时；空闲时长超过 SHUTDOWN_TIMER_SECONDS 后：
#        a. 调用 stop 脚本，向服务器控制台发送 /stop（安全保存世界）
#        b. 等待 STOP_GRACE_SECONDS 秒确保保存完成
#        c. 关闭弹性云服务器（关机后计算资源随之释放，按需启停）
#
# 说明：本脚本以 root 运行（关机需要系统权限），仅执行「读连接数 /
#       发送 /stop / 关机」三类固定动作，不监听任何网络端口。
# ============================================================================

CONFIG_FILE="/opt/minecraft/config"
SERVER_DIR="/opt/minecraft/server"
GAME_PORT=25565
DEFAULT_SHUTDOWN_TIMER=900        # 默认空闲 15 分钟后关机
CHECK_INTERVAL=30                 # 连接检查间隔（秒）
STOP_GRACE_SECONDS=20             # /stop 后等待世界保存的宽限时间（秒）

# ---- 读取空闲关机阈值（配置缺失或非法时回退默认值）----
SHUTDOWN_TIMER_SECONDS=$DEFAULT_SHUTDOWN_TIMER
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi
if ! [[ "$SHUTDOWN_TIMER_SECONDS" =~ ^[0-9]+$ ]] || [ "$SHUTDOWN_TIMER_SECONDS" -le 0 ]; then
    SHUTDOWN_TIMER_SECONDS=$DEFAULT_SHUTDOWN_TIMER
fi

echo "[monitor] 监控启动：游戏端口 ${GAME_PORT}，检查间隔 ${CHECK_INTERVAL}s，空闲关机阈值 ${SHUTDOWN_TIMER_SECONDS}s"

lastdisconnect=0
while true; do
    connections=$(ss -ant state established 2>/dev/null | grep -c ":${GAME_PORT}")

    if [ "$connections" -eq 0 ]; then
        now=$(date +%s)
        if [ "$lastdisconnect" -eq 0 ]; then
            echo "[monitor] $(date '+%F %T') 无玩家在线，开始空闲计时"
            lastdisconnect=$now
        else
            elapsed=$((now - lastdisconnect))
            echo "[monitor] $(date '+%F %T') 持续无玩家：已空闲 ${elapsed}/${SHUTDOWN_TIMER_SECONDS}s"
            if [ "$elapsed" -ge "$SHUTDOWN_TIMER_SECONDS" ]; then
                echo "[monitor] 达到空闲阈值，执行安全关机流程"
                "$SERVER_DIR/stop"
                sleep "$STOP_GRACE_SECONDS"
                shutdown -h now
                break
            fi
        fi
    else
        echo "[monitor] $(date '+%F %T') 在线连接数：${connections}"
        lastdisconnect=0
    fi

    sleep "$CHECK_INTERVAL"
done
