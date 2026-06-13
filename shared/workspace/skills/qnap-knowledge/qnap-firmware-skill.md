---
name: qnap-firmware
description: QNAP QTS 固件版本管理、升级注意事项、升级失败恢复、版本回退及已知问题汇总。
---

# QNAP 固件管理

> 适用范围：QTS 5.x 固件管理
> 适用场景：固件升级、升级失败恢复、版本确认、升级前评估

---

## ⚠️ 固件升级警告

```text
升级前必须确认：
1. 有完整外部备份（升级失败可能导致系统不可用）
2. 查看社区反馈，确认目标版本无重大 bug（尤其是刚发布的版本）
3. 不要升级到 RC（发布候选）版本（不稳定）
4. 升级期间不要断电或重启

已知问题版本：
- QTS 5.2.2 Build 20241114 → 升级后无法登录（大量用户报告）
  → 建议升级到后续修复版本，或降回 QTS 5.2.1
```

---

## 一、查看当前版本

```sh
# 查看系统版本
cat /etc/os-release
uname -a

# 通过 getcfg 查看详细版本信息
/sbin/getcfg System Version -f /etc/config/uLinux.conf
/sbin/getcfg System Build -f /etc/config/uLinux.conf
/sbin/getcfg System Model -f /etc/config/uLinux.conf

# 综合显示
echo "型号: $(/sbin/getcfg System Model -f /etc/config/uLinux.conf 2>/dev/null)"
echo "版本: $(/sbin/getcfg System Version -f /etc/config/uLinux.conf 2>/dev/null)"
echo "Build: $(/sbin/getcfg System Build -f /etc/config/uLinux.conf 2>/dev/null)"
```

---

## 二、查看已安装 QPKG 列表

```sh
# 查看所有已安装 QPKG
/sbin/getcfg -f /etc/config/qpkg.conf -a | grep '^\[' | tr -d '[]'

# 查看某个应用版本
# 查询应用状态: /sbin/getcfg <AppName> Enable -f /etc/config/qpkg.conf

# 查看应用启用状态
# 列出所有QPKG: /sbin/getcfg -f /etc/config/qpkg.conf -a | grep '^[' | tr -d '[]'
```

---

## 三、固件升级方式

### 3.1 通过 QTS Web 界面升级（推荐）

```text
控制台 → 系统 → 固件升级
→ 实时更新 → 检查更新
→ 确认版本号后，点击升级
```

### 3.2 通过 Qfinder 工具升级

适用场景：QTS 界面无法访问时（如固件损坏）

```text
Qfinder Pro → 搜索到 NAS → 右键 → 固件更新
→ 选择本地 .img 固件文件
```

固件文件下载：https://www.qnap.com/zh-tw/download

### 3.3 通过 SSH 检查升级状态

```sh
# 查看固件升级日志
cat /var/log/qnap-agent-init.log 2>/dev/null | head -50
ls /tmp/qfwup* 2>/dev/null
```

---

## 四、QTS 5.2.2 登录失败问题（已知 Bug）

**症状：** 升级到 QTS 5.2.2 Build 20241114 后，3秒重置 NAS 后出现错误：
"Your login credentials are incorrect or account is no longer valid."

**原因：** 固件更新引入安全变更导致账户认证机制异常。

**解决方法：**

方法 1：通过 Qfinder 重置网络和安全设置
```text
Qfinder Pro → 找到 NAS → 右键 → 重置为默认网络设置
```

方法 2：回退到 QTS 5.2.1
```text
1. 下载 QTS 5.2.1 固件（从 QNAP 官网）
2. 通过 Qfinder → 固件更新 → 选择 .img 文件强制降级
注意：降级可能存在数据兼容性风险，建议先备份
```

方法 3：硬重置（最后手段，会清除配置）
```text
NAS 背面的 Reset 按钮按住 10 秒（完全重置）
注意：这会清除所有配置，但通常不会删除共享文件夹数据
```

---

## 五、QPKG 应用更新管理

```sh
# 查看待更新的应用
# 列出所有QPKG: /sbin/getcfg -f /etc/config/qpkg.conf -a | grep '^[' | tr -d '[]'

# 通过 GUI 更新（推荐）
# 控制台 → 应用中心 → 已安装 → 检查更新
```

**更新原则：**
- 安全补丁更新优先（如 Malware Remover、SSL）
- 重要应用更新（HBS3、Container Station）在低使用期更新
- 不要同时更新多个关键应用

---

## 六、固件升级前检查清单

```sh
# 1. 确认当前版本
/sbin/getcfg System Version -f /etc/config/uLinux.conf
/sbin/getcfg System Build -f /etc/config/uLinux.conf

# 2. 检查 RAID 状态（确保阵列健康）
cat /proc/mdstat | head -20

# 3. 检查磁盘空间（升级需要足够临时空间）
df -h

# 4. 查看系统日志是否有错误
tail -50 /var/log/messages | grep -iE 'error|fail|critical'

# 5. 检查 Docker 容器状态
docker ps -a --format "table {{.Names}}\t{{.Status}}" 2>/dev/null

# 6. 确认备份已完成（通过 HBS3 查看最后成功时间）
```

升级前**务必**：
- [ ] 有外部完整备份
- [ ] 查看目标版本的社区反馈（等待至少 2 周）
- [ ] RAID 状态正常（非降级）
- [ ] 磁盘空间充足

---

## 七、固件版本历史要点

| 版本 | 重要变化 | 备注 |
|---|---|---|
| QTS 5.2.0 | 引入安全中心（Security Center） | 正式版已修复 CVE-2024-6387 |
| QTS 5.2.1 | 稳定版，安全修复 | 推荐基准版本 |
| QTS 5.2.2 Build 20241114 | **已知 bug：部分型号升级后无法登录** | QNAP 已悄悄撤回部分型号的该版本 |
| QuTS hero h5.2.x | ZFS 版本，存储管理更强 | 硬件要求更高，不适合低配 NAS |

---

## 八、安全要求

- 查看版本信息：只读，无需确认
- 执行固件升级：必须确认，升级期间不可中断
- 降级固件：高风险，必须确认，建议通过 GUI 操作
- 强制重置：最高风险，必须确认，会清除配置
