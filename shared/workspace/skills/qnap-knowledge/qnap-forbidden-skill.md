---
name: qnap-forbidden
description: QNAP QTS 环境中的禁止操作、安全红线、确认规则与灰区操作边界。
---

# 禁止操作与安全红线

> 本文档定义 qnap-agent 在任何情况下都不应执行的高风险操作。
> **即使用户明确要求，也不得跳过确认或执行绝对禁止项。**

---

## 一、系统包管理（绝对禁止）

```text
apt install / apt-get install / apt upgrade / apt-get upgrade
yum install / yum update
dnf install / dnf update
opkg install
ipkg install
pip install / pip3 install
npm install -g
gem install
conda install
brew install
```

需要额外工具时，只能放到：
```sh
${QPKG_ROOT}/tools/
```
通过 curl 下载静态二进制，chmod +x 授权，不使用系统包管理器。

---

## 二、系统升级（绝对禁止）

```text
apt upgrade / apt-get upgrade
yum update / dnf upgrade
qpkg_fw_update（固件升级命令行工具，风险极高）
QTS 固件升级必须通过 GUI 操作，不在 SSH 中执行
```

---

## 三、重启和关机（绝对禁止，无确认前）

```text
reboot
shutdown now / shutdown -h now / shutdown -r now
poweroff
halt
init 0
init 6
systemctl reboot / systemctl poweroff
```

如用户明确要求重启，先确认，再建议通过 QTS Web 界面操作。

---

## 四、大范围删除（绝对禁止）

```text
rm -rf /share/
rm -rf /
rm -rf /*
find / -delete
find /share -delete
```

即使用户明确想删除，也要：
1. 先列出所有将被删除的对象（`find ... -print | head -50`）
2. 用户确认
3. 分批处理，每批后确认
4. 不使用 `-rf` 的大范围删除

---

## 五、磁盘格式化（绝对禁止）

```text
mkfs.ext4 /dev/sd*
mkfs.xfs /dev/sd*
mkfs.btrfs /dev/sd*
fdisk /dev/sd*
parted /dev/sd*
sgdisk /dev/sd*
dd if=/dev/zero of=/dev/sd*
```

---

## 六、用户账户修改（绝对禁止）

```text
passwd
chpasswd
usermod
useradd
userdel
groupadd
groupmod
groupdel
```

账户管理必须通过 QTS Web 界面操作（控制台 → 权限 → 用户）。

---

## 七、防火墙清空（绝对禁止）

```text
iptables -F
iptables -X
iptables -Z
ip6tables -F
ip6tables -X
nft flush ruleset
```

可以查询（`iptables -L -n -v`），但不能修改或清空。

---

## 八、系统关键目录写入（绝对禁止）

以下目录默认按高风险处理，禁止写入：

```text
/bin
/sbin
/usr/bin
/usr/sbin
/lib
/lib64
/usr/lib
/boot
/etc/passwd
/etc/shadow
/etc/sudoers
/etc/sudoers.d/
```

---

## 九、第三方 QPKG 目录改造（绝对禁止）

**本条仅针对 qnap-agent 以外的其他 QPKG 应用目录。**
`qnap-agent` 自身目录（`${QPKG_ROOT}/`）的升级操作由 `qnap-agent-upgrade-skill` 管理，**不受本条限制**。

针对其他应用（`/share/CACHEDEV*_DATA/.qpkg/<其他app>/`），以下行为按禁止项处理：

```text
对 /share/CACHEDEV*_DATA/.qpkg/<其他app>/ 写入文件
对 /share/CACHEDEV*_DATA/.qpkg/<其他app>/ 覆盖脚本
对 /share/CACHEDEV*_DATA/.qpkg/<其他app>/ 替换二进制
对 /share/CACHEDEV*_DATA/.qpkg/<其他app>/ 私自改造配置
```

允许操作：
- 读取任何应用目录内容（`ls`, `cat`）
- 读取 `<app>.sh` 和其他启动脚本
- 读取应用目录中的只读配置与说明

**qnap-agent 自身升级白名单**（以下操作不触发本条禁令）：
```text
${QPKG_ROOT}/update/picoclaw            ← 下载新二进制到此，由 watchdog 接管
${QPKG_ROOT}/update/picoclaw-launcher   ← 同上
${QPKG_ROOT}/workspace/skills/          ← 技能文件热更新
${QPKG_ROOT}/workspace/scripts/         ← 脚本热更新
```

---

## 十、RAID 操作（无确认前禁止）

```text
mdadm --create     # 创建新 RAID
mdadm --fail       # 标记磁盘失效
mdadm --remove     # 从 RAID 移除磁盘
# 降级阵列中任何磁盘拔出操作都必须确认
```

---

## 十一、灰区操作（必须明确确认）

以下操作必须先列出影响，再明确确认，再执行：

```text
删除单个文件                     → 列出文件信息，确认
重启单个 Docker 容器              → 告知影响，确认
修改文件或目录权限（chmod/chown）  → 告知影响，确认
清理 Docker 缓存/镜像             → 列出将被删除内容，确认
修改 /etc/config/ 下的配置        → 告知具体变更，确认
批量文件整理/重命名               → 展示前几条预览，确认
清空共享文件夹回收站               → 列出大小，确认
更新 Docker 镜像                  → 告知影响，确认
停止、启动、重建 Compose 项目      → 告知影响，确认
```

以下是 qnap-agent 自身服务管理，可以自行执行（无需确认）：
```text
qnap-agent.sh status     ✅ 可以执行
qnap-agent.sh restart    ✅ 可以执行（影响自身，可以自主决定）
```

---

## 十二、额外新增禁令（安全加固）

以下操作增加到禁止列表：

```text
# 证书私钥操作（禁止）
openssl genrsa ... > /etc/...      # 不在系统目录生成密钥
rm /etc/stunnel/*.pem              # 不删除证书文件

# SSH 配置修改（禁止）
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config   # 不修改 SSH 配置
sed -i 's/PasswordAuthentication.*/.../' /etc/ssh/sshd_config

# 定时任务系统（禁止直接修改系统 crontab）
crontab -r                        # 不删除系统 crontab
echo "... >> /etc/crontab"        # 不写入系统 crontab
# 允许写入 ${QPKG_ROOT}/workspace/cron/ 下的用户任务文件

# 网络配置（禁止）
ifconfig eth0 down                # 不关闭网络接口
ip link set eth0 down             # 同上

# 进程强制终止（谨慎）
kill -9 1                         # 禁止 kill PID 1（init）
killall -9 smbd                   # 禁止强制终止系统关键服务进程
```

---

## 十三、处理原则

1. **命中绝对禁止项** → 直接停止，不执行，解释原因
2. **命中灰区项** → 先列出影响对象和范围，等待用户确认后再执行
3. **不确定是否危险** → 按灰区处理，先查询再确认
4. **用户强制要求执行禁止操作** → 礼貌拒绝，说明风险，建议通过 QTS Web 界面操作
5. **所有高风险操作** → 优先建议通过 QTS Web 管理界面处理
