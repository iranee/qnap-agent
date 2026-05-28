---
name: qnap-docker
description: QNAP QTS 上的 Docker 和 Container Station 管理、排查与部署规范。含 Portainer 集成、Container Station 3 迁移要点。
---

# QNAP Docker 容器管理

> 适用范围：QNAP Container Station 3 / Docker CE on QTS 5.x
> 适用场景：容器部署、管理、故障排查、Compose 项目维护

---

## 一、QNAP Docker 环境概述

QNAP 通过 **Container Station** 提供 Docker 支持，底层使用 Docker CE。

**⚠️ 关键变更：Container Station 3（CS3）升级要点**

Container Station 3 相比 CS2 有重大变化：
- **命令变更**：`docker-compose` 已废弃，改用 `docker compose`（注意：中间是空格，不是连字符）
- **docker compose PATH 问题**：CS3 安装后 SSH 中可能找不到 `docker compose`，需要更新 PATH：
  ```sh
  # 检查 Container Station 实际路径
  QPKG_NAME="container-station"
  QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf)
  echo "${QPKG_ROOT}"
  
  # 如果 docker compose 找不到，临时添加路径
  export PATH=$PATH:${QPKG_ROOT}/bin:${QPKG_ROOT}/usr/local/lib/docker/cli-plugins
  
  # 验证
  docker compose version
  ```
- **LXC 支持移除**：CS3 不再支持 LXC 容器，原 LXC 容器需要迁移
- **CS2 容器迁移**：CS2 创建的容器在 CS3 中可见但无法直接编辑 Compose 配置，建议在 CS3 中重建

```sh
QPKG_NAME="container-station"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf)
echo "Container Station 路径: ${QPKG_ROOT}"
ls "${QPKG_ROOT}"/*.sh 2>/dev/null
```

常用信息：
- Docker socket：`/var/run/docker.sock`
- Compose 命令：`docker compose`（CS3，注意空格）
- 容器挂载路径：优先使用 `/share/` 下的共享文件夹

---

## 二、Container Station vs Portainer 选择

**Container Station 3（CS3）内置管理界面：**
- 优点：原生集成 QTS，安装简单，初学者友好
- 缺点：功能有限，Compose 编辑不够灵活，跨版本迁移麻烦

**Portainer（推荐高级用户）：**
- 优点：功能更完整，Compose 管理灵活，日志查看更方便，支持模板
- 缺点：需要额外安装，学习曲线略陡

**使用原则：两者不要混用管理同一个容器。**
- 在 CS3 中创建的容器，Portainer 会显示为"limited"（只读），不能在 Portainer 中修改
- 在 Portainer 中创建的容器，CS3 可以查看但无法编辑
- 选一个工具管到底，不要交叉操作

**Portainer 安装（通过 Docker Compose）：**
```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /share/portainer/data:/data
```

---

## 三、容器状态查询

```sh
docker ps
docker ps -a
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"
docker inspect <容器名或ID>
docker logs <容器名>
docker logs --tail 100 <容器名>
docker logs --tail 100 -f <容器名>
docker stats --no-stream
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
```

---

## 四、容器生命周期管理

```sh
docker start <容器名>
docker stop <容器名>
docker stop -t 0 <容器名>        # 立即停止，无等待
docker restart <容器名>
docker rm <容器名>               # 删除已停止容器
docker rm -f <容器名>            # 强制删除（确认前禁止执行）
```

---

## 五、Docker Compose 项目管理

```sh
cd /share/<项目目录>

# 执行任何操作前先验证配置文件
docker compose config

docker compose up -d
docker compose down
docker compose restart
docker compose pull && docker compose up -d   # 更新镜像
docker compose ps
docker compose logs
docker compose logs -f <服务名>
docker compose restart <服务名>

# 注意：CS3 后 SSH 中需要确认 docker compose 命令可用（见上方 PATH 说明）
# docker-compose（连字符版本）在 CS3 中已废弃
```

---

## 六、镜像管理

```sh
docker images
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | sort -k2 -h
docker pull <镜像名>:<标签>
docker rmi <镜像名>:<标签>        # 删除前确认
docker image prune               # 清理悬空镜像（安全）
docker image prune -a            # 清理所有未使用镜像（确认后）
```

---

## 七、卷和网络

```sh
docker volume ls
docker volume inspect <卷名>
docker system df -v | grep -A 20 "VOLUME NAME"
docker network ls
docker network inspect <网络名>
```

---

## 八、进入容器

```sh
docker exec -it <容器名> /bin/sh
docker exec -it <容器名> /bin/bash
docker exec --user root -it <容器名> /bin/sh
docker exec <容器名> env
```

---

## 九、QNAP 部署规范

### 9.1 Volume 挂载路径

```yaml
services:
  myapp:
    volumes:
      - /share/myapp/data:/app/data     # 推荐：/share/ 路径
      - /share/myapp/config:/app/config
      # 避免挂载 /tmp/、/etc/、/bin/ 等系统目录
      # 避免挂载 /root/ 目录（RAM disk，重启消失）
```

### 9.2 端口映射

```yaml
services:
  myapp:
    ports:
      - "127.0.0.1:8080:8080"   # 仅本机访问
      - "0.0.0.0:8080:8080"     # 局域网可访问（等同于 "8080:8080"）
```

### 9.3 重启策略

```yaml
services:
  myapp:
    restart: unless-stopped    # 推荐：手动停止后不自动重启
    # restart: always           # 慎用：可能造成重启风暴
```

### 9.4 资源限制（防止单容器耗尽资源）

```yaml
services:
  myapp:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
```

### 9.5 日志大小限制（防止日志写满 RAM disk 或磁盘）

```yaml
services:
  myapp:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"   # 单个日志文件最大 100MB
        max-file: "3"      # 最多保留 3 个日志文件
```

**重要**：不限制日志大小会导致长期运行的容器日志无限增长，可能写满 `/` RAM disk。

### 9.6 推荐目录结构

```sh
# 推荐：创建独立的 docker 共享文件夹
# /share/docker/
#   appdata/   ← 各容器数据和配置（按容器名分子目录）
#   compose/   ← Compose 项目文件（可 git 版本管理）
#   secrets/   ← 密码、API Key 等敏感文件（不要放进 git）

mkdir -p /share/docker/appdata /share/docker/compose /share/docker/secrets

# 创建某个容器的数据目录
mkdir -p /share/docker/appdata/jellyfin
```

### 9.7 CS3 Compose 项目路径（GUI 创建的项目）

```sh
# CS3 GUI 创建的 Application（Compose 项目）存放在：
/share/Container/container-station-data/application/

# 每个项目的结构：
# /share/Container/container-station-data/application/<项目名>/
# ├── docker-compose.yml   ← Compose 配置
# └── qnap.json           ← QNAP 元数据（不要手动修改）

# 查看所有 CS3 项目
ls /share/Container/container-station-data/application/

# 查看某项目的 compose 配置（只读查看可以）
cat /share/Container/container-station-data/application/<项目名>/docker-compose.yml

# ⚠️ 警告：在 GUI 外编辑 docker-compose.yml 后，该项目在 CS3 GUI 中会变为 "Invalid"
# 此后只能通过 SSH + docker compose 命令管理，不能再通过 GUI 编辑
# 选择一种管理方式，不要混用 GUI 和 SSH
```

---

## 十、常见问题排查

### 10.1 容器无法启动

```sh
docker logs <容器名>
docker inspect <容器名> | grep -E '"ExitCode"|"Error"|"OOMKilled"'
ss -tlnp | grep <端口号>       # 端口占用检查
ls -la /share/<路径>           # 挂载路径是否存在
docker images | grep <镜像名>  # 镜像是否存在

# 退出码参考
# 0=正常 / 1=应用错误 / 125=Docker错误 / 137=OOM内存不足 / 139=段错误
```

### 10.2 容器频繁重启

```sh
docker inspect <容器名> | grep RestartCount
docker logs -f <容器名>
docker update --restart=no <容器名>   # 调试时暂停自动重启
# 手动测试（覆盖 entrypoint）
docker run --rm -it --entrypoint /bin/sh <镜像名>
```

### 10.3 磁盘空间不足

```sh
docker system df
docker system df -v
docker image prune               # 悬空镜像（安全）
docker container prune           # 已停止容器（确认后）
docker volume prune              # 未使用卷（危险！确认数据后）
docker system prune              # 全部清理（确认后）
```

**警告：** `docker volume prune` 可能删除含数据的卷，执行前务必确认。

### 10.4 docker compose 命令找不到（CS3 升级后）

```sh
# 确认 CS3 安装路径
QPKG_NAME="container-station"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf)

# 直接使用完整路径（最可靠）
"${QPKG_ROOT}/bin/docker" compose ps

# 或在 /etc/profile 末尾添加（新开 SSH 会话后生效）
echo "export PATH=\$PATH:${QPKG_ROOT}/bin:${QPKG_ROOT}/usr/local/lib/docker/cli-plugins" >> /etc/profile
```

### 10.5 容器无法访问外网 / DNS 问题

```sh
docker network inspect bridge | grep -E 'Subnet|Gateway'
docker exec <容器名> cat /etc/resolv.conf
docker exec <容器名> ping -c 3 8.8.8.8
```

DNS 未传入容器时，在 Compose 中指定：
```yaml
services:
  myapp:
    dns:
      - 8.8.8.8
      - 1.1.1.1
```

---

## 十一、安全要求

- 查询容器状态、日志：只读，无需确认
- 停止、重启容器：必须确认（影响运行中的服务）
- 删除容器、数据卷：必须确认，卷数据可能不可恢复
- `docker system prune`：必须确认
- 不要通过 apt/yum/opkg 安装 Docker 相关依赖

---

## 十二、Docker 镜像源（Registry Mirror）配置

Docker Hub 在国内网络环境访问不稳定，可通过配置镜像源加速拉取。

### 12.1 通过 Container Station GUI 配置（推荐）

```
Container Station → 偏好设置 → Registry 服务器
→ 点击"+"添加镜像地址
→ 填入镜像源地址（如 https://mirror.example.com）
→ 确定 → 重启 Container Station
```

### 12.2 通过配置文件修改

CS3 的 Docker 配置文件路径：

```sh
# 定位配置文件
QPKG_ROOT=$(/sbin/getcfg container-station Install_Path -f /etc/config/qpkg.conf)
echo "${QPKG_ROOT}"
ls "${QPKG_ROOT}/etc/"

# 配置文件一般在
cat "${QPKG_ROOT}/etc/docker.json" 2>/dev/null
# 或
cat "${QPKG_ROOT}/var/container-station-data/etc/docker.json" 2>/dev/null
```

**修改格式（修改前备份原文件）：**

```json
{
  "registry-mirrors": [
    "https://你的镜像地址"
  ]
}
```

**修改后重启 Container Station：**

```sh
/etc/init.d/container-station.sh restart
```

### 12.3 验证镜像源是否生效

```sh
docker info | grep -A 5 "Registry Mirrors"
# 如果列出了配置的地址，则生效
```

**注意：** 修改 docker.json 属于灰区操作，执行前须备份原文件，并确认用户已知晓。容器配置文件路径因 CS 版本而异，务必先通过 getcfg 确认实际路径。
