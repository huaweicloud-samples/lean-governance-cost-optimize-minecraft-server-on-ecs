# 部署指导书

> 目标读者：需要在华为云上部署并运维本实践的 DevOps / 运维工程师。
> 前置阅读：`docs/architecture.md`（架构与设计取舍）。

## 1. 前置条件

| 项 | 要求 |
|---|---|
| 账号 | 已开通华为云账号并完成实名认证 |
| 权限 | 具备 VPC / ECS / EIP / 安全组的创建与删除权限（Tenant Administrator 或等效） |
| 区域 | 推荐 `cn-north-4`（北京四）；可用区 `cn-north-4a` |
| Terraform | `>= 1.5.0` |
| huaweicloud Provider | `>= 1.96` |
| 本地工具 | `curl`（用于拉取服务端 jar，实例内已由 user_data 安装） |
| AK/SK | 运行时经环境变量提供，请勿写入仓库文件 |

```bash
export HW_ACCESS_KEY="<AK>"
export HW_SECRET_KEY="<SK>"
```

## 2. 部署步骤

```bash
# 1. 进入本仓库 infra 目录（相对路径）
cd infra

# 2. 复制变量示例并按需修改
cp terraform.tfvars.example terraform.tfvars

# 3. 初始化（首次执行）
terraform init

# 4. 预演变更，核对将创建的资源清单
terraform plan

# 5. 执行部署
terraform apply -auto-approve
```

**预期输出**：`Apply complete! Resources: 7 added, 0 changed, 0 destroyed.`

**部署资源清单**（共 7 个）：

| 资源 | 说明 |
|---|---|
| `huaweicloud_vpc.main` | 私有网络 10.0.0.0/16 |
| `huaweicloud_vpc_subnet.main` | 子网 10.0.1.0/24 |
| `huaweicloud_networking_secgroup.main` | 安全组 |
| `huaweicloud_networking_secgroup_rule.allow_ssh` | 入站放行 SSH（22） |
| `huaweicloud_networking_secgroup_rule.allow_game` | 入站放行游戏端口（25565） |
| `huaweicloud_vpc_eip.main` | 弹性公网 IP（按流量计量，5 Mbit/s） |
| `huaweicloud_compute_instance.server` | 游戏服务器实例（Ubuntu 22.04） |

> **公网入口告知**：本实践含弹性公网 IP（玩家接入必需）。EIP 按实际流量计量，
> 实例关机后计算资源即释放、公网 IP 仍处于保有状态；如无需保留公网入口，清理资源时一并释放即可。

**首次启动自动完成**（约 3–5 分钟，无需人工干预）：

1. 安装 OpenJDK 17 与 `iproute2` / `curl`；
2. 创建 `minecraft` 系统用户与 `/opt/minecraft/server` 目录；
3. 写入 `/opt/minecraft/config`（堆内存、空闲阈值，来自 Terraform 变量）；
4. 落盘 `start` / `stop` / `monitor` 三个脚本与三个 systemd 单元；
5. 下载 Minecraft 1.20.4 服务端并做 SHA1 校验，写入 `eula.txt`；
6. `systemctl enable --now` 拉起游戏服务与监控服务。

## 3. 部署后验证

```bash
# 1. 获取接入地址
terraform output game_server_address
# 预期输出：<弹性公网IP>:25565

# 2. 确认游戏端口可连通（本机执行）
nc -vz $(terraform output -raw eip_public_ip) 25565
# 预期输出：succeeded / open

# 3. 查看首次部署日志（任选其一）
#    a) 控制台「弹性云服务器 → 监控 → 云监控」查看实例状态为「运行中」
#    b) SSH 登录后查看 systemd 日志：
ssh root@$(terraform output -raw eip_public_ip)
journalctl -u minecraft.service --no-pager | tail -20
journalctl -u monitor_minecraft.service --no-pager | tail -5
```

预期关键日志：

```
[start] 启动 Minecraft 服务器：堆内存 -Xmx2048M -Xms2048M
[monitor] 监控启动：游戏端口 25565，检查间隔 30s，空闲关机阈值 900s
```

## 4. 日常使用

### 4.1 玩家接入

Minecraft Java 版客户端：「多人游戏 → 添加服务器」，地址填 `<弹性公网IP>:25565`。

### 4.2 关机后的重启

空闲自动关机后，实例进入「已停止」状态，世界数据保留在系统盘。重新游玩：

1. 华为云控制台 →「弹性云服务器」→ 找到实例 →「开机」；
2. 等待约 1 分钟（服务开机自启），客户端即可接入。

### 4.3 修改运行参数

```bash
# SSH 登录实例后
sudo vi /opt/minecraft/config
# 修改 RAM_MB（堆内存 MB）或 SHUTDOWN_TIMER_SECONDS（空闲关机秒数）后：
sudo systemctl restart minecraft.service monitor_minecraft.service
```

也可通过修改 `infra/terraform.tfvars` 中 `server_ram_mb` / `shutdown_timer_seconds` 后
重新 `terraform apply` 实现（下次重建实例时生效；运行中实例的参数以实例内配置为准）。

### 4.4 与游戏控制台互动

```bash
# 向游戏内广播（服务器运行中）
echo "/say 服务器将在无人时自动关机" > /run/minecraft.stdin
```

### 4.5 查看日志

```bash
journalctl -u minecraft.service -f          # 游戏服务实时日志
journalctl -u monitor_minecraft.service -f  # 监控服务实时日志
```

## 5. 清理资源

```bash
cd infra
terraform destroy -auto-approve
```

**预期输出**：`Destroy complete! Resources: 7 destroyed.`

> **避免残留**：
> - `terraform destroy` 仅释放 Terraform state 追踪的资源；
> - 世界数据位于实例系统盘，随实例一并释放；如需保留世界，请先通过 SSH 备份 `/opt/minecraft/server/world` 等目录；
> - 若曾在控制台手工创建过资源（如额外 EIP），需手动释放。

## 6. 故障排除

| 现象 | 可能原因 | 处理方法 |
|---|---|---|
| 部署后无法连接游戏端口 | 首次启动部署尚未完成（约 3–5 分钟） | `journalctl -u minecraft.service` 确认 `Done` 日志出现 |
| 客户端提示「未知服务器」| 地址填错或端口未通 | 用 `nc -vz <IP> 25565` 验证；核对 `game_server_address` 输出 |
| SSH 连不上 | `allowed_cidr` 未包含本机公网 IP | 修改 `terraform.tfvars` 的 `allowed_cidr` 后重新 apply |
| 服务端下载失败 | 实例出网异常 | SSH 登录后手动执行 `curl -I <server_jar_url>` 排查；确认 EIP 绑定正常 |
| 实例反复自动关机 | 无玩家时属预期行为 | 需要常驻时把 `SHUTDOWN_TIMER_SECONDS` 调大，或 `systemctl disable --now monitor_minecraft.service` |
| 堆内存不足导致服务重启 | `RAM_MB` 超过实例可用内存 | 将 `RAM_MB` 调低（2 核 4 GB 实例建议不超过 3072）|
| 修改配置后不生效 | 未重启服务 | `systemctl restart minecraft.service monitor_minecraft.service` |

## 7. 已知约束

- 本实践为单实例架构，世界数据仅在本地系统盘，**不提供跨实例高可用**；实例销毁即数据丢失，重要世界请定期备份。
- 关机依赖实例内 `shutdown -h now` 上报 ACPI 事件，公共镜像均支持；若实例长时间处于「关机中」，可在控制台执行强制停止。
- 服务端版本固定为 1.20.4（Java 17）；升级版本需同步更换 `server_jar_url` / `server_jar_sha1` 变量。
