# ============================================================================
# 输出：部署后可直接用于访问与运维的关键信息
# ============================================================================

output "ecs_instance_id" {
  description = "运行 Minecraft 服务端的弹性云服务器实例 ID"
  value       = huaweicloud_compute_instance.server.id
}

output "ecs_instance_name" {
  description = "弹性云服务器实例名称"
  value       = huaweicloud_compute_instance.server.name
}

output "eip_public_ip" {
  description = "弹性公网 IP 地址（玩家接入入口）"
  value       = huaweicloud_vpc_eip.main.address
}

output "game_server_address" {
  description = "Minecraft 服务器接入地址（在游戏客户端「多人游戏 → 添加服务器」中填写）"
  value       = "${huaweicloud_vpc_eip.main.address}:25565"
}

output "ssh_login_hint" {
  description = "SSH 运维登录方式（口令见 admin_password 变量，仅本机执行机可见）"
  value       = "ssh root@${huaweicloud_vpc_eip.main.address}"
}

output "service_log_hint" {
  description = "查看游戏服务与监控服务日志的命令"
  value       = "journalctl -u minecraft.service -f  # 游戏服务；journalctl -u monitor_minecraft.service -f  # 监控服务"
}
