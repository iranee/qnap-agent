---
name: qnap-cli-reference
description: QNAP QTS 常用命令、配置读取方式与命令选择参考速查表。
---

# QNAP QTS CLI 命令速查参考

> 适用范围：QNAP QTS 5.x（兼容 4.5.x）
> 适用场景：需要选择正确 QTS 命令，或判断标准 Linux 命令是否可用时

---

## 一、配置文件读写

```sh
# 读取配置
/sbin/getcfg <Section> <Key> -f <文件路径>

# 写入配置（灰区操作，需确认）
/sbin/setcfg <Section> <Key> <Value> -f <文件路径>

# 常用读取示例
/sbin/getcfg System Model -f /etc/config/uLinux.conf
/sbin/getcfg System Version -f /etc/config/uLinux.conf
/sbin/getcfg System Build -f /etc/config/uLinux.conf
/sbin/getcfg System Hostname -f /etc/config/uLinux.conf

# 读取任意应用安装路径
/sbin/getcfg <应用名> Install_Path -f /etc/config/qpkg.conf

# 动态解析安装目录（脚本推荐写法，更健壮）
QPKG_NAME="container-station"
QPKG_DIR=$(/bin/sed -nr ":s /^\[$QPKG_NAME\]/ b o; n; b s; :o n; /^\[/ q; /^Install_Path[ ]*=/ {s/.*=[ ]*// p; q;} b o;" "/etc/config/qpkg.conf")
```

---

## 二、QPKG 包管理

```sh
# 列出所有已安装 QPKG
/sbin/getcfg -f /etc/config/qpkg.conf -a | grep '^\[' | tr -d '[]'

# 查询单个包状态
# 查询应用状态: /sbin/getcfg <AppName> Enable -f /etc/config/qpkg.conf

# 列出所有包及状态
# 列出所有QPKG: /sbin/getcfg -f /etc/config/qpkg.conf -a | grep '^[' | tr -d '[]'

# 安装 QPKG（通过本地文件）
/usr/sbin/qpkg_cli --install <qpkg文件路径>

# 调阅第三方应用目录（只读）
QPKG_NAME="<应用名>"
QPKG_DIR=$(/bin/sed -nr ":s /^\[$QPKG_NAME\]/ b o; n; b s; :o n; /^\[/ q; /^Install_Path[ ]*=/ {s/.*=[ ]*// p; q;} b o;" "/etc/config/qpkg.conf")
ls "${QPKG_DIR}"
ls "${QPKG_DIR}"/*.sh 2>/dev/null
```

约束：
- 除 `qnap-agent` 自身目录外，`.qpkg/<app>` 目录按只读处理
- 不写入、不覆盖、不替换第三方应用文件

---

## 三、存储与磁盘命令

```sh
# 磁盘使用
df -h
df -h /share/

# 块设备列表
lsblk
cat /proc/partitions

# 挂载信息
mount | grep share

# LVM（存储池/卷）
/usr/sbin/lvm lvs 2>/dev/null    # 逻辑卷
/usr/sbin/lvm vgs 2>/dev/null    # 卷组
/usr/sbin/lvm pvs 2>/dev/null    # 物理卷

# RAID 状态
cat /proc/mdstat
mdadm --detail /dev/md0 2>/dev/null

# 磁盘信息
hdparm -I /dev/sda | grep -E 'Model|Serial|Firmware|capacity'
smartctl -H /dev/sda 2>/dev/null
```

---

## 四、网络命令

```sh
# 网络接口
ip addr show
ip route show

# 端口监听
netstat -tlnp 2>/dev/null || ss -tlnp
netstat -ulnp 2>/dev/null || ss -ulnp

# 连通性
ping -c 4 8.8.8.8
nslookup google.com
curl -I --connect-timeout 5 https://www.google.com

# DNS
cat /etc/resolv.conf
cat /etc/hosts

# 防火墙（只读）
iptables -L -n -v 2>/dev/null
```

---

## 五、进程与资源命令

```sh
# 进程列表
ps aux
ps aux | grep <进程名> | grep -v grep

# 内存
free -m
cat /proc/meminfo | grep -E 'MemTotal|MemFree|Cached|Buffers'

# CPU
uptime
cat /proc/cpuinfo | grep -E 'model name|cpu MHz|processor' | sort -u

# 磁盘 I/O
iostat -x 1 3 2>/dev/null

# 系统负载和资源综合
vmstat 1 5

# Docker 资源
docker stats --no-stream
```

---

## 六、日志命令

```sh
# 系统主日志
tail -100 /var/log/messages
grep -iE 'error|fail|warn|critical' /var/log/messages | tail -50

# 内核日志
dmesg | tail -30
dmesg | grep -iE 'error|fail|I/O error'

# qnap-agent 日志
tail -50 ${QPKG_ROOT}/log/watchdog.log
tail -50 ${QPKG_ROOT}/log/qnap-agent.log
cat /var/log/qnap-agent-init.log

# Docker 日志
docker logs <容器名>
docker logs --tail 100 <容器名>
```

---

## 七、服务管理命令

```sh
# 标准 QTS 服务管理
/etc/init.d/<服务名> start
/etc/init.d/<服务名> stop
/etc/init.d/<服务名> restart
/etc/init.d/<服务名> status

# 列出所有服务脚本
ls /etc/init.d/

# 常用服务
/etc/init.d/smbd         # Samba
/etc/init.d/nfsd         # NFS
/etc/init.d/ftpd         # FTP
/etc/init.d/sshd         # SSH
/etc/init.d/dlna         # DLNA

# qnap-agent 自身服务（可自行执行）
${QPKG_ROOT}/qnap-agent.sh status
${QPKG_ROOT}/qnap-agent.sh restart
```

---

## 八、文件操作命令

```sh
# 查找
find /share/<路径>/ -name "*.mp4" 2>/dev/null
find /share/<路径>/ -type f -size +1G 2>/dev/null
find /share/<路径>/ -type f -mtime -7 2>/dev/null

# 复制（带进度）
rsync -avh --progress /share/source/ /share/target/

# 压缩/解压
tar czf archive.tar.gz /share/target/
tar xzf archive.tar.gz -C /share/dest/
zip -r archive.zip /share/target/
unzip archive.zip -d /share/dest/

# 权限查看
ls -la /share/<路径>/
stat /share/<路径>/文件名
getfacl /share/<路径>/文件名 2>/dev/null
```

---

## 九、qnap-agent 路径速查

```text
${QPKG_ROOT}/qnap-agent.sh             服务脚本
${QPKG_ROOT}/init-system.sh            初始化脚本
${QPKG_ROOT}/watchdog.sh               看门狗脚本
| `${QPKG_ROOT}/workspace/`                 PicoClaw 工作目录
| `${QPKG_ROOT}/picoclaw`                   主程序
| `${QPKG_ROOT}/picoclaw-launcher`          Launcher
| `${QPKG_ROOT}/workspace/config.json`      运行配置
| `${QPKG_ROOT}/workspace/.security.yml`    凭据文件
| `${QPKG_ROOT}/workspace/skills/`          技能目录
| `${QPKG_ROOT}/workspace/sessions/`        会话目录
| `${QPKG_ROOT}/workspace/memory/`          记忆目录
| `${QPKG_ROOT}/workspace/state/`           状态目录
| `${QPKG_ROOT}/workspace/cron/`            定时任务目录
${QPKG_ROOT}/update/                   升级包目录
${QPKG_ROOT}/backup/                   备份目录
${QPKG_ROOT}/run/                      PID 文件目录
${QPKG_ROOT}/log/                      日志目录
${QPKG_ROOT}/scripts/                  辅助脚本目录
${QPKG_ROOT}/tools/                    额外工具目录
```

---

## 十、Linux vs QTS 命令对照

| 标准 Linux | QTS 状态 | 正确做法 |
|---|---|---|
| `systemctl status <svc>` | 不完整 | `/etc/init.d/<svc> status` |
| `journalctl -xe` | 不存在 | `tail /var/log/messages` |
| `apt install <pkg>` | 禁止 | 下载静态二进制到 tools/ |
| `source file.sh` | ash 不支持 | `. file.sh` |
| `[[ condition ]]` | bash 扩展 | `[ condition ]` |
| `lsb_release -a` | 不存在 | `cat /etc/os-release` |
| `timedatectl` | 不存在 | `date` + `getcfg` |
| `nohup cmd &` | 不存在 | `bash -c 'cmd' & disown` |

---

## 十一、命令选择原则

1. 优先用 QTS 原生命令（getcfg、/etc/init.d/）
2. 不确定时先查 `ls /etc/init.d/`、`cat /etc/config/`
3. 不要把 Debian/Ubuntu/CentOS 的习惯直接搬到 QTS
4. 脚本优先使用 POSIX sh 语法（兼容 BusyBox ash）
5. 工具不存在时放到 ${QPKG_ROOT}/tools/，不安装系统包

---

## 十二、工具下载安全规范

> 适用范围：通过 curl/wget 下载工具二进制到 tools/ 目录的场景
> 触发场景：用户要求下载工具、升级工具版本、替换 tools/ 中的二进制文件

### 12.1 确认正确的下载链接

GitHub Release 的下载 URL 格式：

- **正确**：`https://github.com/<owner>/<repo>/releases/download/<tag>/<binary-file>`
- **错误**：`https://github.com/<owner>/<repo>`（这是首页 HTML）
- **错误**：`https://github.com/<owner>/<repo>/releases/tag/<tag>`（这是 Release 页面 HTML）

**黄金法则：URL 最后一级路径应该是文件名，而不是页面路径。**

### 12.2 下载前必须执行的预检

先用 HEAD 请求检查链接是否返回二进制：

```sh
curl -sI "https://github.com/<owner>/<repo>/releases/download/<tag>/<binary>" | grep -i content-type
```

- 期望输出：`content-type: application/octet-stream` 或 `application/gzip`
- 危险输出：`content-type: text/html`（说明下载到的是网页，不是文件！）

### 12.3 先下载到临时文件，确认后再移动

```sh
# 1. 下载到临时文件
curl -L -o /tmp/new-tool "https://..."

# 2. 验证文件类型
file /tmp/new-tool
# 期望：ELF 64-bit LSB executable, ... 或 GZip compressed data

# 3. 检查文件大小，确认合理
ls -lh /tmp/new-tool
# >= 几百 KB 才可能是真正的二进制

# 4. 确认无误后，备份旧文件（安全第一！）
cp tools/sqlite3 tools/sqlite3.bak.$(date +%Y%m%d%H%M%S)

# 5. 移动新文件到位
cp /tmp/new-tool tools/sqlite3
chmod +x tools/sqlite3

# 6. 基本功能测试
tools/sqlite3 --version 2>&1 || tools/sqlite3 -version 2>&1
```

### 12.4 常见下载陷阱

| 场景 | 陷阱 | 正确做法 |
|------|------|----------|
| GitHub Release 下载 | 直接访问仓库主页或 Release 页获取的是 HTML | 必须使用 Release 附件直链（`/releases/download/<tag>/<file>`）|
| GitHub 镜像站 | 镜像站可能返回不同的内容类型 | 同样用 `curl -sI` 预检 |
| SourceForge | 下载页面通常是 HTML | 使用直接链接，或用 `wget` 配合 cookie |
| 官方站经过 CDN | 可能返回 302 重定向到 CDN | 用 `-L` 跟随重定向 |
| raw.githubusercontent.com | 获取源码时可能拿到 HTML 非代码 | 确认路径为 `/raw/` 而非 `/blob/` |

### 12.5 事故恢复流程

如果不慎下载了无效文件覆盖了原来的工具：

1. **立即停止使用该工具**，避免产生更多错误
2. **检查是否有备份**：`ls -la tools/<tool>*bak*`
3. **如有备份**：`cp tools/<tool>.bak.<date> tools/<tool>`
4. **如无备份**：从其他来源重新获取正确版本（已安装的 QPKG 中的同名工具、官方发布页手动下载等）
5. **恢复后验证**：`file tools/<tool> && tools/<tool> --version`

### 12.6 预防措施

- **能用就别动** — 好用的工具不主动升级
- **必须升级时，保留旧备份** — 备份原文件后再替换
- **先验证后覆盖** — 始终使用 12.3 的步骤：临时文件 → 验证 → 备份 → 移动
- **对 GitHub Release 链接保持警惕** — 确认 URL 结构正确后再使用
