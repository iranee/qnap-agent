---
name: qnap-application
description: QNAP QTS 应用服务管理，包含 QuMagie 照片管理（Photo Station 继任者）、Video Station、Music Station、Download Station 多媒体套件、QVR 监控系统、Virtualization Station 虚拟化及常用 Docker 镜像推荐。
---

# QNAP 应用服务管理

> 适用范围：QTS 5.x 应用服务层管理
> 适用场景：多媒体服务配置、监控管理、虚拟化部署、容器推荐

---

## 一、多媒体套件概览

### 1.1 QNAP 多媒体应用状态

| 应用 | 功能 | 状态 | 推荐替代 |
|---|---|---|---|
| **Photo Station** | 照片管理与分享 | **2023年10月已停用** | QuMagie、PhotoPrism |
| **Video Station** | 视频管理与转码 | 仍在维护 | Jellyfin、Plex、Emby |
| **Music Station** | 音乐管理与串流 | 仍在维护 | Navidrome |
| **Download Station** | 下载（BT/PT/HTTP） | 仍在维护 | qBittorrent（Docker） |
| **QuMagie** | AI 智能相册（Photo Station 继任者） | 官方推荐 | PhotoPrism |
| **Qfile** | 移动端文件管理 | 正常 | — |

### 1.2 Photo Station 停用与迁移

**停用时间：** 2023 年 10 月 1 日

**迁移方案 A（官方推荐）：迁移到 QuMagie**
1. App Center 安装 QuMagie（某些机型需要 QNAP AI Core）
2. 首次打开时选择导入 Photo Station 数据库
3. 照片会自动同步到 QuMagie AI 相册

**迁移方案 B：自托管 PhotoPrism**
```yaml
services:
  photoprism:
    image: photoprism/photoprism:latest
    container_name: photoprism
    ports:
      - "2342:2342"
    volumes:
      - /share/Container/photoprism/originals:/photoprism/originals
      - /share/Container/photoprism/storage:/photoprism/storage
    restart: unless-stopped
```

### 1.3 Video Station 硬件转码

- **Intel QuickSync**：支持 H.264/H.265 实时转码，减少 CPU 负载
- **NVIDIA GPU**：需要 NVIDIA 驱动 QPKG + 容器直通
- ARM NAS：一般不支持硬件转码

---

## 二、媒体服务器对比（第三方）

| | Plex | Emby | Jellyfin |
|---|---|---|---|
| 费用 | 免费+付费（Plex Pass） | 免费+付费（Premiere） | 完全免费开源 |
| 硬件转码 | 需 Plex Pass | 需 Premiere | 免费支持 |
| 界面 | 最精美 | 次之 | 功能完善 |
| 推荐程度 | 高（订阅用户） | 中 | 高（无订阅需求） |

### 2.1 Jellyfin 部署（推荐）

```sh
# 检查 Jellyfin 状态
docker ps | grep -i jellyfin
docker logs jellyfin 2>/dev/null | tail -30
ss -tlnp | grep :8096

# Compose 配置参考
# 媒体库路径映射到 /share/ 下的实际目录
```

### 2.2 Plex 检查

```sh
# 检查 Plex 安装方式（QPKG 或 Docker）
QPKG_NAME="PlexMediaServer"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf 2>/dev/null)

if [ -n "${QPKG_ROOT}" ]; then
    echo "Plex QPKG 安装路径: ${QPKG_ROOT}"
    ls "${QPKG_ROOT}"
else
    echo "Plex 未以 QPKG 安装，检查 Docker..."
    docker ps | grep -i plex
fi

# Plex 端口（默认 32400）
ss -tlnp | grep :32400
```

---

## 三、QuMagie 人像数据备份

QuMagie 的人脸识别数据存储在特定路径，系统升级或重置后会丢失，需要单独备份：

```sh
QPKG_ROOT=$(/sbin/getcfg QuMagie Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
ls "${QPKG_ROOT}" 2>/dev/null

# 查找人脸数据文件
find /share -name "*.facev*" -o -name "face_*.db" 2>/dev/null | head -10
```

---

## 四、常用 Docker 镜像参考

| 镜像 | 用途 | 端口 | 注意事项 |
|---|---|---|---|
| **homeassistant/home-assistant** | 智能家居 | 8123 | 需要特权模式运行 |
| **portainer/portainer-ce** | Docker 可视化管理 | 9000/9443 | 首次登录设置强密码 |
| **linuxserver/jellyfin** | 媒体服务 | 8096/8920 | 需要配置媒体库路径 |
| **linuxserver/plex** | 媒体服务 | 32400 | 硬件转码需 Plex Pass |
| **nginx** | Web 反向代理 | 80/443 | 配置文件持久化 |
| **postgres** | 数据库 | 5432 | 数据目录持久化到存储卷 |
| **redis** | 缓存 | 6379 | 内存数据库，注意持久化 |
| **grafana/grafana** | 监控面板 | 3000 | 可对接 Prometheus |
| **adguard/adguardhome** | DNS 广告拦截 | 53/3000 | 需特权模式，注意与 DNS 冲突 |
| **mariadb** | 数据库 | 3306 | 配置文件持久化 |
| **nextcloud** | 私有云盘 | 80 | 大规模建议外接 MariaDB |

---

## 五、QVR 监控系统

### 5.1 QVR 产品线

| 产品 | 定位 | 通道数 |
|---|---|---|
| **QVR Pro** | 专业监控（推荐） | 64 路 |
| **QVR Guard** | 24/7 录像监控 | 高可靠性 |
| **QVR Face** | AI 人脸识别 | 支持 8 路免费 |
| **QVR Human** | 人流统计 | 需配合 AI 模块 |

> QVR Pro 推荐安装在 QuTS hero 系统（ZFS 快照支持，数据更安全）。

### 5.2 QVR 初始配置路径

```
App Center → 安装 QVR Pro
QVR Pro → 相机管理 → 添加相机
```

**⚠️ WEB UI 优先原则：** QVR 的所有录像计划、事件规则、相机配置必须通过 QVR GUI 完成，禁止通过命令行创建或修改监控任务。

### 5.3 QVR 状态查询

```sh
QPKG_NAME="QVRPro"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
echo "QVR Pro 路径: ${QPKG_ROOT}"

# 检查 QVR 服务状态（只读查询）
${QPKG_ROOT}/QVRPro.sh status 2>/dev/null || \
    ps aux | grep -i qvr | grep -v grep | head -5

# 检查录像存储路径
ls /share/*/QVRPro/ 2>/dev/null | head -10
```

---

## 六、Virtualization Station 虚拟化

### 6.1 硬件虚拟化支持检查

```sh
# 检查 CPU 是否支持虚拟化
cat /proc/cpuinfo | grep -E 'vmx|svm'
# 有 vmx（Intel）或 svm（AMD）输出 → 支持
# 无输出 → CPU 不支持虚拟化，无法运行 Windows VM
```

### 6.2 虚拟机状态查询

```sh
QPKG_NAME="VirtualizationStation"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
echo "VS 路径: ${QPKG_ROOT}"

# 虚拟机列表（只读查询）
ls /share/Container/VS/ 2>/dev/null | head -10
```

**注意：** 虚拟机的创建、配置、启动/停止优先通过 Virtualization Station GUI 完成。

---

## 七、Download Station 排查

Download Station 持续访问磁盘可能导致磁盘无法进入休眠。

```sh
# 检查 Download Station 是否运行
QPKG_NAME="DownloadStation"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
${QPKG_ROOT}/DownloadStation.sh status 2>/dev/null

# 查看下载目录占用
ls /share/Download/ 2>/dev/null | head -10
df -h /share/Download/ 2>/dev/null
```

---

## 八、安全要求

- 查询应用状态、日志：只读，无需确认
- 停止/启动应用（非 Agent 自身）：必须确认
- 删除容器、虚拟机：必须确认
- 所有 WEB UI 可配置的内容：引导用户在界面操作，不代替执行
