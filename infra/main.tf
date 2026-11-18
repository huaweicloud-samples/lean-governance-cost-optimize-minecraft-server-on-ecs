# ============================================================================
# Minecraft Java 服务器空闲自动关机 — 主入口
#
# 架构：VPC / 子网 / 安全组 + 弹性公网 IP + 弹性云服务器（Ubuntu 22.04）
#   实例首次启动经 user_data 自动完成：
#     安装 Java 17 → 写入运行配置 → 落盘 start/stop/monitor 脚本与 systemd 单元
#     → 下载并校验 Minecraft 服务端 → 启动游戏服务与空闲监控服务
# ============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = ">= 1.96"
    }
  }
}

provider "huaweicloud" {
  region = var.region
  # AK/SK 从环境变量读取，不硬编码：
  #   export HW_ACCESS_KEY="<AK>"
  #   export HW_SECRET_KEY="<SK>"
}

# ---------------------------------------------------------------------------
# 网络：私有网络、子网、安全组
# ---------------------------------------------------------------------------

resource "huaweicloud_vpc" "main" {
  name                  = "${var.project_name}-vpc"
  cidr                  = "10.0.0.0/16"
  enterprise_project_id = null
}

resource "huaweicloud_vpc_subnet" "main" {
  name       = "${var.project_name}-subnet"
  vpc_id     = huaweicloud_vpc.main.id
  cidr       = "10.0.1.0/24"
  gateway_ip = "10.0.1.1"
}

resource "huaweicloud_networking_secgroup" "main" {
  name        = "${var.project_name}-sg"
  description = "Minecraft 服务器安全组：仅放行运维 SSH 与游戏端口"
}

# 运维 SSH 入口（来源受 allowed_cidr 约束）
resource "huaweicloud_networking_secgroup_rule" "allow_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allowed_cidr
  security_group_id = huaweicloud_networking_secgroup.main.id
}

# 游戏端口（Minecraft Java 版默认 25565，玩家接入）
resource "huaweicloud_networking_secgroup_rule" "allow_game" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 25565
  port_range_max    = 25565
  remote_ip_prefix  = var.allowed_cidr
  security_group_id = huaweicloud_networking_secgroup.main.id
}

# 出方向使用安全组默认全放行，不显式重复创建（华为云安全组默认行为）

# ---------------------------------------------------------------------------
# 公网入口：弹性公网 IP（按流量计量，实例借其出网与对外提供游戏服务）
# ---------------------------------------------------------------------------

resource "huaweicloud_vpc_eip" "main" {
  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "${var.project_name}-bw"
    size        = var.bandwidth_size
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

# ---------------------------------------------------------------------------
# 计算：运行 Minecraft 服务端的弹性云服务器
# ---------------------------------------------------------------------------

data "huaweicloud_images_image" "ubuntu" {
  name_regex  = var.image_name_regex
  most_recent = true
}

resource "huaweicloud_compute_instance" "server" {
  name               = "${var.project_name}-ecs"
  flavor_name        = var.ecs_flavor
  availability_zone  = var.availability_zone
  image_id           = data.huaweicloud_images_image.ubuntu.id
  security_group_ids = [huaweicloud_networking_secgroup.main.id]

  # 系统盘：类型与容量均为显式决策（非 provider 默认值）
  system_disk_type = var.system_disk_type
  system_disk_size = var.system_disk_size

  # 登录口令：敏感变量，仅用于 SSH 运维；生产环境建议改用密钥对
  admin_pass = var.admin_password

  # 绑定弹性公网 IP
  eip_id = huaweicloud_vpc_eip.main.id

  network {
    uuid = huaweicloud_vpc_subnet.main.id
  }

  # 首次启动自动完成游戏服务端部署（脚本源码见 src/scripts/，经 base64 内联）
  user_data = <<-EOT
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive

    # ---- 1. 安装 Java 17 运行时与网络/校验工具 ----
    apt-get update -y
    apt-get install -y --no-install-recommends openjdk-17-jre-headless iproute2 curl ca-certificates

    # ---- 2. 创建运行用户与目录 ----
    id minecraft >/dev/null 2>&1 || useradd --system --home-dir /opt/minecraft --shell /usr/sbin/nologin minecraft
    mkdir -p /opt/minecraft/server

    # ---- 3. 写入运行配置（堆内存 / 空闲关机阈值）----
    cat > /opt/minecraft/config <<CFG
    RAM_MB=${var.server_ram_mb}
    SHUTDOWN_TIMER_SECONDS=${var.shutdown_timer_seconds}
    CFG

    # ---- 4. 落盘运行时脚本与 systemd 单元（base64 内联，来源 src/scripts/）----
    echo '${base64encode(file("${path.module}/../src/scripts/start.sh"))}' | base64 -d > /opt/minecraft/server/start
    echo '${base64encode(file("${path.module}/../src/scripts/stop.sh"))}' | base64 -d > /opt/minecraft/server/stop
    echo '${base64encode(file("${path.module}/../src/scripts/monitor.sh"))}' | base64 -d > /opt/minecraft/server/monitor
    echo '${base64encode(file("${path.module}/../src/scripts/minecraft.service"))}' | base64 -d > /etc/systemd/system/minecraft.service
    echo '${base64encode(file("${path.module}/../src/scripts/minecraft.socket"))}' | base64 -d > /etc/systemd/system/minecraft.socket
    echo '${base64encode(file("${path.module}/../src/scripts/monitor_minecraft.service"))}' | base64 -d > /etc/systemd/system/monitor_minecraft.service
    chmod 755 /opt/minecraft/server/start /opt/minecraft/server/stop /opt/minecraft/server/monitor
    chmod 644 /etc/systemd/system/minecraft.service /etc/systemd/system/minecraft.socket /etc/systemd/system/monitor_minecraft.service

    # ---- 5. 下载 Minecraft 服务端（版本锁定 + SHA1 校验）----
    cd /opt/minecraft/server
    curl -fsSL --retry 3 -o server.jar "${var.server_jar_url}"
    echo "${var.server_jar_sha1}  server.jar" | sha1sum -c -

    # ---- 6. 接受 Minecraft 最终用户许可协议（EULA）----
    echo "eula=true" > /opt/minecraft/server/eula.txt

    # ---- 7. 修正属主并启动服务 ----
    chown -R minecraft:minecraft /opt/minecraft
    chown root:root /opt/minecraft/config
    chmod 644 /opt/minecraft/config

    systemctl daemon-reload
    systemctl enable minecraft.service
    systemctl enable monitor_minecraft.service
    systemctl start minecraft.service
    systemctl start monitor_minecraft.service

    echo "[user_data] Minecraft 服务器部署完成"
  EOT

  tags = {
    project = var.project_name
  }

  # user_data / admin_pass 为部署期或运行期可变更项，交由实例生命周期管理
  lifecycle {
    ignore_changes = [user_data, admin_pass]
  }
}
