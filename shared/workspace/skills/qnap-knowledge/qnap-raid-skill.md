---
name: qnap-raid
description: QNAP QTS RAID 阵列状态查询、降级恢复、磁盘更换、手动重建及常见排障流程。包含大量论坛用户真实经验。
---

# QNAP RAID 管理与故障恢复

> 适用范围：QTS 5.x / 4.5.x RAID 管理
> 适用场景：RAID 降级警告、磁盘故障更换、重建失败、只读模式恢复

---

## ⚠️ RAID 最重要的原则

```text
RAID 不等于备份！RAID 只提供冗余，不能替代异地备份。
降级状态下禁止随意拔盘。
替换磁盘前，先确认要替换的是已退出阵列的失效盘，而非仍在阵列中的成员盘。
```

---

## 一、RAID 状态查询

### 1.1 基本状态

```sh
# 查看 RAID 详情（核心命令）
cat /proc/mdstat

# 查看所有 md 设备详情
for md in /dev/md*; do
    echo "=== ${md} ==="
    mdadm --detail "${md}" 2>/dev/null
done

# 查看存储池状态（通过日志）
tail -100 /var/log/messages | grep -iE 'raid|degraded|failed|rebuild|mdadm'

# 查看磁盘列表
lsblk
cat /proc/partitions
```

### 1.2 SMART 健康检查

```sh
# 查看单块磁盘 SMART 信息
smartctl -a /dev/sda
smartctl -H /dev/sda   # 仅看健康摘要

# 批量检查所有磁盘健康
for disk in /dev/sd[a-z]; do
    [ -b "${disk}" ] || continue
    health=$(smartctl -H "${disk}" 2>/dev/null | grep 'overall-health' | awk '{print $NF}')
    echo "${disk}: ${health}"
done
```

**注意：** QTS 自带 smartctl 可能未安装，路径可能在 `/usr/local/sbin/smartctl` 或需要从工具目录调用。

---

## 二、RAID 级别说明

| RAID 级别 | 最少磁盘数 | 可容忍故障盘 | 特点 |
|---|---|---|---|
| RAID 0 | 2 | 0 | 无冗余，性能最高，一块坏全毁 |
| RAID 1 | 2 | 1（共2盘时） | 镜像，安全但空间利用率50% |
| RAID 5 | 3 | 1 | 条带+奇偶，性能与安全平衡 |
| RAID 6 | 4 | 2 | 双奇偶，可同时容忍2块故障 |
| RAID 10 | 4 | 最多1块/每对 | 镜像+条带，性能和安全兼顾 |

**RAID 5 重要提示（论坛高频错误）：**
- RAID 5 降级后（1块坏盘）仍可读写，但**无冗余**
- 此时再坏1块 → **数据全毁，无法恢复**
- 降级后应立即更换磁盘重建，不要拖延

---

## 三、RAID 降级（Degraded）恢复流程

### 3.1 正常情况（GUI 操作）

1. 确认失效磁盘编号（查看 QTS 控制台告警）
2. 热插拔更换同等或更大容量磁盘（NAS 运行中换盘）
3. 登录 QTS → 存储与快照管理 → 选择降级阵列 → 管理 → 重建 RAID 阵列
4. 选择新磁盘 → 应用
5. 等待重建完成（视数据量，数小时到数十小时不等）

### 3.2 重建未自动开始（论坛常见问题）

现象：更换新盘后 RAID 仍显示 Degraded，新盘状态显示 "not member" 或 "spare"

**解决方法（用户验证有效）：**
```text
QTS Web UI → 存储与快照管理 → 选择存储池
→ 管理降级 RAID 组 → 管理 → 配置热备盘
→ 选择新插入的磁盘 → 应用
重建会立即开始
```

如果 UI 操作无效，通过 SSH 手动添加：

```sh
# 查看 md 设备名称
cat /proc/mdstat

# 确认新盘分区（替换 sdb 为实际磁盘号）
fdisk -l /dev/sdb

# 手动将新盘分区加入 RAID（替换 md1 和 sdb3 为实际值）
mdadm /dev/md1 --add /dev/sdb3

# 确认重建开始
mdadm --detail /dev/md1 | grep -E 'State|Rebuild'
cat /proc/mdstat
```

**注意：** 分区号通常是 3（如 `/dev/sdb3`），因为 QNAP 使用固定分区结构。用 `fdisk -l /dev/sdb` 确认。

### 3.3 只读模式（Read-Only）恢复

**原因：** RAID 5/6 在降级基础上又有成员盘出现坏块，系统切换到只读保护数据。

**正确处理顺序：**
```text
1. 【不要拔任何盘！】先确认哪块是已退出阵列的"失效盘"，哪块是仍在阵列中的"坏块盘"
2. 替换"已退出阵列"的失效盘 → 重建阵列
3. 重建完成，阵列恢复冗余
4. 再替换"有坏块"的成员盘 → 再次重建
5. 切勿颠倒顺序！
```

**数据拷出（只读模式下仍可读）：**
```sh
# 趁只读模式将数据拷到其他位置
rsync -avh --progress /share/目标共享/ /share/备份位置/
```

---

## 四、RAID 5 双盘故障后的数据尝试恢复

**结论：** RAID 5 双盘同时故障，官方和社区均确认：**标准方法无法恢复数据**。

```text
RAID5 只能容忍1块故障盘。
2块同时故障 = 数据无法通过软件恢复。
```

**如有备份：** 重建阵列，从备份恢复。

**如无备份，想最大化数据恢复：**
1. 不要写入任何数据到 NAS
2. 联系专业数据恢复公司（如 DriveSavers、Ontrack）
3. 不要自行尝试 `mdadm --create` 覆盖，会破坏残留数据

**SSH 中查看 SMART 判断磁盘状态：**
```sh
smartctl -a /dev/sda3
smartctl -a /dev/sdb3
smartctl -a /dev/sdc3
```

---

## 五、磁盘更换最佳实践

### 5.1 更换前检查清单
```sh
# 1. 确认 RAID 当前状态
cat /proc/mdstat

# 2. 确认要更换的磁盘编号（从 NAS 面板 LED 或 QTS 界面确认，不要从命令行猜）
lsblk

# 3. 确认新磁盘容量 ≥ 旧磁盘
# QNAP 要求：新盘容量必须 ≥ 最小成员盘容量

# 4. 确认新磁盘在兼容列表（建议检查）
# https://www.qnap.com/en/compatibility/
```

### 5.2 热插拔注意事项
- QNAP 大多数机型支持热插拔，但确认前先查机型规格
- 热插拔时先将磁盘从 QTS 界面"移除"，再物理拔出
- 新盘插入后等待系统识别（通常 30 秒内），再从界面操作
- **不要同时更换多块磁盘**（RAID 5 同时更换 2 块 = 数据全毁）

### 5.3 重建期间的注意事项
```sh
# 监控重建进度
watch -n 60 cat /proc/mdstat

# 重建期间的磁盘 I/O
iostat -x 5

# 重建期间不要做以下操作：
# - 大文件传输（会显著延长重建时间）
# - 磁盘检查
# - 固件升级
```

---

## 六、常见 RAID 错误信息解读

| 错误信息 | 含义 | 处理方式 |
|---|---|---|
| `RAID device in degraded mode` | 有1块盘退出阵列 | 确认失效盘，更换并重建 |
| `Disk 2 removed` | 磁盘 2 被系统移除 | 查 SMART，确认是否真坏 |
| `HDD SMART Rapid Test: Failed` | 磁盘 SMART 快速测试失败 | 安排更换磁盘 |
| `NCQ timeout error` | SSD 或 HDD NCQ 命令超时 | 磁盘可能故障，检查 SMART |
| `Host: SSD 1 Disabled NCQ since timeout error` | 因超时禁用 NCQ | 同上，优先检查该盘 |
| `RAID Recovery failed` | 恢复操作失败 | 多盘同时故障，需专业数据恢复 |

---

## 七、定期维护建议

```sh
# 查看坏块扫描结果
tail -50 /var/log/messages | grep -i 'badblock\|bad_block\|sector'

# 检查所有磁盘的重新分配扇区数（Reallocated Sectors）
for disk in /dev/sd[a-z]; do
    [ -b "${disk}" ] || continue
    reallocated=$(smartctl -A "${disk}" 2>/dev/null | awk '/^  5/{print $10}')
    echo "${disk} 重新分配扇区: ${reallocated}"
done
```

**QTS 定期任务建议：**
- 每月执行 SMART 测试（控制台 → 存储与快照管理 → 磁盘健康）
- 每季度执行一次坏块扫描
- 每年检查磁盘是否超过 5 年使用寿命

---

## 八、安全要求

- RAID 状态查询只读，无需确认
- 任何 `mdadm` 写操作（--add/--remove/--fail/--create）必须确认
- 磁盘热拔之前必须确认是已退出阵列的失效盘
- 降级阵列中不要随意拔盘
- 重建未开始时，先尝试 GUI 操作，再考虑 SSH 手动操作
