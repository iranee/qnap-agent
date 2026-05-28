---
name: qnap-plugins
description: QNAP QTS 第三方 QPKG 插件使用指南，含 ZeroTier、OpenList、NPS、GoCron 的安装、诊断与排障。以及 QPKG 通用结构知识。
---

# QNAP 第三方插件管理

> 适用范围：QTS 5.x 第三方 QPKG 插件
> 适用场景：ZeroTier 组网、多云盘挂载、内网穿透、定时任务管理

---

## 一、QPKG 通用结构与操作规范

### 1.1 QPKG 核心原理

每个已安装的 QPKG 都在 `/etc/config/qpkg.conf` 中记录了关键字段：

```ini
[AppName]
Enable = TRUE
Version = 1.0.0
Install_Path = /share/CACHEDEV1_DATA/.qpkg/AppName
```

**动态获取应用安装路径（标准写法）：**

```sh
# 方法一：直接 getcfg（最简单）
QPKG_ROOT=$(/sbin/getcfg <AppName> Install_Path -f /etc/config/qpkg.conf)

# 方法二：sed 解析（更健壮，不依赖 getcfg 路径）
QPKG_NAME="<AppName>"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf)

# 验证
echo "安装路径: ${QPKG_ROOT}"
ls "${QPKG_ROOT}"
```

### 1.2 QPKG 标准服务控制

```sh
# 标准 start/stop/restart（通用于所有 QPKG）
${QPKG_ROOT}/<AppName>.sh start
${QPKG_ROOT}/<AppName>.sh stop
${QPKG_ROOT}/<AppName>.sh restart

# 或通过 init.d 中的符号链接
/etc/init.d/<AppName>.sh start

# 检查是否启用
/sbin/getcfg <AppName> Enable -u -d FALSE -f /etc/config/qpkg.conf
```

### 1.3 QPKG 常用系统目录查询

```sh
# 默认共享目录名称查询
/sbin/getcfg SHARE_DEF defVolMP    -f /etc/config/def_share.info   # 主存储挂载点
/sbin/getcfg SHARE_DEF defWeb      -d Qweb -f /etc/config/def_share.info      # Web 目录
/sbin/getcfg SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info # 下载目录
/sbin/getcfg SHARE_DEF defMultimedia -d Qmultimedia -f /etc/config/def_share.info # 多媒体目录
```

### 1.4 QPKG PID 文件约定

```sh
# 标准 PID 文件位置
PIDF=/var/run/<app_name>.pid

# 检查进程是否运行
[ -f "${PIDF}" ] && kill -0 "$(cat "${PIDF}")" 2>/dev/null && echo "Running" || echo "Stopped"
```

---

## 二、ZeroTier 插件（qnap-zerotier）

ZeroTier 是一款异地组网工具，将多个网络设备连接到同一虚拟局域网，实现跨地区通过内网 IP 互访所有服务。与 Tailscale 同类，支持跨 NAT 穿透，无需端口转发。

### 2.1 安装方式选择

**方式 A — QPKG 插件（推荐，带 WebUI）：**

> **qnap-zerotier** 是为 QNAP 定制的 ZeroTier QPKG 插件，提供完整 WebUI 管理界面，无需命令行即可管理网络加入/退出、状态查看、允许列表配置。

```
下载地址：https://github.com/iranee/qnap-zerotier/releases
安装：App Center → 手动安装 → 上传 .qpkg 文件
```

**方式 B — Docker 容器（QTS 5.x 原生 ZeroTier 不稳定时推荐）：**

QTS 5.0.1 及以后，官方 ZeroTier QPKG 在内核兼容性上存在问题（尤其是 `zerotier-cli leave` 命令超时挂起）。Docker 方式更稳定：

```yaml
# 安装前：必须先从 App Center 安装 QVPN，以加载 TUN 内核驱动
# 不安装 QVPN → /dev/net/tun 不存在 → ZeroTier 无法启动

services:
  zerotier:
    image: zyclonite/zerotier:latest
    container_name: zerotier-one
    network_mode: host
    restart: unless-stopped
    volumes:
      - /share/zerotier/data:/var/lib/zerotier-one
    devices:
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
```

```sh
# 加入网络
docker exec zerotier-one zerotier-cli join <网络ID>

# 或通过预置配置文件加入（容器重启后自动加入）
mkdir -p /share/zerotier/data/networks.d
touch /share/zerotier/data/networks.d/<网络ID>.conf
```

### 2.2 ZeroTier 网络状态诊断

**通过 QPKG WebUI 查看（qnap-zerotier 插件）：**
打开插件管理界面即可查看网络状态、节点信息、加入/退出操作。

**通过命令行查看（Docker 模式）：**

```sh
# 查看节点信息
docker exec zerotier-one zerotier-cli info

# 查看所有已加入的网络
docker exec zerotier-one zerotier-cli listnetworks

# 查看所有 Peer 节点
docker exec zerotier-one zerotier-cli listpeers

# 加入网络
docker exec zerotier-one zerotier-cli join <网络ID>

# 离开网络（注意：QTS 5.x 原生模式下此命令可能超时，Docker 模式无此问题）
docker exec zerotier-one zerotier-cli leave <网络ID>
```

### 2.3 ZeroTier 网络状态码含义

| 状态码 | 含义 | 处理方式 |
|---|---|---|
| `OK` ✅ | 成功加入，运行正常 | 正常 |
| `REQUESTING_CONFIGURATION` ⌛ | 正在请求配置，等待连接建立 | 稍等，通常几十秒内变为 OK |
| `AUTHORIZING` ⌛ | 等待网络管理员在 my.zerotier.com 批准 | 登录管理控制台授权该节点 |
| `ACCESS_DENIED` 🚫 | 节点被拒绝，管理员未授权 | 在控制台勾选允许该节点 |
| `NOT_FOUND` 🚫 | 网络 ID 不存在或已删除 | 确认网络 ID 是否正确 |

### 2.4 ZeroTier vs Tailscale 选择建议

| | ZeroTier | Tailscale |
|---|---|---|
| 免费配额 | 25 台设备 | 100 台设备（个人版） |
| 自托管控制平面 | 支持（自建 Moon 节点） | 需第三方 Headscale |
| QNAP 插件支持 | qnap-zerotier QPKG（有 WebUI） | App Center 官方插件 |
| 穿透能力 | 强，支持 Moon 中继 | 更强，DERP 中继网络全球分布 |
| 管理界面 | my.zerotier.com 控制台 | tailscale.com 控制台 |
| 内网路由广播 | 支持（手动配置路由） | 支持（Subnet Router） |

**选择建议：**
- 希望有 WebUI 且设备数不多：优先用 **qnap-zerotier QPKG**
- 希望免配置开箱即用：**Tailscale**（App Center 安装）
- 设备多、或希望自托管控制平面：**ZeroTier + Moon**
- ZeroTier QPKG 不稳定时：改用 Docker 模式

### 2.5 qnap-zerotier 插件 v1.14.0 新增功能

最新版本支持以下网络选项（可在 WebUI 中配置）：
- **Allow Managed**：允许 ZeroTier 管理 IP 地址（默认开启）
- **Allow DNS**：允许 ZeroTier 推送 DNS 配置
- **Allow Default**：允许 ZeroTier 接管默认路由（访问整个网络）
- **Allow Global**：允许 ZeroTier 管理全局/公网路由

### 2.6 TUN 驱动缺失排查

```sh
# 检查 TUN 模块
ls -la /dev/net/tun
lsmod | grep tun

# 手动加载 TUN（仅临时，重启后失效），可以加载到启动脚本里
modprobe tun

# 永久解决：安装 QVPN QPKG（会自动在启动时加载 TUN）
# App Center → 搜索 QVPN → 安装
```

---

## 三、OpenList WebDAV 多云盘挂载（qnap-openlist-webdav）

将阿里云盘、夸克、百度网盘、Google Drive 等多种云盘通过 WebDAV 协议挂载到 NAS，实现统一管理。

### 3.1 安装前提条件

```
控制台 → 应用程序 → Web 服务器 → ☑️ 启用 Web 服务器
保持默认 80 端口（不要修改）
```

```sh
# 验证 Web 服务器状态
/etc/init.d/Qthttpd status 2>/dev/null || \
    ss -tlnp | grep ':80'
```

### 3.2 诊断

```sh
QPKG_ROOT=$(/sbin/getcfg openlist Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
echo "openlist 路径: ${QPKG_ROOT}"
ls "${QPKG_ROOT}"

# 服务状态
ss -tlnp | grep ':5244'   # openlist 默认端口
```

### 3.3 常见问题

**忘记密码：**
```sh
# 通过命令行重置密码
QPKG_ROOT=$(/sbin/getcfg openlist Install_Path -f /etc/config/qpkg.conf)
"${QPKG_ROOT}/openlist" admin set <新密码>

# 初始默认凭据：admin / 123456
```

**HBS3 挂载 WebDAV 注意事项：**
- 挂载名称必须为英文（中文会导致挂载失败）
- 不能挂载 `/dav/` 根目录，必须指定具体网盘路径
- 例：阿里云盘挂载路径格式：`/dav/aliyundrive`

---

## 四、NPS 内网穿透客户端（qnap-nps）

NPS 是轻量级内网穿透代理，支持 TCP/UDP 转发、HTTP 代理、SOCKS5、P2P，适合将 QNAP 内网服务通过公网服务器暴露。

### 4.1 安装前提

```
控制台 → 应用程序 → Web 服务器 → 启用
```

### 4.2 诊断

```sh
QPKG_ROOT=$(/sbin/getcfg nps Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
echo "nps 路径: ${QPKG_ROOT}"

# 查看连接状态
ss -tnp | grep npc
tail -30 "${QPKG_ROOT}/logs/npc.log" 2>/dev/null
```

**使用注意：**
- NPS 客户端（npc）运行在 QNAP 上，连接远端的 NPS 服务端（nps）
- 服务端需要有公网 IP 的服务器运行
- 适合无公网 IP 情况下暴露 QNAP 的特定服务端口

---

## 五、GoCron 定时任务（qnap-gocron）

QNAP 版 Crontab 的增强替代品，提供 WebUI 管理多个定时任务，支持任务依赖、多主从高可用、日志查看。

### 5.1 安装版本选择

| 版本 | 数据库 | 适用场景 |
|---|---|---|
| `gocron_*_Sqlite3.qpkg` | SQLite3 | 首次安装，即装即用，推荐 |
| `gocron_*_MySQL.qpkg` | MySQL/MariaDB | 已有 MySQL 数据库，升级安装 |

MySQL 版本安装前提：
```
控制台 → 应用程序 → MariaDB5（原 MySQL 服务）→ 启用
```

### 5.2 默认凭据

- 初始账号：admin
- 初始密码：123456

```sh
QPKG_ROOT=$(/sbin/getcfg gocron Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
echo "gocron 路径: ${QPKG_ROOT}"
ss -tlnp | grep ':5920'   # gocron 默认 WebUI 端口
```

---

## 六、QPKG 提取与分析（qnap-extract-qpkg）

分析已有 QPKG 安装包的内部结构，用于学习其他应用的打包方式。

```sh
# QPKG 文件本质是带有头部信息的 tar 包
# 手动提取方式：
file app.qpkg                      # 查看文件类型
tail -n +XX app.qpkg | tar xzf -  # XX 为数据开始偏移量（查看头部信息确定）

# 使用工具提取
QPKG_ROOT=$(/sbin/getcfg qnap-extract-qpkg Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
"${QPKG_ROOT}/extract-qpkg.sh" app.qpkg
```

---

## 七、QuMagie 人像数据备份

QuMagie 的人脸识别数据存储在特定路径，系统升级或重置后会丢失，需要单独备份。

```sh
# QuMagie 数据路径（通过 qnap-qumagie-face-data 工具定位）
QPKG_ROOT=$(/sbin/getcfg QuMagie Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
ls "${QPKG_ROOT}" 2>/dev/null

# 一般人脸数据路径
find /share -name "*.facev*" -o -name "face_*.db" 2>/dev/null | head -10
```

---

## 八、插件通用排障流程

```sh
# 1. 确认插件已安装
/sbin/getcfg <插件名> Install_Path -f /etc/config/qpkg.conf

# 2. 确认插件已启用
/sbin/getcfg <插件名> Enable -f /etc/config/qpkg.conf

# 3. 获取安装路径
QPKG_ROOT=$(/sbin/getcfg <插件名> Install_Path -f /etc/config/qpkg.conf)

# 4. 读取启动脚本了解服务结构
ls "${QPKG_ROOT}"/*.sh 2>/dev/null
cat "${QPKG_ROOT}"/<插件名>.sh 2>/dev/null | head -50

# 5. 查看日志
ls "${QPKG_ROOT}"/log/ 2>/dev/null
ls "${QPKG_ROOT}"/logs/ 2>/dev/null
tail -50 "${QPKG_ROOT}"/log/*.log 2>/dev/null | head -80

# 6. 检查端口是否监听
ss -tlnp | grep <端口号>

# 7. 查看系统日志
grep -i "<插件名>" /var/log/messages | tail -20
```

---

## 九、安全要求

- 读取插件配置和日志：只读，无需确认
- 启动/停止插件：告知用户
- 修改插件配置文件：必须确认
- 禁止写入其他 QPKG 目录（仅限 qnap-agent 自身目录）
