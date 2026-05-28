---
name: qnap-shares
description: QNAP QTS 共享文件夹、SMB、NFS、FTP、WebDAV 的配置查询、排查与访问诊断规范。包含常见问题和社区解决方案。
---

# QNAP 共享文件夹管理

> 适用范围：QTS 5.x 共享文件夹配置、SMB/NFS/WebDAV/FTP 访问
> 适用场景：查询共享配置、访问权限排查、连接问题诊断

---

## 一、共享文件夹信息查询

```sh
# 列出所有共享文件夹（过滤系统目录）
ls -la /share/ | grep -v CACHEDEV | grep -v total | grep -v '^\.'

# 查看 SMB 中的共享配置
grep -A 5 '^\[' /etc/config/smb.conf | grep -E '^\[|path\s*=' | head -60

# 各共享磁盘使用情况
df -h | grep /share
du -sh /share/*/ 2>/dev/null | sort -rh | head -20

# 通过 getcfg 列出所有配置区段
/sbin/getcfg -f /etc/config/smb.conf -a | head -100
```

---

## 二、SMB / Samba 详细诊断

### 2.1 服务状态检查

```sh
# 服务状态
/etc/init.d/smbd status 2>/dev/null
ps aux | grep smbd | grep -v grep

# 端口监听
ss -tlnp | grep -E ':139|:445'

# 当前连接
smbstatus 2>/dev/null | head -50

# 配置验证
testparm 2>/dev/null | head -50
```

### 2.2 配置文件查看

```sh
# 全局配置
cat /etc/config/smb.conf | head -50

# 查看所有共享定义
grep -E '^\[|path|valid users|write list|read only|guest ok' /etc/config/smb.conf

# 查看特定共享配置
awk '/^\[target_share_name\]/,/^\[/' /etc/config/smb.conf
```

### 2.3 常见 SMB 问题排查

**问题：Windows 无法连接共享**

```sh
# 按顺序检查
echo "1. 服务状态:"
/etc/init.d/smbd status 2>/dev/null | head -3

echo "2. 端口监听:"
ss -tlnp | grep ':445'

echo "3. 防火墙:"
iptables -L INPUT -n | grep -E '445|139'

echo "4. 共享路径:"
ls -la /share/<共享名>/ 2>/dev/null | head -5

echo "5. 日志:"
tail -20 /var/log/messages | grep -iE 'smb|samba|winbind|access denied'
```

**问题：权限不足，"Access Denied"**
```sh
# 检查文件权限
ls -la /share/<共享名>/problematic_file
stat /share/<共享名>/problematic_file
getfacl /share/<共享名>/problematic_file 2>/dev/null

# 检查 Samba 配置中的用户权限
grep -A 20 '^\[<共享名>\]' /etc/config/smb.conf

# 注意：QTS 使用 POSIX + Windows ACL 混合权限
# 建议通过 GUI 修改：权限 → 共享文件夹 → 编辑权限
```

**问题：Word/Excel 文件提示"Access Denied"（论坛高频问题）**
```
原因：Office 文件在保存时需要创建临时文件，
      如果 Samba 配置了 "oplocks" 或 Windows ACL 有冲突，
      会出现此问题。
解决方案（社区验证有效）：
1. 通过 QTS GUI → 控制台 → 网络与文件服务 → 高级选项
   → 关闭"启用不透明锁定"（Oplocks）
2. 或在 smb.conf 中添加（需通过 GUI 管理，避免直接修改）
   oplocks = no
   level2 oplocks = no
```

---

## 三、NFS 共享诊断

```sh
# 服务状态
/etc/init.d/nfsd status 2>/dev/null
ps aux | grep nfsd | grep -v grep

# 端口监听
ss -tlnp | grep ':2049'
rpcinfo -p localhost 2>/dev/null | grep nfs

# 查看导出的 NFS 共享
showmount -e localhost 2>/dev/null
exportfs -v 2>/dev/null

# NFS 配置
cat /etc/config/nfs.conf 2>/dev/null

# 日志
tail -30 /var/log/messages | grep -iE 'nfs|rpc|mountd'
```

**NFS 挂载示例（在客户端执行）：**
```sh
# Linux 客户端
mount -t nfs <NAS_IP>:/share/<共享名> /mnt/nfs_mount

# macOS 客户端
mount -t nfs -o resvport <NAS_IP>:/share/<共享名> /Volumes/nfs_mount
```

---

## 四、FTP 服务诊断

```sh
# 服务状态
/etc/init.d/ftpd status 2>/dev/null
ps aux | grep ftpd | grep -v grep

# 端口监听
ss -tlnp | grep ':21'

# FTP 配置
cat /etc/config/vsftpd.conf 2>/dev/null | head -40
cat /etc/config/pure-ftpd.conf 2>/dev/null | head -40

# 日志
tail -30 /var/log/messages | grep -iE 'ftp|vsftpd|pure-ftpd'
```

**FTP 安全建议：**
- 不要在公网暴露 FTP（明文传输）
- 使用 FTPS（FTP over SSL）或改用 SFTP（SSH 文件传输）
- 设置 FTP 被动模式端口范围（控制台 → FTP 服务）

---

## 五、WebDAV 服务

```sh
# 查看 Web 服务器状态
/etc/init.d/Qthttpd status 2>/dev/null || \
/etc/init.d/apache status 2>/dev/null || \
ps aux | grep -E 'nginx|apache|httpd|Qthttpd' | grep -v grep

# 端口监听（WebDAV 共用 HTTP/HTTPS 端口）
ss -tlnp | grep -E ':80|:443|:8080'
```

**WebDAV 访问地址格式：**
```
http://<NAS_IP>:8080/WebDAV/<共享名>/
https://<NAS_IP>/WebDAV/<共享名>/
```

---

## 六、共享文件夹权限诊断

### 6.1 QNAP 权限体系说明

```
QTS 权限层次（从高到低）：
1. 共享文件夹权限（QTS ACL）→ 控制谁可以访问整个共享
2. 文件系统权限（POSIX/Windows ACL）→ 控制文件/目录级别访问
3. 网络协议权限（SMB guest、NFS 客户端限制）

三层权限都必须允许，用户才能正常访问。
```

### 6.2 权限排查流程

```sh
# 步骤 1：确认共享文件夹存在
ls -la /share/ | grep <共享名>

# 步骤 2：检查目录权限
ls -la /share/<共享名>/
stat /share/<共享名>/

# 步骤 3：检查 ACL（如果 getfacl 可用）
getfacl /share/<共享名>/ 2>/dev/null

# 步骤 4：检查 Samba 用户权限配置
grep -A 20 "^\[$(echo <共享名> | tr '[:lower:]' '[:upper:]')\]" /etc/config/smb.conf
grep -A 20 "^\[<共享名>\]" /etc/config/smb.conf

# 步骤 5：查看访问日志
tail -30 /var/log/messages | grep -iE 'denied|access|permission|<用户名>'
```

---

## 七、macOS 连接 QNAP 常见问题

**问题：Finder 中 NAS 不显示**
```
原因：SMB 网络发现（Bonjour/mDNS）相关问题
解决：
1. Finder → 前往 → 连接到服务器 → 输入 smb://NAS_IP/共享名
2. 或 QTS 中启用 AFP（已在 QTS 5.x 中逐步移除）
3. 检查 NAS 和 Mac 是否在同一网段
```

**问题：macOS 下 NFS 挂载权限问题**
```sh
# macOS 挂载 NFS 时需要使用 -o resvport
sudo mount -t nfs -o resvport <NAS_IP>:/share/<共享名> /Volumes/mount_point

# NFS 配置中需要允许特权端口
# QTS GUI → NFS 服务 → 允许非标准端口连接
```

---

## 八、配额与回收站

```sh
# 查看磁盘配额
repquota /share/CACHEDEV1_DATA/ 2>/dev/null
quota -u admin 2>/dev/null

# 查看所有共享回收站大小
for share_dir in /share/*/; do
    recycle="${share_dir}@Recycle"
    [ -d "${recycle}" ] && \
        printf "%-40s %s\n" "${recycle}" "$(du -sh "${recycle}" 2>/dev/null | cut -f1)"
done

# 清空回收站（执行前必须确认）
# rm -rf /share/<共享名>/@Recycle/*
```

---

## 九、安全要求

- 查询共享配置：只读，无需确认
- 修改共享权限：必须确认，影响所有有权用户
- 清空回收站：必须确认，不可撤销
- 重启 Samba/NFS 服务：必须确认，会断开所有当前连接
- 修改 smb.conf：高风险，建议通过 GUI 操作
