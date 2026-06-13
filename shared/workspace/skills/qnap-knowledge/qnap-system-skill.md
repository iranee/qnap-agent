---
name: qnap-system
description: QNAP QTS 系统结构、路径、服务管理、命令差异、QPKG 机制与系统级操作规范。
---

# QTS 系统核心知识

> 适用范围：QNAP QTS 5.x（兼容 4.5.x）
> 适用场景：系统查询、路径判断、服务管理、配置读取、QPKG 应用管理

---

## 一、【必读】QTS 文件系统持久化规则

> ⚠️ 这是 QTS 上最容易踩的坑。不理解这一点，很多操作重启后"失效"找不到原因。
> 详细陷阱见：`qnap-skills/qnap-quirks-skill.md`

### QTS 存储层次（哪些目录重启后消失）

```sh
# 快速检查当前目录的持久性
df -h | head -20
# 看 "/" 的挂载点类型：none/ramdisk/tmpfs → 内存盘，重启清空

# ❌ 重启后清空：
/                  # RAM disk 根目录（16-400MB）
/tmp/              # tmpfs
/root/             # 在 RAM disk 上
/var/run/          # 在 RAM disk 上（PID文件除外，这是正常行为）
/opt/              # 软链接聚合点，重启后由 QPKG 重新创建

# ✅ 重启后保留（持久化）：
/etc/config/       # QNAP 核心配置目录（挂载自 HDA_ROOT）
/share/            # 所有用户数据（HDD/SSD 上）
${QPKG_ROOT}/      # QPKG 安装目录（在 /share/ 上）
```

**实用规则**：
- 配置放 `/etc/config/`，数据放 `/share/`，工具放 `${QPKG_ROOT}/tools/`
- 所有临时操作（PID、日志临时文件）放 `/tmp/` 或 `/var/run/`（重启前有效）
- `/root/` 目录不持久，SSH 公钥实际存在 `/etc/config/ssh/authorized_keys`

## 二、QTS ≠ 标准 Linux

### 1.1 缺失或不完整的工具

| 标准 Linux 工具 | QTS 状态 | 正确做法 |
|---|---|---|
| `lsb_release` | 不存在 | `cat /etc/os-release` 或 `getcfg System Version` |
| `apt/dpkg/yum/dnf` | 不存在 | 禁止安装系统包 |
| `systemctl` | 不完整 | `/etc/init.d/<service> start/stop/restart/status` |
| `journalctl` | 不存在 | `cat /var/log/messages` + `dmesg` |
| `nohup` | 不存在 | `bash -c '...' & disown` |
| `timedatectl` | 不存在 | `date` + `getcfg` |
| `hostnamectl` | 不存在 | `hostname` + `getcfg System Hostname` |
| `useradd/usermod` | 存在但禁止使用 | QTS Web 界面管理 |
| `screen/tmux` | 不存在 | `bash -c '...' & disown` 或 `at` |
| `htop/glances` | 不存在 | `top`，或放到 `${QPKG_ROOT}/tools/` |
| `jq` | 不存在 | 放到 `${QPKG_ROOT}/tools/jq` |
| `smartctl` | 路径不标准 | `/usr/local/sbin/smartctl` 或 `tools/smartctl` |

### 1.2 Shell 环境

```sh
/bin/sh   →  BusyBox ash（不是 bash，某些语法不支持）
/bin/bash →  通常存在，但版本较旧（4.x）
```

**ash vs bash 关键差异（避免踩坑）：**

```sh
# ❌ bash 扩展语法，ash 不支持
[[ -f file ]]          → 改用  [ -f file ]
source ./config.sh     → 改用  . ./config.sh
arr=(a b c)            → ash 不支持数组
echo "${var,,}"        → ash 不支持大小写转换
$'\n'                  → ash 某些版本不支持

# ✅ POSIX 兼容写法
[ -f file ]
. ./config.sh
# 数组改用临时文件或变量拼接

# ❌ bash here-doc 在某些 ash 版本不稳定
cat << 'EOF'
content
EOF
# ✅ 更安全的写法
printf '%s\n' 'content'
```

---

## 二、QNAP 专有命令体系

### 2.1 getcfg / setcfg（最核心）

```sh
# 读取配置（格式：getcfg <Section> <Key> [-d <默认值>] -f <文件>）
/sbin/getcfg <应用名> Install_Path -f /etc/config/qpkg.conf
/sbin/getcfg System Model -f /etc/config/uLinux.conf
/sbin/getcfg System Version -f /etc/config/uLinux.conf
/sbin/getcfg System Build -f /etc/config/uLinux.conf
/sbin/getcfg System Hostname -f /etc/config/uLinux.conf
/sbin/getcfg eth0 IPAddress -f /etc/config/network.conf
/sbin/getcfg eth0 DHCP -f /etc/config/network.conf

# 查询默认共享路径名称
/sbin/getcfg SHARE_DEF defVolMP    -f /etc/config/def_share.info   # 主卷挂载点
/sbin/getcfg SHARE_DEF defWeb      -d Qweb -f /etc/config/def_share.info
/sbin/getcfg SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info
/sbin/getcfg SHARE_DEF defMultimedia -d Qmultimedia -f /etc/config/def_share.info

# 检查 QPKG 是否启用
/sbin/getcfg <AppName> Enable -u -d FALSE -f /etc/config/qpkg.conf
# 返回 TRUE → 已启用，FALSE → 已禁用

# 列出所有 QPKG 名称
/sbin/getcfg -f /etc/config/qpkg.conf -a | grep '^\[' | tr -d '[]'
```

### 2.2 QPKG 路径解析（两种方式，推荐 sed 方式更健壮）

```sh
# 方式一：getcfg（简单）
QPKG_ROOT=$(/sbin/getcfg <AppName> Install_Path -f /etc/config/qpkg.conf)

# 方式二：sed（更健壮，不依赖 getcfg 可执行路径）
QPKG_NAME="<AppName>"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf)

# 验证路径
echo "路径: ${QPKG_ROOT}"
ls "${QPKG_ROOT}"

# 读取应用启动脚本（了解应用结构）
ls "${QPKG_ROOT}"/*.sh 2>/dev/null
cat "${QPKG_ROOT}"/<AppName>.sh 2>/dev/null | head -80
```

### 2.3 服务管理

```sh
# QNAP 服务管理（标准方式）
/etc/init.d/<service> start
/etc/init.d/<service> stop
/etc/init.d/<service> restart
/etc/init.d/<service> status

# 列出所有服务
ls /etc/init.d/

# 常用服务
/etc/init.d/smbd        # Samba
/etc/init.d/nfsd        # NFS
/etc/init.d/ftpd        # FTP
/etc/init.d/sshd        # SSH
/etc/init.d/Qthttpd     # QTS Web 服务器（启停影响 QTS 界面！）
/etc/init.d/dlna        # DLNA
```

### 2.4 系统通知（QNAP 专用）

```sh
# 发送系统通知（用于 QPKG 服务安装/启动提示）
/usr/local/sbin/notify send -A A039 -C C001 -M 46 -l info -t 3 \
  "[{0}] {1} {2} 已成功安装" "qnap-agent" "Agent" "1.0"
```

---

## 三、当前 qnap-agent 路径基准

```sh
QPKG_NAME="qnap-agent"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
```

| 路径 | 说明 |
|---|---|
| `${QPKG_ROOT}/qnap-agent.sh` | 服务主脚本（start/stop/restart） |
| `${QPKG_ROOT}/init-system.sh` | 初始化脚本 |
| `${QPKG_ROOT}/watchdog.sh` | 看门狗进程 |
| `${QPKG_ROOT}/update/` | 升级包目录 |
| `${QPKG_ROOT}/backup/` | 备份目录 |
| `${QPKG_ROOT}/run/` | PID 文件目录（如 `agent.pid`） |
| `${QPKG_ROOT}/log/` | 日志目录 |
| `${QPKG_ROOT}/scripts/` | 辅助脚本 |
| `${QPKG_ROOT}/tools/` | 额外工具（jq、ffprobe、静态二进制） |
| `${QPKG_ROOT}/workspace/` | PicoClaw 工作目录 |
| `${QPKG_ROOT}/picoclaw` | 主程序 |
| `${QPKG_ROOT}/picoclaw-launcher` | Launcher |
| `${QPKG_ROOT}/workspace/config.json` | 运行配置 |
| `${QPKG_ROOT}/workspace/.security.yml` | 凭据文件 |
| `${QPKG_ROOT}/workspace/skills/` | 技能目录 |
| `${QPKG_ROOT}/workspace/sessions/` | 会话目录 |
| `${QPKG_ROOT}/workspace/memory/` | 记忆目录 |
| `${QPKG_ROOT}/workspace/state/` | 状态目录 |
| `${QPKG_ROOT}/workspace/cron/` | 定时任务目录 |

**qnap-agent 自身服务管理（可自行执行，无需确认）：**
```sh
${QPKG_ROOT}/qnap-agent.sh status
${QPKG_ROOT}/qnap-agent.sh restart
```

---

## 四、系统关键路径

```text
/share/                           共享文件夹挂载入口
/share/CACHEDEV1_DATA/            存储池 1 数据根目录
/share/CACHEDEV2_DATA/            存储池 2 数据根目录
/share/CACHEDEV1_DATA/.qpkg/     所有 QPKG 应用安装目录
/etc/config/                      QNAP 配置目录（写入需确认）
/etc/config/qpkg.conf             QPKG 安装记录
/etc/config/uLinux.conf           系统信息
/etc/config/network.conf          网络配置
/etc/config/smb.conf              Samba 配置
/etc/config/def_share.info        默认共享路径映射
/var/log/messages                 系统主日志
/var/run/                         PID 文件目录
/tmp/                             临时目录（重启后清空）
```

---

## 五、常用系统查询命令

```sh
# 系统版本
cat /etc/os-release
uname -a
/sbin/getcfg System Model -f /etc/config/uLinux.conf
/sbin/getcfg System Version -f /etc/config/uLinux.conf

# 硬件
cat /proc/cpuinfo | grep -E 'model name|processor' | sort -u
free -m
cat /proc/meminfo | grep -E 'MemTotal|MemFree|Cached'

# 存储
df -h
lsblk
cat /proc/mdstat
mount | grep share

# 网络
ip addr show
ip route show

# 进程
ps aux | head -30
uptime
vmstat 1 3

# 日志
tail -100 /var/log/messages
dmesg | tail -30
```

---

## 六、后台任务运行

QTS 无 `nohup`，运行后台任务的正确方式：

```sh
# 方式一（推荐）
bash -c 'long_command > /tmp/output.log 2>&1' & disown

# 方式二：带 PID 记录
bash -c 'long_command > /tmp/output.log 2>&1 & echo $! > /var/run/task.pid'

# 查看后台任务
jobs
ps aux | grep long_command
```

---

## 七、额外工具安装（只能用静态二进制）

```sh
TOOLS_DIR="${QPKG_ROOT}/tools"
mkdir -p "${TOOLS_DIR}"

# 示例：jq（JSON 处理工具）
# 检查架构
uname -m   # x86_64 / aarch64 / armv7l

# x86_64 静态 jq （实际已内置jq命令）
curl -L "https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64" \
  -o "${TOOLS_DIR}/jq"
chmod +x "${TOOLS_DIR}/jq"

# 使用
"${TOOLS_DIR}/jq" '.key' data.json
PATH="${TOOLS_DIR}:${PATH}" jq '.key' data.json

# 禁止：不使用 apt/yum/opkg/pip 安装任何工具
```

---

## 八、Entware 说明（了解，不主动推荐）

Entware 是 QNAP 上的第三方包管理器（通过 QPKG 安装），安装后可以用 `opkg install` 安装 Linux 工具。

**了解但限制使用：**
- Entware 安装后 `opkg` 命令可用，但仅建议在充分了解风险的情况下使用
- `opkg install` 安装的包与 QTS 系统隔离，安装到 `/opt/`，一般不影响系统稳定性
- **不用于 qnap-agent 自身的依赖**（qnap-agent 使用 tools/ 目录中的静态二进制）

```sh
# 检查 Entware 是否安装
ls /opt/bin/opkg 2>/dev/null
QPKG_ROOT=$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
echo "Entware: ${QPKG_ROOT}"
```

---

## 九、日志查看

```sh
# 系统日志
tail -100 /var/log/messages
grep -iE 'error|fail|warn|critical' /var/log/messages | tail -50
dmesg | grep -iE 'error|fail|I/O' | tail -20

# qnap-agent 日志
tail -50 "${QPKG_ROOT}/log/watchdog.log" 2>/dev/null
tail -50 "${QPKG_ROOT}/log/qnap-agent.log" 2>/dev/null
cat /var/log/qnap-agent-init.log 2>/dev/null | head -100

# QPKG 安装日志
cat /var/log/qpkg*.log 2>/dev/null | tail -50
```

---

## 十、crontab 持久化（QTS 特有规则）
# 一般不建议使用此功能，尽量用agent自带的cron工具

```sh
# 正确的写入方式（持久化）
echo "0 2 * * * ${QPKG_ROOT}/scripts/daily_task.sh" >> /etc/config/crontab

# 激活（必须，否则 cron 守护进程不读新配置）
crontab /etc/config/crontab
/etc/init.d/crond.sh restart

# 错误的写入方式（重启后失效）
# crontab -e   ← 某些 QTS 版本写入的是内存，重启丢失

# 验证生效
crontab -l | grep task
```

---

## 十一、禁止事项

- **禁止安装系统包**（apt/yum/opkg/pip/npm/gem）
- **禁止修改系统用户**（passwd/useradd/usermod）
- **禁止清空防火墙**（iptables -F）
- **禁止在 /bin、/sbin、/usr 等系统目录写入文件**
- **不要把 QTS 当 Ubuntu/Debian/CentOS 操作**
- **脚本一律使用 POSIX sh 语法**（兼容 BusyBox ash）
- **不要在 RAM disk 位置存放重要数据**（/root、/tmp、/var 非配置部分）

---

## 十一、QPKG 命令行安装方式

当需要安装未在 App Center 上架的 QPKG 时，可通过命令行安装：

```sh
# 方法一：直接执行 .qpkg 文件（推荐）
sh /share/Public/PackageName_1.0.0_x86_64.qpkg

# 安装成功标志（日志末尾显示）：
# [App Center] Installed <PackageName> 1.0.0 in /share/CACHEDEV1_DATA/.qpkg/<PackageName>

# 方法二：通过系统安装器（另一种方式）
/usr/sbin/qpkg_cli --install /share/Public/PackageName.qpkg

# 安装完成后清理安装包
rm -f /share/Public/PackageName.qpkg
```

**安装前提条件：**
- App Center → 设置（齿轮图标）→ 允许安装未经数字签名的应用
- 安装包必须在 `/share/` 目录下（RAM disk 外），否则重启后找不到文件

**查看安装结果：**
```sh
/sbin/getcfg <PackageName> Install_Path -f /etc/config/qpkg.conf
/sbin/getcfg <PackageName> Enable -f /etc/config/qpkg.conf
```

---

## 十二、Apache Web 服务器（QTS 内置）配置

QTS 内置 Apache Web 服务器（通过"Web 服务器"功能启用），可托管 Web 应用。

### 12.1 关键路径

```sh
# 虚拟主机用户配置文件（通过 GUI 添加 vhost 后自动生成）
cat /etc/config/apache/extra/httpd-vhosts-user.conf

# Web 根目录
ls /share/Web/

# 重载 Web 服务器配置（修改 vhost 后执行）
/etc/init.d/Qthttpd.sh reload

# 重启 Web 服务器
/etc/init.d/Qthttpd.sh restart
```

### 12.2 vhost 配置结构

```text
控制台 → 应用程序 → Web 服务器 → 虚拟主机 → 新建虚拟主机：
- 主机名：blog.nas.local
- 目录：/share/Web/myapp
- 协议：HTTP / HTTPS
- 端口：80 / 443
```

GUI 操作后配置写入 `/etc/config/apache/extra/httpd-vhosts-user.conf`，内容示例：

```apache
<VirtualHost *:80>
    ServerName blog.nas.local
    DocumentRoot "/share/Web/myapp"
    <Directory "/share/Web/myapp">
        Options FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

### 12.3 Let's Encrypt SSL 证书

```text
控制台 → 安全 → SSL 证书与私钥 → 从 Let's Encrypt 获取证书
（需要：已有有效域名 + 该域名指向 NAS 公网 IP）

配合 myQNAPcloud 的 DDNS 功能可以自动更新 IP。
```

**注意：** 修改 vhost 配置文件属于灰区操作，建议通过 GUI 操作，修改后须执行 `Qthttpd.sh reload`。
