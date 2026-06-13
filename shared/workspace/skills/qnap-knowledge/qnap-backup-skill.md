---
name: qnap-backup
description: QNAP NAS 备份策略、HBS3（Hybrid Backup Sync）使用、快照管理、3-2-1 备份原则、RTRR 同步及云备份配置。
---

# QNAP 备份与数据保护

> 适用范围：QTS 5.x / 4.5.x 备份管理
> 适用场景：备份任务配置、快照管理、数据恢复、异地备份策略

---

## ⚠️ 备份第一原则

```text
RAID 不是备份！
RAID 只防磁盘硬件故障，不防：
- 勒索病毒（Deadbolt 等会同时加密所有盘）
- 误删除
- 火灾/水灾（需要异地备份）
- 存储控制器故障
- 软件 bug 导致的数据损坏

3-2-1 原则：3份副本，2种媒介，1份异地
```

---

## 一、QNAP 备份体系概览

| 工具 | 用途 | 推荐场景 |
|---|---|---|
| HBS3（Hybrid Backup Sync） | 备份/同步/恢复，支持云和远程 NAS | 日常备份主力工具 |
| 快照（Snapshot） | 时间点恢复，防勒索病毒 | 配合 HBS3 使用，非替代关系 |
| RTRR | QNAP-to-QNAP 实时同步 | 双机实时同步 |
| USB 备份 | 备份到外接 USB 存储 | 简单本地备份 |

---

## 二、HBS3 快速检查

```sh
# 检查 HBS3 是否安装
/sbin/getcfg HybridBackup Enable -f /etc/config/qpkg.conf 2>/dev/null

# 获取 HBS3 安装路径
QPKG_NAME="HybridBackup"
QPKG_DIR=$(/bin/sed -nr ":s /^\[$QPKG_NAME\]/ b o; n; b s; :o n; /^\[/ q; /^Install_Path[ ]*=/ {s/.*=[ ]*// p; q;} b o;" "/etc/config/qpkg.conf")
ls "${QPKG_DIR}" 2>/dev/null

# 查看 HBS3 日志
ls /share/*/HybridBackup/log/ 2>/dev/null | head
find /share -path "*/HybridBackup/log/*" -name "*.log" 2>/dev/null | head -5
```

---

## 三、3-2-1 备份策略配置建议

```text
推荐策略（家庭/小型企业）：

副本 1：NAS 本身（生产数据）
副本 2：本地外置硬盘 或 第二台 NAS（HBS3 备份任务）
副本 3：云存储（HBS3 → Amazon S3 / Google Drive / Dropbox 等）

时间点保护（额外）：
- 在 NAS 上启用快照（每日快照，保留 7-30 天）
- 快照 + 外部备份 = 最强防护
```

---

## 四、HBS3 备份任务状态查询（SSH）

```sh
# 通过日志判断备份状态
find /share -name "*.hbslog" -mtime -1 2>/dev/null | head -10

# 查看系统日志中的 HBS 相关记录
grep -i 'HybridBackup\|HBS\|backup' /var/log/messages | tail -30

# 通过 API 查询任务状态（如有 curl）
# 注意：API 需要登录 token，一般通过 QTS Web 界面查看更方便
```

**通常推荐通过 QTS GUI 查看 HBS3 任务状态：**
- HBS3 → 备份与恢复 → 任务列表 → 查看最近运行状态
- 绿色 = 成功，红色 = 失败，黄色 = 警告

---

## 五、QNAP-to-QNAP 备份（RTRR）

**适用场景：** 两台 QNAP NAS 之间的实时或定时备份

**配置步骤：**
1. 目标 NAS：HBS3 → 服务 → 启用 RTRR Server
2. 源 NAS：HBS3 → 备份与恢复 → 新建任务 → 远程 NAS
3. 填写目标 NAS 的 IP、端口（默认 8899）、账号密码
4. 选择 RTRR 协议
5. 设置源文件夹和目标路径
6. 设置计划（实时/每小时/每天）

```sh
# 检查 RTRR 服务状态
ss -tlnp | grep 8899
/etc/init.d/rtrrd status 2>/dev/null
```

---

## 六、快照（Snapshot）管理

### 6.1 快照状态查询

```sh
# 查看快照列表
ls /share/.snapshot/ 2>/dev/null
ls /.snapshots/ 2>/dev/null

# 查看某个共享的快照
ls /share/<共享名>/.snapshot/ 2>/dev/null | grep GMT

# LVM 快照查询（QTS 底层）
/usr/sbin/lvm lvs 2>/dev/null | grep snap
```

### 6.2 快照注意事项

**论坛用户经验：**
```text
- 快照本身不是备份（存在同一物理存储上）
- 勒索病毒攻击可能不会立即影响快照，给了时间窗口恢复
- QTS 5.2 安全中心可以在检测到大规模文件加密时自动触发快照
- 快照会占用存储空间，需要合理设置保留数量
- 快照保留策略：建议每天 1 个，保留 7 天；每周 1 个，保留 4 周
```

### 6.3 从快照恢复（GUI 路径）

```text
存储与快照管理 → 快照 → 快照库
→ 选择共享文件夹 → 查看快照 → 选择时间点 → 恢复
```

---

## 七、云备份配置（HBS3 支持的云服务）

HBS3 支持的主要云服务：
- Amazon S3
- Amazon Glacier
- Google Drive
- Dropbox
- OneDrive
- Backblaze B2
- Azure Blob Storage
- S3 兼容服务（如 Wasabi、Cloudflare R2）

```sh
# 检查 HBS3 版本（影响支持的云服务）
QPKG_NAME="HybridBackup"
QPKG_DIR=$(/bin/sed -nr ":s /^\[$QPKG_NAME\]/ b o; n; b s; :o n; /^\[/ q; /^Install_Path[ ]*=/ {s/.*=[ ]*// p; q;} b o;" "/etc/config/qpkg.conf")
cat "${QPKG_DIR}/version.txt" 2>/dev/null || cat "${QPKG_DIR}/config/version" 2>/dev/null
```

**QuDedup 去重功能说明：**
- HBS3 自带 QuDedup 块级去重
- 可将备份大小减少 75%（测试数据）
- 去重后数据以 `.qdff` 格式存储
- 需要 QuDedup Extract Tool 才能在无 NAS 情况下还原

---

## 八、USB 外置备份

```sh
# 检查已连接的 USB 设备
lsblk | grep -E 'usb|sdb|sdc'
mount | grep /dev/sd[b-z]

# USB 存储挂载路径
ls /share/USB_*/  2>/dev/null
ls /share/External*/  2>/dev/null
```

**最佳实践（来自论坛用户）：**
```text
1. 连接 USB 存储，等待挂载完成（通常 30 秒内）
2. 确认挂载：ls /share/USB_*/
3. 运行 HBS3 备份任务（备份到本地 → 选择 USB 设备）
4. 任务完成后，点击"退出"等待安全弹出
5. 确认弹出完成后再拔出 USB（不要直接拔）
```

---

## 九、备份验证

**定期验证备份可用性（非常重要，很多用户忽略）：**

```sh
# 从快照随机恢复一个文件进行验证
# （通过 QTS GUI 操作更安全）

# 检查 HBS3 任务日志中是否有错误
find /share -path "*/HybridBackup/log/*.log" 2>/dev/null | while read f; do
    echo "=== ${f} ==="
    grep -iE 'error|fail|warning' "${f}" | tail -10
done
```

**建议：** 每季度从备份中随机恢复几个文件验证备份完整性。"从未测试过的备份等于没有备份。"

---

## 十、常见备份问题排查

### 10.1 HBS3 任务失败

```sh
# 查看 HBS3 相关日志
grep -i 'HybridBackup\|hbs3' /var/log/messages | tail -30

# 检查存储空间
df -h
df -h /share/

# 检查目标存储是否可达
ping -c 3 <目标NAS_IP>
curl -I --connect-timeout 5 <云存储URL> 2>/dev/null | head -5
```

常见原因：
- 目标存储空间不足
- 网络连接断开（云备份）
- 目标 NAS 服务未启动
- 凭据过期（云服务 API Key 更新）

### 10.2 同步速度极慢

```sh
# 检查网络速度
iperf3 -c <目标IP> 2>/dev/null || echo "iperf3 不可用"

# 检查磁盘 I/O
iostat -x 5 3
```

**HBS3 速度优化（来自社区建议）：**
- 开启 TCP BBR（HBS3 高级设置）
- 备份时段设置在低负载时间（深夜）
- 避免备份期间同时进行大文件传输

---

## 十一、安全要求

- 查询备份状态：只读，无需确认
- 删除备份版本/快照：必须确认
- 修改备份任务配置：建议告知用户
- 清理 HBS3 任务历史：必须确认
