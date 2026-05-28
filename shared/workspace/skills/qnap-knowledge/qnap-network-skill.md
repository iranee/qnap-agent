---
name: qnap-network
description: QNAP QTS 的网络状态、端口、DNS、服务监听、连接诊断、SMB/NFS/FTP 服务排查、远程访问方案及 VPN 配置。
---

# QNAP 网络管理与诊断

> 适用范围：QTS 5.x 网络配置、连接诊断、服务端口
> 适用场景：网络故障排查、端口查询、连接测试、远程访问配置

---

## 一、网络状态查询

```sh
ip addr show
ip route show
ip addr show eth0
ethtool eth0 2>/dev/null | grep -E 'Speed|Duplex|Link'
cat /etc/resolv.conf
cat /etc/hosts
cat /proc/net/bonding/bond0 2>/dev/null   # 链路聚合状态
ip -s link show
```

---

## 二、端口与服务查询

```sh
netstat -tlnp 2>/dev/null || ss -tlnp
netstat -ulnp 2>/dev/null || ss -ulnp
ss -tlnp | grep :8080
ss -tlnp | grep :445
docker ps --format "{{.Names}}: {{.Ports}}"
```

---

## 三、连通性测试

```sh
ping -c 4 8.8.8.8
nslookup google.com
nslookup google.com 8.8.8.8
curl -I --connect-timeout 5 https://www.google.com
nc -zv 192.168.1.100 445 2>&1
nc -zv 192.168.1.100 22 2>&1
```

---

## 四、QNAP 网络配置文件

```sh
cat /etc/config/network.conf
/sbin/getcfg eth0 IPAddress -f /etc/config/network.conf
/sbin/getcfg eth0 Netmask -f /etc/config/network.conf
/sbin/getcfg eth0 Gateway -f /etc/config/network.conf
/sbin/getcfg eth0 DHCP -f /etc/config/network.conf
/sbin/getcfg Network DNS -f /etc/config/uLinux.conf 2>/dev/null
```

---

## 五、常用服务端口速查

| 服务 | 默认端口 | 协议 |
|---|---|---|
| QTS Web 管理 | 8080 / 443 | TCP |
| SSH | 22 | TCP |
| FTP | 21 | TCP |
| FTP 被动模式 | 55536-56559 | TCP |
| Samba/SMB | 445 | TCP |
| NFS | 2049 | TCP/UDP |
| NFS rpcbind | 111 | TCP/UDP |
| WebDAV | 8080/443 | TCP |
| DLNA | 1900 | UDP |
| Plex | 32400 | TCP |
| Emby / Jellyfin | 8096 | TCP |
| iSCSI | 3260 | TCP |
| RTRR | 8899 | TCP |
| QVPN WireGuard | 51820 | UDP |
| QVPN OpenVPN | 1194 | UDP |
| Tailscale | 41641 | UDP |

---

## 六、防火墙状态查询（只读）

```sh
iptables -L -n -v 2>/dev/null
iptables -L INPUT -n -v 2>/dev/null
iptables -t nat -L -n -v 2>/dev/null
# 禁止执行 iptables -F
```

---

## 七、SMB / Samba 排查

### 7.1 服务状态

```sh
/etc/init.d/smbd status 2>/dev/null
ss -tlnp | grep -E ':139|:445'
smbstatus 2>/dev/null | head -40
testparm 2>/dev/null | head -40
grep -E '^\[|path|valid users|guest|writeable' /etc/config/smb.conf | head -60
```

### 7.2 Windows 11 24H2 SMB 兼容性问题（高频故障，2024年10月后大量出现）

Windows 11 24H2 默认强制开启两项 SMB 安全策略，导致大量 QNAP 用户突然无法访问共享或速度骤降。

**故障一：SMB 签名（Signing）导致速度从 100 MB/s 骤降到 10-15 MB/s**

诊断：
```powershell
# Windows 端执行（管理员 PowerShell）
Get-SmbClientConfiguration | Select RequireSecuritySignature
# 如果返回 True，即为此问题
```

修复方案 A（推荐，在 QNAP 侧启用签名支持）：
```
QTS GUI → 控制台 → 网络与文件服务 → Windows 共享（Samba）
→ 高级设置 → SMB 签名 → 选择"如客户端要求则签名"
```

修复方案 B（Windows 端关闭强制签名，内网环境可接受）：
```powershell
# 管理员 PowerShell 执行
Set-SmbClientConfiguration -RequireSecuritySignature $false

# 或通过注册表（立即生效，无需重启）
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 0 /f
```

**故障二：来宾账户回退禁用导致 Windows 11 Pro 完全无法连接（报错：网络路径未找到）**

诊断：
```powershell
Get-SmbClientConfiguration | Select EnableInsecureGuestLogons
# 如果返回 False 且 NAS 使用来宾访问，即为此问题
```

修复方案：
```powershell
Set-SmbClientConfiguration -EnableInsecureGuestLogons $true
```

**长期解决方案（最彻底）：** 在 QNAP 上为每个需要访问共享的用户创建独立账号，不依赖来宾访问。此方案完全兼容 Windows 11 24H2 的新安全策略，且更安全。

**查询 Windows 版本号：**
```
运行 → winver → 查看 Build 号，26100.x 即为 24H2
```

### 7.3 其他 SMB 速度问题

- **SMB 协议版本**：确认 QNAP 启用 SMB3.1.1（控制台 → Samba → 最高协议版本）
- **Jumbo Frame**：NAS、交换机、PC 三端 MTU 必须一致设为 9000，否则反而更慢
- **小文件传输慢**：SMB 对小文件（<1MB）元数据开销大，无法避免；大量小文件场景可考虑 rsync 或 iSCSI
- **Office 文件保存报 Access Denied**：通常是 Oplocks 冲突，可在 Samba 高级设置中关闭 Oplocks

---

## 八、NFS 排查

```sh
/etc/init.d/nfsd status 2>/dev/null
showmount -e localhost 2>/dev/null
ss -tlnp | grep ':2049'
exportfs -v 2>/dev/null
cat /etc/config/nfs.conf 2>/dev/null

# macOS 挂载必须加 resvport（否则权限拒绝）
# sudo mount -t nfs -o resvport <NAS_IP>:/share/<共享名> /Volumes/mnt
```

NFS 权限问题：QTS NFS 配置需开启"允许非标准端口连接"，macOS 默认使用特权端口（<1024）。

---

## 九、远程访问方案

**核心原则：绝不直接将 NAS 管理端口（8080/443）暴露到公网，这是勒索病毒的首要入口。**

| 方案 | 安全性 | 难度 | 说明 |
|---|---|---|---|
| **Tailscale** | ★★★★★ | 极低 | 零配置，无需端口转发，跨 CGNAT，个人免费 |
| QVPN WireGuard | ★★★★★ | 中等 | 原生集成，只需一个 UDP 端口 |
| ZeroTier | ★★★★ | 低 | 类 Tailscale，可自托管控制平面 |
| QVPN OpenVPN | ★★★★ | 较复杂 | 兼容性广 |
| myQNAPcloud Link | ★★★ | 极低 | QNAP 中继，速度受限，适合应急 |
| 直接端口转发 | ★ | 极低 | **严禁，高风险** |

### 9.1 Tailscale 安装（最推荐的远程访问方案）

**方式 A — App Center 直装：**
```
App Center → Communications → Tailscale → 安装 → 打开 → Connect
登录 Tailscale 账号后，NAS 加入 Tailnet，可从任何已授权设备访问
```

**方式 B — Docker 安装（支持 authkey 自动认证，适合无头配置）：**
```yaml
services:
  tailscale:
    image: tailscale/tailscale:stable
    container_name: tailscale
    network_mode: host            # 关键：必须 host 模式，NAT 模式无效
    restart: unless-stopped
    volumes:
      - /share/tailscale/state:/var/lib/tailscale
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
      - NET_RAW
    environment:
      - TS_AUTH_KEY=<从 Tailscale Admin Console → Settings → Keys 生成>
      - TS_STATE_DIR=/var/lib/tailscale
```

**Tailscale 使用要点：**
- 容器模式的 `TS_AUTH_KEY` 支持 reusable key，避免每次重启重新认证
- App Center 版可在 QTS 界面直接查看连接状态
- 子网路由（Subnet Router）功能可让所有 Tailscale 设备访问整个内网，需 CLI 配置：
  ```sh
  # 获取 Tailscale CLI 路径
  echo $(getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg/Tailscale/
  # 启用子网路由
  <tailscale_path>/tailscale up --advertise-routes=192.168.1.0/24
  ```

### 9.2 QVPN WireGuard 检查

```sh
ss -ulnp | grep :51820
QPKG_DIR=$(/bin/sed -nr ":s /^\[QVPN\]/ b o; n; b s; :o n; /^\[/ q; /^Install_Path[ ]*=/ {s/.*=[ ]*// p; q;} b o;" "/etc/config/qpkg.conf")
ls "${QPKG_DIR}" 2>/dev/null
```

---

## 十、myQNAPcloud 安全配置

```sh
/sbin/getcfg myQNAPcloud AutoRouterConfig -f /etc/config/uLinux.conf 2>/dev/null
```

安全必做：关闭 myQNAPcloud 自动路由器配置（即关闭 UPnP 端口自动映射）。

---

## 十一、HDD 待机（磁盘休眠）诊断

磁盘无法进入休眠的常见根源：

```sh
# 查看哪些进程持续访问磁盘
lsof /share/CACHEDEV1_DATA/ 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | head -10

# 查看磁盘 I/O 活动
iostat -x 2 5
```

已知持续唤醒磁盘的组件：Download Station、Music Station、Photo Station、NTP 同步、RAID 元数据守护进程、Docker 容器写日志。

```sh
# hdparm 设置较长待机时间（绕过 QTS GUI 设置有时不生效的问题）
# -S251 约等于 5.5 小时
hdparm -S251 /dev/sda
hdparm -S251 /dev/sdb
# 注意：QTS 后台进程可能覆盖此设置，重启后需重新设置
```

---

## 十二、安全要求

- 网络查询：只读，无需确认
- 修改网络配置：必须确认，错误配置可能导致 NAS 失联
- 重启 smbd/nfsd：必须确认，会断开所有连接
- 禁止 `iptables -F`
