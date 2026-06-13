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

```text
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

```text
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

```text
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
```text
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

## 六、QPKG 提取与分析（extract_qdk.sh）

分析已有 QPKG 安装包的内部结构，用于学习其他应用的打包方式。

### 6.1 用法

```sh
# 解包命令
./extract_qdk.sh extract <foldername> <pkgname>

# 参数说明：
#   extract     子命令，执行解包操作
#   foldername  解包输出的目标文件夹名称或路径（会在其下创建 qpkg_content/ 子目录）
#   pkgname     待解包的 .qpkg 文件名

# 示例：将 alist_3.28.0_x86_64.qpkg 解包到 alist/ 目录
./extract_qdk.sh extract alist alist_3.28.0_x86_64.qpkg

# 解包结果结构：
#   alist/qpkg_content/          ← 控制文件（qpkg.cfg、qinstall.sh、package_routines 等）
#   alist/qpkg_content/data/     ← 应用程序实际文件
#   alist/qpkg_content/data.tar.gz（或 .7z）← 数据包原始归档
#   alist/head                   ← QPKG 头部脚本
#   alist/tail                   ← QPKG 尾部签名区
```

### 6.2 重打包命令

```sh
# 修改文件后重新打包
./extract_qdk.sh pack <foldername> <pkgname>

# 注意：重打包需要签名证书文件 sign.crt 和 sign.key 存在于当前目录
```

### 6.3 脚本完整内容

将以下脚本保存为 `extract_qdk.sh` 并赋予执行权限（`chmod +x extract_qdk.sh`）：

```bash
#!/bin/bash

SIGN_CERT=sign.crt
SIGN_KEY=sign.key

PREFIX=qpkg_workspace
EXTRACT_PATH=qpkg_content

len_to_binary() {
        len=$1
        byte4="\\`printf 'x%02x' $((len%256))`"
        len=$((len/256))
        byte3="\\`printf 'x%02x' $((len%256))`"
        len=$((len/256))
        byte2="\\`printf 'x%02x' $((len%256))`"
        len=$((len/256))
        byte1="\\`printf 'x%02x' $((len%256))`"
        printf "$byte1$byte2$byte3$byte4"
}

get_offset() {
        offsets="$(/bin/sed -n '1,/^exit 1/{
s/^script_len=\([0-9]*\).*$/\1/p
s/^offset.*script_len[^0-9]*\([0-9]*\).*$/\1/p
s/^offset.*offset[^0-9]*\([0-9]*\).*$/\1/p
/^exit 1/q
}' "${QPKG}")"
        script_len=`echo $offsets|cut -f 1 -d " "`
        raw_offset1=`echo $offsets|cut -f 2 -d " "`
        raw_offset2=`echo $offsets|cut -f 3 -d " "`
        offset1=$((script_len+raw_offset1))
        offset2=$((offset1+raw_offset2))
}

extract_qdk() {
        mkdir -p $PREFIX/$EXTRACT_PATH
        get_offset
        echo $script_len $raw_offset1 $raw_offset2 $offset1 $offset2
        echo $(((raw_offset2+1024)/1024))
        dd if=$QPKG bs=$script_len count=1 > $PREFIX/head
        if grep data.tar.7z  $PREFIX/head >/dev/null; then
                is7z=1
        fi
        dd if=$QPKG bs=$script_len skip=1 |/bin/tar -xO | /bin/tar -xzv -C  $PREFIX/$EXTRACT_PATH
        dd if=$QPKG bs=$offset1 skip=1 | /bin/cat | /bin/dd bs=1024 of=$PREFIX/$EXTRACT_PATH/data.tar.gz
        busybox truncate -s $raw_offset2 $PREFIX/$EXTRACT_PATH/data.tar.gz

        mkdir $PREFIX/$EXTRACT_PATH/data
        if [ "$is7z" == "1" ]; then
                mv $PREFIX/$EXTRACT_PATH/data.tar.gz $PREFIX/$EXTRACT_PATH/data.tar.7z
                7z x -so $PREFIX/$EXTRACT_PATH/data.tar.7z | tar x -C $PREFIX/$EXTRACT_PATH/data
        else
                tar xf $PREFIX/$EXTRACT_PATH/data.tar.gz -C $PREFIX/$EXTRACT_PATH/data
        fi

        tail -c 100 $QPKG> $PREFIX/tail
}

pack_qdk() {
        # control.tar.gz
        tar czf $PREFIX/control.tar.gz -C $PREFIX/$EXTRACT_PATH built_info package_routines  qinstall.sh  qpkg.cfg
        tar cf $PREFIX/control.tar -C $PREFIX control.tar.gz
        new_offset1=`stat -c "%s" $PREFIX/control.tar`
        new_offset2=`stat -c "%s" $PREFIX/$EXTRACT_PATH/data.tar.gz`
# update control.tar offset
        sed -i "s/^\(.*script_len \+ \)$raw_offset1\(.*\)\$/\1$new_offset1\2/g" $PREFIX/head
# update data.tar.gz offset
# assume the longest number will not expect confict.
        sed -i "s/^\(.*\)$raw_offset2\(.*\)\$/\1$new_offset2\2/g" $PREFIX/head
# update /bin/dd bs=1024 count=
        bcount=$(((new_offset2+1024)/1024))
        sed -i "s/^\(.*bs=1024 count=\)[0-9]*\(.*\)\$/\1$bcount\2/g" $PREFIX/head

# update script_len
        script_len=`stat -c "%s" $PREFIX/head`
        sed -i "s/^script_len=.*\$/script_len=$script_len/g" $PREFIX/head

# assemble
        cat $PREFIX/head $PREFIX/control.tar $PREFIX/$EXTRACT_PATH/data.tar.gz > $PREFIX/qpkg.bin

# sign
        openssl sha1 -binary $PREFIX/qpkg.bin | openssl cms -sign  -nodetach -binary -signer $SIGN_CERT -inkey $SIGN_KEY > $PREFIX/qpkg.bin.sign

 # tail
        sign_len=`stat -c "%s" $PREFIX/qpkg.bin.sign`
        echo -n "QDK" >> $PREFIX/qpkg.bin
        printf "\xFE" >> $PREFIX/qpkg.bin
        len_to_binary $sign_len >> $PREFIX/qpkg.bin
        cat $PREFIX/qpkg.bin.sign >> $PREFIX/qpkg.bin
        printf "\xFF" >> $PREFIX/qpkg.bin
        cat $PREFIX/tail >> $PREFIX/qpkg.bin
 # update encrypt
        fullsize=`stat -c "%s" $PREFIX/qpkg.bin`
        encrypt=$((fullsize * 3589 + 1000000000))
        echo -n "$encrypt" | dd of=$PREFIX/qpkg.bin seek=$((fullsize-60)) bs=1 conv=notrunc
        mv $PREFIX/qpkg.bin $PREFIX/$QPKG

}

usage() {
        echo "Usage:"
        echo "$0 extract foldername pkgname             extract package to foldername"
        echo "$0 pack foldername pkgname                pack files under folder to foldername"
        exit 1
}

if [ "$#" -eq "2" ]; then
        usage
fi

PREFIX="$2"
QPKG=$3

case "$1" in
        extract)
                extract_qdk
                ;;
        pack)
                pack_qdk
                echo "please find it in $PREFIX/$QPKG"
                ;;
        *)
                usage
esac
```

### 6.4 QPKG 内部结构说明

| 区域 | 内容 |
|---|---|
| 头部脚本（`head`） | Shell 安装脚本，含偏移量变量 `script_len`、`offset1`、`offset2` |
| `control.tar` | 控制文件归档：`qpkg.cfg`、`qinstall.sh`、`package_routines`、`built_info` |
| `data.tar.gz` / `data.tar.7z` | 应用程序实际文件 |
| 尾部签名（`tail`） | QDK 签名区，含 `openssl cms` 数字签名 |

---

## 七、QuMagie 人像数据备份

QuMagie v2.4.0 起支持人脸识别元数据的备份与恢复。备份原理是将每张图片/视频的元数据（相册、标签、人脸信息等）导出为独立 JSON 文件，存储于照片所在目录下的隐藏目录 `.@__thumb/` 中，文件名与照片同名，后缀为 `.json`。

> **注意：** QTS 5.0 及以上不再支持通过备份 MySQL `S01` 库来恢复人脸数据，系统升级后会自动重新索引导致数据丢失，必须使用 v2.4.0 的新备份机制。

### 7.1 qm_export 工具说明

`qm_export` 是 QuMagie 安装目录内自带的 CLI 工具，路径为：

```sh
# 定位 QuMagie 安装路径
QPKG_ROOT=$(/sbin/getcfg QuMagie Install_Path -f /etc/config/qpkg.conf)
echo "QuMagie 安装路径: ${QPKG_ROOT}"

# qm_export 完整路径
QM_EXPORT="${QPKG_ROOT}/v2.4.0/cli/qm_export"
ls -la "${QM_EXPORT}"
```

### 7.2 qm_export 调用方式

`qumagie-backup.sh` 脚本对 `qm_export` 的调用封装如下（基于博客原文提取）：

```sh
#!/bin/sh

# ── 配置区（修改以下四项）──────────────────────────────────────────
export_type="metadata"
# 可选值：
#   metadata  仅导出元数据（相册、标签、人物等），不含原始文件
#   full      导出媒体文件 + 元数据（文件较大）

target_folder="备份/照片备份/QuMagie"
# 备份目标路径，相对于 /share/，无需加 /share/ 前缀

uname="admin"
# 执行备份的用户名，管理员可备份其他用户数据

password=""
# 可选密码后缀：
#   留空   → 实际密码为系统默认 qnapqnap
#   123456 → 实际密码为 qnapqnap123456
# ─────────────────────────────────────────────────────────────────────

QPKG_ROOT=$(/sbin/getcfg QuMagie Install_Path -f /etc/config/qpkg.conf)
QM_EXPORT="${QPKG_ROOT}/v2.4.0/cli/qm_export"

"${QM_EXPORT}" \
    --type "${export_type}" \
    --target "/share/${target_folder}" \
    --user "${uname}" \
    --password "qnapqnap${password}"
```

### 7.3 使用步骤

```sh
# 1. 下载或创建脚本，赋予执行权限
chmod 0755 /share/scripts/qumagie-backup.sh

# 2. 编辑脚本，配置 export_type / target_folder / uname / password

# 3. 手动执行测试
/share/scripts/qumagie-backup.sh

# 4. 配合 GoCron 或系统 crontab 实现定时自动备份
# GoCron WebUI 添加任务，命令填写脚本完整路径即可
```

### 7.4 备份产物说明

导出完成后，JSON 文件写入到每张照片所在目录的 `.@__thumb/` 隐藏目录：

```bash
/share/Photo/
└── 全家福/
    ├── 01.jpg
    └── .@__thumb/
        └── 01.jpg.json    ← 元数据备份文件
```

JSON 文件包含字段：`MediaType`、`Path`、人脸数组 `Faces`（含姓名、坐标、GroupId）、相册数组 `Albums`、标签 `Objects`、`Qtag` 版本标识等。

### 7.5 恢复方式

在 QuMagie WebUI 中执行恢复操作（目前仅支持网页端手动触发），系统会读取 `.@__thumb/` 目录内的 JSON 文件重建人脸识别数据。

### 7.6 相关诊断命令

```sh
# 确认 qm_export 存在且可执行
QPKG_ROOT=$(/sbin/getcfg QuMagie Install_Path -f /etc/config/qpkg.conf)
ls -la "${QPKG_ROOT}/v2.4.0/cli/qm_export"

# 查找已生成的 JSON 备份文件
find /share/Photo -name "*.json" -path "*/.@__thumb/*" 2>/dev/null | head -20

# 统计 JSON 备份文件数量
find /share/Photo -name "*.json" -path "*/.@__thumb/*" 2>/dev/null | wc -l
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
