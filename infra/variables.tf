# ============================================================================
# 变量定义
# ============================================================================

variable "region" {
  description = "华为云区域"
  type        = string
  default     = "cn-north-4"
}

variable "project_name" {
  description = "资源命名前缀"
  type        = string
  default     = "minecraft-idle-server"
}

variable "availability_zone" {
  description = "可用区完整名称，如 cn-north-4a"
  type        = string
  default     = "cn-north-4a"
}

variable "ecs_flavor" {
  description = "弹性云服务器规格（2 核 4 GB，满足 2 GB 堆内存 + 系统开销）"
  type        = string
  default     = "s6.large.2"
}

variable "image_name_regex" {
  description = "公共镜像名称正则（首尾锚定，避免命中带 GPU 驱动等变体）"
  type        = string
  default     = "^Ubuntu 22.04 server 64bit$"
}

variable "system_disk_type" {
  description = "系统盘类型（必填显式决策，非 provider 默认值）"
  type        = string
  default     = "GPSSD"
}

variable "system_disk_size" {
  description = "系统盘容量（GiB），默认 40"
  type        = number
  default     = 40
}

variable "bandwidth_size" {
  description = "弹性公网 IP 带宽大小（Mbit/s，按流量计量）"
  type        = number
  default     = 5
}

variable "allowed_cidr" {
  description = "允许访问 SSH(22) 与游戏端口(25565) 的源 IP 段；部署前请收紧为本机公网 IP 或办公网段"
  type        = string
  default     = "0.0.0.0/0"
}

variable "admin_password" {
  description = "弹性云服务器登录口令（至少 8 位且含大小写字母与数字，请勿使用弱口令）；生产环境建议改用密钥对"
  type        = string
  sensitive   = true
  default     = "ChangeMe_2026!Mc"
}

variable "server_ram_mb" {
  description = "Minecraft 服务器堆内存（MB），需小于实例总内存"
  type        = number
  default     = 2048
}

variable "shutdown_timer_seconds" {
  description = "全部玩家断开后，等待多少秒执行自动关机（不建议低于 300 秒）"
  type        = number
  default     = 900
}

variable "server_version" {
  description = "Minecraft 服务端版本（仅用于记录，实际以下载地址为准）"
  type        = string
  default     = "1.20.4"
}

variable "server_jar_url" {
  description = "Minecraft 服务端 jar 下载地址（版本锁定）"
  type        = string
  default     = "https://piston-data.mojang.com/v1/objects/8dd1a28015f51b1803213892b50b7b4fc76e594d/server.jar"
}

variable "server_jar_sha1" {
  description = "Minecraft 服务端 jar 的 SHA1 校验和（下载后强制校验）"
  type        = string
  default     = "8dd1a28015f51b1803213892b50b7b4fc76e594d"
}
