---
name: qnap-performance
description: QNAP NAS 性能优化：SMB 传输提速、Windows 11 24H2 兼容性修复、iSCSI 调优、Qtier 缓存、链路聚合、Docker 性能管理。
---

# QNAP 性能优化

> 适用范围：QTS 5.x 性能调优
> 适用场景：传输速度慢、CPU 过高、SMB 性能、Docker 响应慢

---

## 一、性能基准诊断

```sh
# CPU 和内存
uptime
free -m
cat /proc/cpuinfo | grep -E 'model name|processor' | sort -u

# 磁盘 I/O
iostat -x 1 5 2>/dev/null

# 网络接口
ip -s link show

# 整体性能快照
vmstat 1 5

# Docker 资源
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
```

---

## 二、SMB 传输速度排查（最常见性能问题）

### 2.1 诊断当前 SMB 状态

```sh
smbd --version 2>/dev/null || /usr/sbin/smbd --version 2>/dev/null
cat /etc/config/smb.conf | grep -E 'max protocol|min protocol|server signing|socket options'
smbstatus 2>/dev/null | head -30
```

### 2.2 Windows 11 24H2 导致速度骤降（高频问题）

**症状：** 速度从 75-100 MB/s 降到 10-15 MB/s，或完全无法连接。

**根本原因：** Windows 11 24H2（Build 26100+）默认强制开启 SMB 签名（Signing）。

**一步诊断（Windows 端执行）：**
```powershell
winver                                                # 确认版本是否为 24H2
Get-SmbClientConfiguration | Select RequireSecuritySignature
# 若返回 True → 就是这个问题
```

**修复方案 A（推荐，NAS 侧启用签名支持）：**
```
QTS GUI → 控制台 → 网络与文件服务 → Windows 共享 → 高级设置
→ SMB 签名 → 选择"如客户端要求则签名"
```

**修复方案 B（Windows 侧关闭强制签名，内网环境可接受）：**
```powershell
# 管理员 PowerShell 执行（无需重启，立即生效）
Set-SmbClientConfiguration -RequireSecuritySignature $false

# 或通过注册表
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 0 /f
```

**长期解决方案（最彻底）：** 为每个用户创建独立账号，彻底移除来宾（Guest）访问。这同时解决了速度和安全两个问题，完全兼容 Windows 11 24H2 的新安全策略。

**上传速度慢（写入）：** 在 10GbE 环境下，部分用户发现禁用 SMB 签名后读取恢复正常，但写入仍慢（10-15 MB/s）。此时需要额外检查：
- 交换机配置（巨帧是否一致）
- QNAP 端 SMB 签名设置（NAS 侧也需要"如客户端要求则签名"）
- 磁盘 I/O 是否成为瓶颈（`iostat -x 1 5`）

### 2.3 其他 SMB 速度问题

**问题：SMB 协议版本回退**
```sh
# 确认使用的协议版本
smbstatus 2>/dev/null | grep -i 'SMB\|protocol'
```
确保 QNAP 端启用 SMB3.1.1（控制台 → Windows 共享 → 最高协议版本 SMB3.1.1）。

**问题：Jumbo Frame 不匹配**
```sh
# 查看当前 MTU
ip link show | grep mtu
```
NAS、交换机、PC 三端 MTU 必须**全部**一致设为 9000，任何一端不支持都应保持 1500，否则性能反而更差。

**问题：大量小文件传输慢**
SMB 对每个文件有元数据请求开销，小文件（<100KB）场景下协议本身是瓶颈。备选方案：
- 用 rsync 替代 SMB 传输（更高效）
- 打包后传输
- 考虑改用 NFS（小文件场景 NFS 优于 SMB）

**问题：Office 文件保存报 Access Denied**
Office 保存时需要创建临时文件，Oplocks（文件锁）配置不当会导致冲突。
```
控制台 → 网络与文件服务 → 高级选项 → 关闭"启用不透明锁定"（Oplocks）
```

---

## 三、SMB vs iSCSI 性能对比

根据真实测试数据（QNAP TS-462A + 2.5GbE 环境）：

| 场景 | SMB | iSCSI | 建议 |
|---|---|---|---|
| 大文件（>1GB 顺序读写） | ~295 MB/s | ~265 MB/s | 用 SMB |
| 小文件（1MB x 32768） | ~98-119 MB/s | ~167-293 MB/s | 用 iSCSI |
| 多用户并发访问 | 好 | 差 | 用 SMB |
| 数据库/虚拟机（单机） | 差 | 好 | 用 iSCSI |

---

## 四、iSCSI 性能优化

```sh
/etc/init.d/iscsi-target status 2>/dev/null
ss -tlnp | grep 3260
tgtadm --lld iscsi --op show --mode target 2>/dev/null
```

**调优建议：**
- 使用**厚置备**（Thick Provisioning）而非薄置备，顺序读写性能更好
- 每个 CPU 线程建议对应一个 LUN（4核 CPU → 建议 4+ 个 LUN）
- 高负载应用各自独立 LUN，避免 I/O 竞争
- 有 RDMA 网卡时启用 iSER（延迟从 0.9ms 降至 0.5ms）

---

## 五、Qtier 自动分层存储

**适用场景：** NAS 同时安装 HDD 和 SSD，用 SSD 缓存热数据。

```sh
/usr/sbin/lvm lvs 2>/dev/null | grep -i tier
cat /proc/fs/qtier_info 2>/dev/null
lsblk | grep -v loop
```

**注意：**
- SSD 至少 2 块建议做 RAID 1（单块故障风险）
- 读缓存和写缓存分开配置效果更好
- 存储与快照管理 → 存储池 → Qtier 设置

---

## 六、链路聚合（Link Aggregation）

```sh
ip link show
ethtool eth0 2>/dev/null | grep -E 'Speed|Duplex|Link'
cat /proc/net/bonding/bond0 2>/dev/null
```

| 模式 | 说明 | 适用场景 |
|---|---|---|
| 主动-备用（Active-Backup） | 一主一备 | 高可用，不增加带宽 |
| 平衡-轮询（Round-Robin） | 轮流发送 | 多客户端场景 |
| 802.3ad LACP | 需交换机支持，最大化带宽 | 企业环境 |
| 自适应负载均衡（ALB） | 接收方负载均衡 | 不需要交换机特殊配置 |

---

## 七、Docker 性能

```sh
# 查看资源占用
docker stats --no-stream

# 空间分析
docker system df
docker system df -v
```

**清理建议（按危险程度排序）：**

```sh
docker image prune          # 悬空镜像（安全，无需确认）
docker container prune      # 已停止容器（确认后执行）
docker volume prune         # 未使用卷（⚠️ 危险，务必确认数据！）
docker system prune         # 全量清理（⚠️ 确认后执行）
```

**容器日志占满磁盘：**
```sh
# 查看最大日志容器
docker inspect <容器名> | grep LogPath
du -sh $(docker inspect --format='{{.LogPath}}' <容器名> 2>/dev/null)

# 限制日志大小（在 docker-compose.yml 中配置）
services:
  myapp:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
```

---

## 八、系统级性能监控

```sh
# CPU 实时监控
top -b -n 3 | head -30

# I/O 等待问题
grep -i 'io wait\|iowait\|ata.*error\|blk_update_request' /var/log/messages | tail -20
dmesg | grep -iE 'I/O error|ata.*error' | tail -10

# 内存不足（OOM）
grep -i 'OOM\|out of memory\|killed process' /var/log/messages | tail -10
dmesg | grep -i 'OOM\|out of memory' | tail -5
```

---

## 九、常见性能问题速查

| 症状 | 首要检查 | 解决方向 |
|---|---|---|
| Win11 升级后 SMB 速度骤降 | `winver` 确认是否 24H2 | 启用 NAS 端 SMB 签名支持，或 Win 端关闭强制签名 |
| SMB 速度 < 50 MB/s（千兆） | SMB 版本、SMB 签名 | 确认 SMB3.1.1，检查 Signing 设置 |
| SMB 速度 < 100 MB/s（万兆） | Jumbo Frame、CPU | 全链路 9K MTU，检查交换机配置 |
| Docker 容器响应慢 | `docker stats` | 分析资源占用，设置 CPU/内存限制 |
| CPU 持续 > 80% | 后台任务 | 检查媒体扫描、防病毒、RAID 重建 |
| 磁盘 I/O 持续 100% | `iostat` + `/proc/mdstat` | RAID 重建、快照操作、Qtier 迁移 |
| NAS 整体变慢 | 内存占用 | `free -m` 检查内存，重启大内存容器 |

---

## 十、安全要求

- 性能查询（iostat、top、docker stats）：只读，无需确认
- 修改网络配置（MTU、链路聚合）：必须确认，错误配置可能导致网络中断
- Docker 容器资源限制修改：告知用户
- `docker volume prune`：必须确认，误删不可恢复
