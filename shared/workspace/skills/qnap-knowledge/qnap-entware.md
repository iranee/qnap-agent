---
name: qnap-entware
description: QNAP QTS 上的 Entware 包管理器完整指南。包含利弊决策、安装方法、3500+ 可用软件包、agent 工具集成、常见故障排查。当 agent 需要某个工具但 tools/ 目录没有时，优先参考本文件。
---

# Entware — QTS 上的 Linux 工具生态

> 适用范围：QTS 5.x / 4.5.x，所有架构（x86_64、aarch64、armv7）

> **权限说明：** 如果用户已安装 Entware 插件，则允许在 Entware 内部使用 `opkg`、`pip3` 等命令（用于更新 Entware 内的依赖包、插件包）。**仅限影响 `/opt/` 目录内部的操作，不影响 QTS 系统文件。**

---

## 一、Entware 是什么

Entware 是为嵌入式 Linux（路由器、NAS）设计的第三方软件包管理器，基于 OpenWrt 的 `opkg`，现有 **3500+ 可安装软件包**。

它解决了 QTS 上最根本的工具缺失问题：

```text
QTS 内置工具（BusyBox）:  简化版 grep、sed、awk、find...功能有限
Entware 工具:             GNU 完整版 grep、sed、awk、find + jq、python3、git、htop 等
```

**与 tools/ 静态二进制方式的对比**：

| 对比维度 | tools/ 静态二进制 | Entware opkg |
|---|---|---|
| 安装方式 | 手动 curl 下载单个文件 | `opkg install <包名>`，一条命令 |
| 可用工具数量 | 有限（需要有人编译并上传静态版） | 3500+ 包（含大量无静态版的工具） |
| 依赖管理 | 手动处理 | opkg 自动解决依赖 |
| 版本更新 | 手动 | `opkg upgrade` |
| Python 生态 | 无法支持 pip 包 | python3 + python3-pip，完整 pip 生态 |
| 编译工具 | 无 | gcc、make、cmake（有限支持） |
| 系统隔离 | 完全隔离（/share/）| 安装到 /opt/，与 QTS 系统隔离 |
| 官方支持 | 无需安装任何依赖 | 需先安装 Entware QPKG |
| 重启持久性 | 完全持久 | QPKG 重启自动 mount /opt/ |

**结论**：对于需要频繁使用多种工具、需要 Python 生态、需要工具之间有依赖关系的场景，Entware 远优于手动下载静态二进制。

---

## 二、利弊分析与决策建议

### 2.1 好处（大于弊端）

```text
✅ 3500+ 工具：jq、htop、ncdu、python3、git、ffmpeg、imagemagick、nano 等一应俱全
✅ pip 生态：python3-pip 安装后可用所有 PyPI 包
✅ 一条命令安装：opkg install jq ncdu htop python3
✅ 自动依赖解决：不需要手动处理 .so 库文件
✅ GNU 完整工具：grep、awk、sed、find 完整版，支持所有标准选项
✅ 与 QTS 系统完全隔离：安装到 /opt/，不污染系统目录
✅ 重启后持久：QPKG 机制保证 /opt/ 每次重启自动挂载
✅ 无法用静态二进制的工具：如 python3 pip 包、需要 glibc 的工具等
```

### 2.2 弊端与风险

```text
⚠️ 非 QNAP 官方支持：问题需要到 Entware 社区/论坛寻求帮助
⚠️ /opt 目录冲突：极少数其他 QPKG 也使用 /opt，需要用 SortMyQPKGs 调整加载顺序
⚠️ QTS 固件大版本升级后可能被禁用：需要手动重新 enable（一条命令，不是重装）
⚠️ 不能与 Optware/Qnapware 共存（这两个已淘汰，通常不是问题）
⚠️ opkg upgrade 偶有库版本冲突（影响少数包，非常罕见）
⚠️ 某些包在 QTS 的 Linux 内核版本上可能有兼容性问题
```

### 2.3 推荐决策流程

当用户询问是否值得安装 Entware 时，按此逻辑决策：

```text
是否满足以下任一条件？

① 需要 python3 + pip 安装任何 PyPI 包
② 需要 git、jq、htop、ncdu、nano 等常用工具
③ 需要同时使用 3 个以上工具（每个都要单独下载静态二进制很麻烦）
④ 需要 GNU 完整版的 grep/awk/sed（BusyBox 版功能不够）
⑤ 对 agent 的工具调用能力有较高期望

→ 满足任意一条：建议安装，好处明显大于弊端

都不满足（只需要 1-2 个工具）：
→ 用 tools/ 静态二进制即可，不需要 Entware
```

**推荐话术**（向用户说明时）：

> Entware 是专为 QNAP 这类嵌入式 Linux 设计的软件包管理器，类似 Ubuntu 的 apt。安装后可以一条命令安装 3500+ 工具，包括 Python3、jq、git、htop 等，且与 QTS 系统完全隔离，不影响系统稳定性。主要的注意事项是 QTS 大版本升级后可能需要重新启用（一条命令即可），以及极个别场景下与其他第三方 QPKG 的 /opt 目录冲突。对于需要多种工具的场景，安装 Entware 的收益远大于风险。

---

## 三、安装前检查

```sh
# 1. 检查是否已安装
/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf 2>/dev/null
# 如果有输出 → 已安装，跳到第五节

# 2. 检查是否有冲突（Optware/Qnapware 不能共存）
/sbin/getcfg Optware Install_Path -f /etc/config/qpkg.conf 2>/dev/null
/sbin/getcfg Qnapware Install_Path -f /etc/config/qpkg.conf 2>/dev/null
# 如果有输出 → 必须先卸载 Optware/Qnapware

# 3. 查看系统架构（决定安装哪个版本）
uname -m
# x86_64    → 标准 x86_64 版本（大多数 i3/i5/i7/Celeron NAS）
# aarch64   → arm64 版本（如 TS-x33、部分新款 ARM NAS）
# armv7l    → armv7 版本（较老的 ARM NAS）

# 4. 检查 /opt 是否被其他 QPKG 占用
ls -la /opt/ 2>/dev/null | head -20
# 如果 /opt 已有内容（非 Entware），需要处理冲突
```

---

## 四、安装方法

### 4.1 方法A：通过 App Center 手动安装（推荐，最简单）

```text
# Step 1：下载 Entware QPKG
下载地址：https://bin.entware.net/other/Entware_1.03std.qpkg
（或从 myqnap.org 或 qnapclub.eu 搜索 Entware）

# Step 2：App Center → 右上角 "+" → 手动安装 → 选择 .qpkg 文件
# （如果提示"需要签名"→ App Center 设置 → 允许未签名安装 → 再安装）

# Step 3：安装完成后，打开新的 SSH 会话（不要用已有的会话）
```

### 4.2 方法B：SSH 命令行安装

```sh
# 下载 QPKG 到 NAS（替换为最新版本的 URL）
cd /share/Public
wget https://bin.entware.net/other/Entware_1.03std.qpkg

# 安装
sh Entware_1.03std.qpkg

# 安装成功的标志（日志末尾会显示）：
# [App Center] Installed Entware-std 1.03 in /share/CACHEDEV1_DATA/.qpkg/Entware.

# 清理安装包
rm -f /share/Public/Entware_1.03std.qpkg
```

### 4.3 安装后：配置 PATH（关键步骤）

Entware 工具安装在 `/opt/bin/` 和 `/opt/sbin/`，需要让 SSH 会话能找到这些命令。

**重新开一个 SSH 会话**（不要用安装时的会话）。如果仍然找不到 opkg：

```sh
# 手动 source profile（当前会话立即生效）
source /opt/etc/profile

# 验证
opkg --version
which opkg   # 应输出 /opt/bin/opkg

# 如果使用非 admin 账户登录，还需要：
echo 'source /opt/etc/profile' >> /etc/config/profile
# 下次 SSH 登录自动生效
```

### 4.4 验证安装成功

```sh
opkg update       # 更新包列表（从 bin.entware.net 拉取）
opkg list | wc -l # 应显示 3000+ 行

# 测试安装一个包
opkg install jq
jq --version     # 应显示版本号
```

---

## 五、Entware 基础操作

```sh
# 更新包列表（类似 apt update）
opkg update

# 搜索包
opkg find <关键词>    # 精确搜索包名
opkg list | grep jq  # 过滤方式搜索
opkg search jq       # 搜索哪个包包含 jq

# 查看包详情
opkg info jq         # 版本、依赖、大小、描述

# 安装包
opkg install jq
opkg install jq python3 git htop ncdu   # 批量安装

# 卸载包
opkg remove jq
opkg remove --autoremove jq   # 同时删除不再需要的依赖

# 查看已安装的包
opkg list-installed
opkg list-installed | grep python   # 过滤

# 升级所有包（谨慎）
opkg upgrade       # 升级所有已安装的包（可能有依赖风险，见注意事项）
opkg upgrade jq    # 只升级单个包（更安全）

# 查看包文件
opkg files jq      # 查看 jq 安装了哪些文件
```

---

## 六、agent 常用工具包清单

### 6.1 JSON 处理与 API 调用

```sh
opkg install jq     # JSON 处理（agent 最常用工具之一）
opkg install curl   # HTTP 请求（Entware 版支持更完整的 SSL/TLS）

# jq 使用示例（比 QTS 自带工具强大得多）
echo '{"key":"value","arr":[1,2,3]}' | jq '.key'
docker inspect <容器名> | jq '.[0].State.Status'
cat config.json | jq '.providers[].name'
```

### 6.2 系统诊断工具

```sh
opkg install htop      # 交互式进程监视器（top 的强化版）
opkg install iotop     # 实时磁盘 I/O 监视（排查 IO 等待问题）
opkg install iftop     # 实时网络流量监视（按连接统计）
opkg install nethogs   # 按进程统计网络带宽（排查哪个进程占网络）
opkg install ncdu      # 交互式磁盘使用分析（快速找大文件/目录）
opkg install atop      # 综合系统资源监控（含历史记录）
opkg install lsof      # 查看进程打开的文件/端口
opkg install strace    # 进程系统调用跟踪（高级调试）

# ncdu 示例（替代 du + sort 的组合）
ncdu /share/<共享名>   # 交互式界面，用方向键浏览，直观看大小
ncdu -x /share/       # -x 不跨文件系统
```

### 6.3 文本处理（GNU 完整版）

```sh
# BusyBox 的 grep/awk/sed 功能有限，Entware 提供 GNU 完整版
opkg install grep      # GNU grep（支持 -P PCRE 正则等）
opkg install gawk      # GNU awk（mawk/nawk 的超集）
opkg install sed       # GNU sed（更多选项）
opkg install coreutils # GNU coreutils（ls、cat、sort、uniq 等完整版）
opkg install findutils # GNU find（支持 -printf 等高级选项）
opkg install diffutils # diff、cmp、patch 工具集
opkg install less      # 翻页查看文件（比 more 好用）
opkg install nano      # 简单文本编辑器（比 vi 对新手友好）
opkg install tree      # 目录树显示

# GNU grep 与 BusyBox grep 的区别
grep -P '\d+\.\d+\.\d+\.\d+' /var/log/messages  # -P PCRE，BusyBox 不支持
grep --color=auto 'error' /var/log/messages      # 颜色高亮
```

### 6.4 Python 生态（重要）

```sh
opkg install python3        # Python 3.x
opkg install python3-pip    # pip 包管理器
opkg install python3-openssl # SSL 支持（很多 pip 包需要）

# pip 安装 PyPI 包
pip3 install requests       # HTTP 库
pip3 install paramiko       # SSH 库
pip3 install pyyaml         # YAML 解析
pip3 install psutil         # 系统信息库

# 注意：pip3 install 的包安装到 /opt/lib/python3.x/site-packages/
# 而不是 /usr/lib/，与 QTS 系统 Python 完全隔离

# Python 路径
which python3    # /opt/bin/python3
python3 --version

# 使用示例
python3 -c "import json; print(json.loads('{\"a\":1}'))"
python3 -c "import subprocess; print(subprocess.getoutput('df -h'))"
```

### 6.5 版本控制与开发工具

```sh
opkg install git       # Git 版本控制
opkg install git-http  # Git HTTP 支持（git clone https://...）

# Git 配置
git config --global user.name "Agent"
git config --global user.email "agent@nas"

# 注意：git 配置文件保存在 ~/.gitconfig，而 ~ 在 RAM disk 上
# 持久化方式：将 .gitconfig 放在 /etc/config/ 并建立软链接
cp ~/.gitconfig /etc/config/.gitconfig 2>/dev/null || true
ln -sf /etc/config/.gitconfig ~/.gitconfig
```

### 6.6 网络工具

```sh
opkg install nmap      # 网络扫描
opkg install netcat    # nc 网络测试（nc -zv host port）
opkg install socat     # 多功能流转发工具
opkg install tcpdump   # 网络抓包（排查网络问题）
opkg install wget      # Entware wget（支持更多 SSL 选项）
opkg install bind-dig  # dig DNS 查询工具（比 nslookup 更强）

# 端口连通性测试
nc -zv 192.168.1.100 445 2>&1

# DNS 查询
dig qnap.com
dig @8.8.8.8 qnap.com
```

### 6.7 媒体工具

```sh
opkg install ffmpeg    # 音视频处理（如果系统没有）
opkg install mediainfo # 媒体文件详细信息
opkg install imagemagick  # 图片处理（convert、identify 等）

# 注意：Entware 的 ffmpeg 与 QTS 内置的 ffmpeg 是两个独立版本
# Entware 版可能更新，但没有 QTS 的硬件加速支持
```

### 6.8 数据处理工具

```sh
opkg install sqlite3    # SQLite 数据库命令行工具
opkg install rsync      # rsync（Entware 版，可能比系统版更新）
opkg install pv         # Pipe Viewer（进度条，如 cat file | pv | gzip > file.gz）
opkg install progress   # 显示 cp/mv/dd 进度
opkg install unzip      # 解压缩
opkg install zip        # 压缩
opkg install p7zip      # 7zip 解压
opkg install xz-utils   # xz 压缩
```

### 6.9 agent 推荐一次性安装的核心工具集

```sh
# 更新包列表
opkg update

# agent 核心工具集（按使用频率排序）
opkg install \
    jq \
    curl \
    python3 \
    python3-pip \
    nano \
    ncdu \
    htop \
    git \
    git-http \
    tree \
    less \
    grep \
    gawk \
    findutils \
    pv \
    coreutils

echo "Entware 核心工具安装完成"

# 验证安装
jq --version && python3 --version && git --version
```

---

## 七、在 agent 脚本中使用 Entware 工具

### 7.1 PATH 动态设置（脚本开头推荐）

```sh
#!/bin/sh
# 在脚本开头检查并加载 Entware
ENTWARE_ROOT=$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
if [ -n "${ENTWARE_ROOT}" ] && [ -d "/opt/bin" ]; then
    export PATH="/opt/bin:/opt/sbin:${PATH}"
fi

# 之后就可以直接用 jq、python3 等命令
echo '{"key":"value"}' | jq -r '.key'
```

### 7.2 检查 Entware 是否可用

```sh
entware_available() {
    command -v opkg > /dev/null 2>&1 || [ -x /opt/bin/opkg ]
}

if entware_available; then
    echo "Entware 可用"
    HAVE_JQ=$(command -v jq >/dev/null 2>&1 && echo true || echo false)
    HAVE_PY3=$(command -v python3 >/dev/null 2>&1 && echo true || echo false)
else
    echo "Entware 未安装，尝试使用 ${QPKG_ROOT}/tools/ 中的工具"
fi
```

### 7.3 智能工具查找（tools/ 优先，Entware 次之）

```sh
# jq 查找顺序：tools/ → Entware → 系统
find_jq() {
    if [ -x "${QPKG_ROOT}/tools/jq" ]; then
        echo "${QPKG_ROOT}/tools/jq"
    elif [ -x "/opt/bin/jq" ]; then
        echo "/opt/bin/jq"
    else
        echo ""
    fi
}

JQ=$(find_jq)
if [ -z "${JQ}" ]; then
    echo "jq 不可用，请安装 Entware 后运行 opkg install jq"
    exit 1
fi

echo '{"a":1}' | "${JQ}" '.a'
```

---

## 八、Entware 路径结构

```text
/opt/                              ← 软链接，指向 Entware QPKG 安装目录
    ↓ 实际路径
/share/CACHEDEV1_DATA/.qpkg/Entware/   （或 ZFS530_DATA/.qpkg/Entware/）
    ├── bin/          ← 可执行文件（opkg、jq、curl、python3 等）
    ├── sbin/         ← 系统级可执行文件
    ├── lib/          ← 库文件（.so）
    ├── etc/          ← 配置文件
    │   ├── profile   ← 环境变量（source 这个）
    │   ├── opkg/     ← opkg 配置
    │   └── init.d/   ← 服务启动脚本
    ├── var/          ← 运行时数据
    │   └── opkg-lists/ ← 包列表缓存
    └── usr/          ← 用户级工具
        ├── bin/      ← 更多可执行文件（python3 在这里）
        └── lib/      ← Python 库等
```

**检查路径**：
```sh
# 获取 Entware 安装路径
ENTWARE_ROOT=$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
echo "Entware: ${ENTWARE_ROOT}"
ls /opt/bin/ | head -20      # 已安装工具
ls /opt/usr/bin/ | head -20  # python3 等在这里
```

---

## 九、常见故障排查

### 9.1 opkg: command not found

```sh
# 原因一：新 SSH 会话未 source profile
source /opt/etc/profile && opkg --version

# 原因二：Entware 被 QTS 升级禁用
qpkg_service enable Entware && /etc/init.d/Entware.sh start
# 然后重新登录 SSH

# 原因三：/opt 软链接损坏（QTS 固件升级后常见）
ls -la /opt    # 查看软链接是否正常
ENTWARE_ROOT=$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
ls -la "${ENTWARE_ROOT}"   # 检查安装目录是否存在
# 如果安装目录存在但 /opt 软链接损坏，重启 Entware 服务会自动修复
/etc/init.d/Entware.sh restart

# 原因四：Entware 安装不完整（下载时断网）
# 解决方案：在 App Center 中禁用再启用 Entware，或重新安装
```

### 9.2 QTS 固件升级后 Entware 失效

```sh
# 症状：升级 QTS 后 opkg、python3 等命令全部找不到
# 原因：QTS 大版本升级会禁用非官方 QPKG

# 修复步骤（一条命令）
qpkg_service enable Entware && /etc/init.d/Entware.sh start

# 然后退出 SSH，重新登录
# 验证
opkg update && echo "Entware 恢复正常"
```

### 9.3 /opt 目录冲突（Permission denied 或内容不对）

```sh
# 查看 /opt 当前状态
ls -la /opt

# 查看哪些 QPKG 在使用 /opt
cat /etc/config/qpkg.conf | grep -A 3 '\[' | grep -i opt

# 如果其他 QPKG 也在用 /opt，需要调整加载顺序
# 安装 SortMyQPKGs（在 App Center 或 qnapclub.eu 找）
# 将 Entware 的加载顺序调到冲突 QPKG 之前
```

### 9.4 opkg update 连接超时

```sh
# 症状：opkg update 卡住或报 connection timed out
# 原因：QTS 防火墙或 DNS 问题

# 检查 DNS 解析
nslookup bin.entware.net || ping -c 3 bin.entware.net

# 检查是否能访问 Entware 服务器
curl -I --connect-timeout 10 https://bin.entware.net/x64-k3.2/Packages.gz 2>&1 | head -5

# 如果是 DNS 问题，临时修改 DNS
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
opkg update
```

### 9.5 某个包安装后报 "library not found" 错误

```sh
# 症状：新安装的包运行时报 libXXX.so not found
# 原因：包依赖的库发生版本变化（opkg 的已知问题）

# 修复方式一：重新安装该包
opkg remove <包名> && opkg install <包名>

# 修复方式二：更新所有包
opkg update && opkg upgrade

# 修复方式三：手动安装缺失的库
opkg find *libXXX*    # 找到提供该库的包
opkg install <库包名>
```

### 9.6 Python pip 包安装失败

```sh
# 确认 pip3 位置
which pip3    # /opt/bin/pip3

# SSL 相关错误：先安装 SSL 支持
opkg install python3-openssl python3-cryptography

# 编译相关错误（某些 pip 包需要编译）
opkg install python3-dev gcc make
pip3 install <包名>

# pip 找不到编译器时，使用纯 Python 包
pip3 install <包名> --prefer-binary  # 优先使用预编译包
```

---

## 十、opkg 高级用法

```sh
# 列出某个包安装的所有文件
opkg files python3

# 查询某个文件属于哪个包
opkg search /opt/bin/python3

# 列出所有有可用更新的包
opkg list-upgradable

# 只升级安全相关包（谨慎模式）
opkg list-upgradable | grep -i ssl | awk '{print $1}' | xargs opkg upgrade

# 查看包的所有版本
opkg list | grep ^python3

# 固定某个包版本（防止自动升级）
# 在 /opt/etc/opkg.conf 中添加：
# hold <包名>

# 查看 Entware 仓库信息
cat /opt/etc/opkg.conf
cat /opt/var/opkg-lists/entware | head -50

# 离线安装（先下载 .ipk 文件，再本地安装）
cd /share/Public
wget https://bin.entware.net/x64-k3.2/jq_1.6-2_x86-64.ipk
opkg install ./jq_1.6-2_x86-64.ipk  # 注意：路径需以 ./ 开头
```

---

## 十一、Entware 与 tools/ 目录的关系

安装 Entware 后，`${QPKG_ROOT}/tools/` 仍然保留，两者各有用途：

```text
${QPKG_ROOT}/tools/   ← agent 专属工具，完全隔离，不依赖 Entware
    适合：少数关键工具（ffprobe、rclone 等），确保 agent 环境独立

/opt/bin/             ← Entware 工具，需要 Entware QPKG 运行
    适合：常用的 Linux 工具链、Python 生态、复杂依赖的工具
```

**查找工具的推荐优先级**：
```sh
# 1. 优先查找 agent 自己的 tools/ 目录
# 2. 其次用 Entware 的 /opt/bin/
# 3. 最后用 QTS 系统自带（BusyBox 版本，功能受限）

TOOL=$(command -v tool_name 2>/dev/null \
    || echo "${QPKG_ROOT}/tools/tool_name" 2>/dev/null \
    || echo "/opt/bin/tool_name" 2>/dev/null)
```

---

## 十二、安全要求

- 安装 Entware QPKG：属于灰区操作，**必须告知用户并确认**
- `opkg install` 单个工具：告知后执行
- `opkg upgrade`（全量升级）：**必须确认**，有依赖破坏风险，建议按包升级
- `opkg remove` 删除包：确认，特别是有其他包依赖时
- 不使用 Entware 的 `opkg` 替代 QTS 系统文件（如不要 opkg install openssh-server 来替换系统 SSH）
- Entware 的工具应安装到 `/opt/`，不要手动 ln -sf 到 `/usr/bin/`（会在重启后消失，且可能冲突）