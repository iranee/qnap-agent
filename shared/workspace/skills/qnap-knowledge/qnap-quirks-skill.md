---
name: qnap-quirks
description: QTS 系统特有的陷阱与坑：RAM disk架构、文件持久化规则、crontab持久化、SSH密钥存储、CS3路径约定、QuTS hero差异。遇到"重启后失效"、"文件消失"、"写入无效"等问题时必读。
---

# QTS 系统特有陷阱与坑

> 这些是最容易踩坑的地方，也是最难靠直觉发现的问题。

---

## 一、【最重要】QTS 根目录是 RAM Disk，重启后清空

### 1.1 QTS 的存储层次（必须理解）

```text
/             ← RAM disk（16-400MB）→ 重启后全部清空！
/tmp/         ← tmpfs（内存）→ 重启后清空
/dev/shm      ← tmpfs（内存）→ 重启后清空
/root/        ← 在 RAM disk 上 → 重启后清空！
/var/         ← 大部分在 RAM disk 上 → 重启后清空！
/var/log/     ← 部分持久、部分不持久（型号差异）
/etc/         ← 大部分在 RAM disk，部分通过 /etc/config 持久化

# ↓ 以下是持久化存储 ↓
/etc/config/  ← 持久化（存在 /mnt/HDA_ROOT 或 flash 分区上）
/mnt/HDA_ROOT/← 系统持久分区（含 /etc/config 内容）
/mnt/ext/     ← 扩展系统分区（约 350-500MB）
/share/       ← 用户数据（HDD/SSD 上）→ 完全持久
```

**后果**：写入 `/root/.bashrc`、`/var/run/`（PID文件）、`/etc/hosts`（非软链接版）等位置的内容，重启后消失。

**验证方式**：
```sh
df -h | head -20
# 看 "/" 挂载点，如果是 none/ramdisk/tmpfs，就是内存盘
# 正常输出示例：
# Filesystem   Size  Used Avail Use% Mounted on
# none         400M  127M  273M  32% /            ← RAM disk
# tmpfs         64M    1M   63M   2% /tmp
# /dev/md9     494M  128M  366M  26% /mnt/HDA_ROOT ← 持久系统区
```

### 1.2 常见"重启后失效"问题汇总

| 操作 | 重启后是否保留 | 正确做法 |
|---|---|---|
| 写入 `/root/.bashrc` | ❌ 不保留 | 写入 `/etc/config/profile` 或启动脚本 |
| 写入 `/etc/hosts` | ❌ 不保留（部分型号） | 通过 QTS GUI 修改，或写 autorun |
| 写入 `/var/run/*.pid` | ❌ 不保留 | 正常，PID文件本来就是临时的 |
| 创建 `/opt/` 下的软链接 | ❌ 不保留 | QPKG 启动脚本中重新创建 |
| `crontab -e` 编辑 | ❌ 不保留（部分情况） | 见下方 crontab 章节 |
| `/etc/config/` 下的文件 | ✅ 保留 | 配置放这里 |
| `/share/` 下的文件 | ✅ 保留 | 数据放这里 |
| `${QPKG_ROOT}/` 下的文件 | ✅ 保留（在 /share/ 上） | 插件数据放这里 |

### 1.3 /mnt/ext/ 分区满了（另一个常见错误）

```sh
# /mnt/ext 是扩展系统分区（约 350-500MB），装 QPKG 二进制和库
df -h | grep ext
# 示例：
# /dev/md13  417M  402M  15M  97% /mnt/ext   ← 快满了！

# 查找 /mnt/ext 中的大文件
du -sh /mnt/ext/*/ 2>/dev/null | sort -rh | head -20
```

`/mnt/ext` 满的常见原因：安装了太多 QPKG 应用（尤其是大型 QPKG 如 Python 库）。
解法：卸载不需要的 QPKG，或通过 QTS GUI 迁移 QPKG 安装位置到 `/share/` 分区。

---

## 二、RAM Disk 满了（ramdisk full）

### 2.1 症状识别

```sh
df -h | grep ' /$'
# 如果看到 100% 占用，就是 ramdisk 满了

# QTS 界面登录后报错：
# "The device has insufficient system storage: RAMDisk (/ or /tmp)"
```

### 2.2 排查步骤

```sh
# Step 1：确认是哪个目录占满了
df -h | head -15

# Step 2：找大目录
du -sh /*/ 2>/dev/null | sort -rh | head -20
du -sh /var/*/ 2>/dev/null | sort -rh | head -20

# Step 3：找写入 ramdisk 的进程
lsof / 2>/dev/null | grep -v '/share' | awk '{print $1}' | sort | uniq -c | sort -rn | head -10

# Step 4：查看系统日志寻找线索
grep -i 'ramdisk\|no space\|cannot write\|write error' /var/log/messages | tail -20
```

### 2.3 常见原因

| 原因 | 特征 | 处理方式 |
|---|---|---|
| 媒体缩略图生成（Photo Station / Multimedia Console） | CPU同时高，缩略图进程多 | 完成后自动恢复；或暂时禁用缩略图 |
| 某个 QPKG 写入临时文件到 / | 特定应用启动后才出现 | 逐一禁用 QPKG 定位，或检查 QPKG 路径配置 |
| Docker 容器日志未限制大小 | 容器运行时间越长越满 | 限制容器日志大小（见 docker-skill） |
| Samba 锁文件堆积 | `/var/samba/` 下大量文件 | 重启 smbd，`/etc/init.d/smbd restart` |
| QNAP CloudLink 缓存泄露 | CloudLink 运行时 | 更新 CloudLink 或禁用再重启 |

### 2.4 临时缓解方法（不重启）

```sh
# 清理 Samba 临时文件
rm -f /var/samba/private/*.tdb /var/samba/private/*.ldb 2>/dev/null

# 清理僵尸 PID 文件
find /var/run -name "*.pid" -mtime +1 2>/dev/null | head -10
# 谨慎：确认进程不在运行后再删除

# 查找可以安全删除的缓存
find /tmp -name "*.cache" -mtime +1 2>/dev/null | head -10
```

**根本解法**：重启 NAS，再找出是哪个 QPKG 造成泄漏，禁用或更新它。

---

## 三、crontab 持久化正确方式

### 3.1 QTS crontab 的坑

`crontab -e` 命令在某些 QTS 版本中编辑的是内存中的 crontab，**重启后失效**。

### 3.2 正确的持久化方法

```sh
# /etc/config/crontab 是持久化的 crontab 文件
# 直接编辑此文件

# 查看当前 crontab
cat /etc/config/crontab

# 添加一条定时任务（例如每天凌晨2点执行脚本）
echo "0 2 * * * /share/scripts/my_task.sh > /tmp/my_task.log 2>&1" >> /etc/config/crontab

# 激活（必须执行，否则 cron 不会读取新配置）
crontab /etc/config/crontab
/etc/init.d/crond.sh restart

# 验证是否生效
crontab -l | grep my_task
```

**重要**：
- 脚本路径必须在 `/share/` 下（RAM disk 外），否则重启后脚本消失
- 日志路径推荐也放 `/share/` 或 `${QPKG_ROOT}/log/` 下
- 每次修改 `/etc/config/crontab` 后必须执行 `crontab /etc/config/crontab` 激活

---

## 四、autorun.sh 启动脚本（持久化自定义启动任务）

QTS 支持在每次系统启动后执行自定义脚本，路径因型号而异。

### 4.1 配置方法（较新型号，QTS 4.x+）

```sh
# Step 1：挂载 flash/配置分区
BOOT_PD=$(/sbin/hal_app --get_boot_pd port_id=0 2>/dev/null)
if [ -n "${BOOT_PD}" ]; then
    mount "${BOOT_PD}6" /tmp/config 2>/dev/null || true
fi

# Step 2：创建或编辑 autorun.sh
cat >> /tmp/config/autorun.sh << 'AUTORUN_EOF'
#!/bin/sh
# 在这里添加启动时要执行的命令
# 例如：加载 tun 模块
modprobe tun 2>/dev/null
# 例如：创建软链接
ln -sf /share/scripts/mytool /usr/local/bin/mytool
AUTORUN_EOF

chmod +x /tmp/config/autorun.sh

# Step 3：卸载分区
umount /tmp/config 2>/dev/null || true

echo "autorun.sh 已配置，下次重启生效"
```

**注意**：不同型号的 flash 分区号可能不同（上面用 `port_id=0`）。建议先查文档确认型号。

### 4.2 不通过 autorun.sh 的替代方案

QPKG 插件的启动脚本（`${QPKG_ROOT}/<AppName>.sh start`）在 QTS 启动时会自动运行。  
如果需要持久化启动任务，**最稳妥的方式是把任务写入 QPKG 的 start 逻辑中**，无需修改 autorun.sh。

---

## 五、SSH 密钥持久化

```sh
# QTS 中 ~/.ssh 实际上是软链接到 /etc/config/ssh/
ls -la ~/.ssh
# 输出：lrwxrwxrwx 1 admin administrators 15 ... .ssh -> /etc/config/ssh/

# 所以 authorized_keys 文件路径是：
cat /etc/config/ssh/authorized_keys

# 添加公钥（持久化，重启后保留）
echo "ssh-rsa AAAA... user@host" >> /etc/config/ssh/authorized_keys
chmod 600 /etc/config/ssh/authorized_keys
```

---

## 六、Container Station 3 路径约定（GitHub项目验证）

### 6.1 CS3 Compose 文件存储路径

```sh
# CS3 存放所有用户 Compose 项目的路径：
/share/Container/container-station-data/application/

# 每个项目（Application）的目录结构：
/share/Container/container-station-data/application/<项目名>/
├── docker-compose.yml   # Compose 配置文件
└── qnap.json           # QNAP 元数据（不要手动修改）

# 查看所有 CS3 Compose 项目
ls /share/Container/container-station-data/application/ 2>/dev/null

# 查看某个项目的 compose 配置
cat /share/Container/container-station-data/application/<项目名>/docker-compose.yml
```

### 6.2 重要：CS3 外部编辑 Compose 文件的坑

**现象**：在 CS3 GUI 外编辑 `docker-compose.yml` 后，CS3 界面显示该项目为 "Invalid"，此后只能通过外部编辑，不能再通过 CS3 GUI 编辑。

**结论**：
- 要么全程用 CS3 GUI 管理
- 要么全程用 SSH + `docker compose` 命令管理
- 两者不要混用（会导致 GUI 显示 "Invalid"，但服务仍然正常运行）

### 6.3 CS3 内置的两个 Docker 实例

```sh
# CS3 有两个 Docker 层：
# 1. system-docker（内部系统层，QNAP 自用）
QPKG_ROOT=$(/sbin/getcfg container-station Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
ls "${QPKG_ROOT}/bin/" | grep docker
# 输出：system-docker, system-docker-compose, docker（符号链接）

# 2. docker（对用户开放）
# 通过 /var/run/docker.sock 访问，这是 CS3 包装后提供给用户的 Docker

# 不要混用 system-docker 和 docker 管理同一个容器！
```

### 6.4 Docker 命令在 SSH 中找不到（CS3 升级后）

```sh
# CS3 安装路径中有 docker 二进制，但 PATH 可能未包含
QPKG_ROOT=$(/sbin/getcfg container-station Install_Path -f /etc/config/qpkg.conf 2>/dev/null)

# 检查 docker 在哪里
ls "${QPKG_ROOT}/bin/docker" 2>/dev/null
ls "${QPKG_ROOT}/usr/local/lib/docker/cli-plugins/" 2>/dev/null

# 临时添加到 PATH（当前 SSH 会话有效）
export PATH="${QPKG_ROOT}/bin:${QPKG_ROOT}/usr/local/lib/docker/cli-plugins:${PATH}"

# 验证
docker version
docker compose version

# 持久化（写入 /etc/config/profile 或 QPKG 启动时 export）
```

---

## 七、QuTS hero 与 QTS 的存储路径差异

QuTS hero（ZFS 版本，用于高端型号）与普通 QTS 在存储路径上有重要差异。

```sh
# 检测当前系统类型
cat /etc/os-release | grep NAME
# QTS: NAME="QTS"
# QuTS hero: NAME="QuTS hero"

# 动态检测主存储池路径（推荐写法）
if [ -d "/share/ZFS530_DATA" ]; then
    MAIN_VOL="/share/ZFS530_DATA"   # QuTS hero ZFS 存储池
elif [ -d "/share/CACHEDEV1_DATA" ]; then
    MAIN_VOL="/share/CACHEDEV1_DATA"  # QTS ext4 存储池
else
    # 通用查找方式
    MAIN_VOL=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info 2>/dev/null)
    MAIN_VOL="${MAIN_VOL%/}/_DATA"
fi

echo "主存储池路径: ${MAIN_VOL}"
ls "${MAIN_VOL}/.qpkg/" 2>/dev/null | head -10
```

QTS vs QuTS hero 核心差异：

| 项目 | QTS | QuTS hero |
|---|---|---|
| 文件系统 | ext4 | ZFS |
| 主存储池路径 | `/share/CACHEDEV1_DATA/` | `/share/ZFS530_DATA/` |
| 快照方式 | LVM 快照 | ZFS 原生快照（更高效） |
| 存储去重 | 通过 HBS3 | ZFS 原生去重 |
| 内存要求 | 较低 | 较高（ZFS 需要更多内存） |
| QPKG 安装路径 | `CACHEDEV1_DATA/.qpkg/` | `ZFS530_DATA/.qpkg/` |

**交叉验证（GitHub qnap-docker 项目）**：
```sh
# 该项目动态检测所有可能的存储池路径：
# /share/CACHEDEV1_DATA/docker  ← QTS
# /share/ZFS530_DATA/docker     ← QuTS hero
# /share/USB/backup             ← USB 存储
```

---

## 八、Docker 推荐目录结构

推荐结构：

```text
推荐目录结构：
/share/docker/              ← 创建为独立共享文件夹（不是子目录）
├── appdata/                ← 各容器配置和数据（按容器名分子目录）
│   ├── plex/
│   ├── jellyfin/
│   ├── portainer/
│   └── ...
├── compose/                ← Compose 项目文件（可用 git 管理）
│   ├── media-stack/
│   │   └── docker-compose.yml
│   └── ...
└── secrets/                ← 敏感信息（不要放进 git）
    ├── db_password.txt
    └── api_key.txt

/share/media/               ← 媒体文件（独立共享，便于权限管理）
/share/backup/              ← 备份目录
```

**为什么 `docker/` 要创建为独立共享文件夹而非子目录**：
- 可独立设置权限（只有 Docker 用户才能访问）
- 便于 HBS3 独立备份
- 避免与用户数据共享文件夹混用导致权限混乱

---

## 九、端口冲突预防（生产实践建议）

来自 QNAP-HomeLAB 等 GitHub 项目的端口规划建议：

```text
QTS 默认占用的端口：
- 8080 → QTS Web UI (HTTP)
- 443  → QTS Web UI (HTTPS)  ← 与 SSL 终止/反向代理冲突
- 80   → QTS Web Server      ← 与反向代理冲突
- 22   → SSH

如果要运行 Traefik/Nginx Proxy Manager 等反向代理，建议修改 QTS 端口：
- 8080 → 改为 8480（控制台 → 系统 → 常规设置 → 系统端口）
- 443  → 改为 8443
- 80   → 改为 8180（控制台 → 应用程序 → Web 服务器）
- 22   → 改为 22222（控制台 → 网络与文件服务 → Telnet/SSH → SSH 端口）

修改后 QTS 访问方式：
https://NAS_IP:8443   ← HTTPS 管理界面
http://NAS_IP:8480    ← HTTP 管理界面
```

---

## 十、qpkg.conf 文件变空（罕见但毁灭性）

**症状**：SSH 中 `cat /etc/config/qpkg.conf` 输出为空，所有 QPKG 路径无法解析，`docker` 命令找不到。

**原因**：
- 极端情况下 `/etc/config/qpkg.conf` 可能变为 0 字节
- 通常在 RAM disk 极度紧张时，写操作被截断导致

**诊断**：
```sh
ls -la /etc/config/qpkg.conf
# 如果显示 size 为 0，则已损坏
wc -l /etc/config/qpkg.conf   # 0 = 空文件
```

**处理**：
- 重启 NAS（QTS 会在启动时重建 qpkg.conf）
- 如果重启后仍为空，通过 QTS GUI → 应用中心重新安装/修复 QPKG
- 这种情况极为罕见，通常由 RAM disk 满触发

---

## 十一、/etc/hosts 不持久（某些型号）

```sh
# 在某些 QNAP 型号上，/etc/hosts 在 RAM disk 上
# 重启后 QNAP 会从模板重新生成，手动添加的条目消失

# 持久化 hosts 的正确方式：
# 通过 QTS GUI → 控制台 → 网络与虚拟交换机 → 主机名 → 编辑
# 或通过 autorun.sh 在启动时追加
```

---

## 十二、QNAP 特有的 /opt 目录结构

```sh
# /opt 目录是 QPKG 应用的软链接聚合点
# 每个 QPKG 启动时通常会创建：
ln -sf $QPKG_ROOT /opt/$QPKG_NAME

# /opt 目录本身可能在 RAM disk 或 /mnt/ext 上
# 重启后 /opt/ 中的软链接消失，由 QPKG 启动脚本重新创建
ls -la /opt/

# 如果 Entware 已安装：
ls /opt/bin/    # Entware 工具链
```

---

## 十三、调试和诊断速查

遇到"重启后配置丢失"、"文件消失"、"命令找不到"时的快速诊断：

```sh
# 1. 确认文件系统挂载情况
df -h | head -20

# 2. 确认操作的目标路径是否在持久存储上
readlink -f /path/to/target   # 解析软链接真实路径
# 如果解析结果不在 /share/ 或 /etc/config/ 下，重启后可能丢失

# 3. 确认 qpkg.conf 完整性
wc -l /etc/config/qpkg.conf

# 4. 确认 /mnt/ext 空间
df -h | grep ext

# 5. 确认 ramdisk 使用率
df -h | grep ' /$'

# 6. 查看启动日志
cat /var/log/qnap-agent-init.log 2>/dev/null | head -50
tail -50 /var/log/messages | grep -iE 'start|init|boot|mount'
```
