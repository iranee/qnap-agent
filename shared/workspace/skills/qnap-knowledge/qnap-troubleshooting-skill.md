---
name: qnap-troubleshooting
description: QNAP NAS 常见故障诊断与解决方案。涵盖启动故障、存储故障、网络连接故障、QPKG 应用故障、Docker 故障和系统性能故障，并附真实案例处理流程。
---

# QNAP 故障排查综合指南

> 适用范围：QTS 5.x / 4.5.x 各类故障排查
> 适用场景：NAS 异常、服务中断、存储报警、网络不通

---

## 一、启动类故障

### 1.1 NAS 完全不通电

**排查步骤：**

```text
1. 确认电源线两端都插紧
2. 换插座测试
3. 检查适配器规格和外观（鼓包/焦糊）
4. 拔掉所有硬盘，只保留电源线后尝试开机
5. 拔掉电源线，按住电源键 30 秒释放静电，再插电尝试
```

**LPC 时钟老化问题（TS-x51/x53 机型）：**
- 症状：开机风扇转一下就停，滴一声后无反应
- 原因：LPC 时钟芯片老化，约使用 5-8 年后出现
- 解决：送修更换 LPC 时钟芯片

### 1.2 卡在 QNAP Logo 界面

```text
情况 A：硬盘问题 → 拔掉所有硬盘后尝试启动（能进入 → 某块硬盘有问题）
情况 B：固件损坏 → Qfinder Pro → 固件更新 → 强制更新
情况 C：内存兼容性 → 拔除非原配内存条
情况 D：RAID 损坏 → 联系 QNAP 客服
```

### 1.3 登录界面报错"凭据不正确"

常见于 QTS 5.2.2 升级后：

```text
修复方案 A：Qfinder Pro → 找到 NAS → 重置网络和安全设置
修复方案 B：回退到 QTS 5.2.1（从 QNAP 官网下载固件 → Qfinder 强制刷新）
修复方案 C（最后手段）：NAS 背面 Reset 按钮长按 10 秒（清除配置，不删数据）
```

---

## 二、存储类故障

### 2.1 RAID 降级警告

```sh
# 查看当前 RAID 状态
cat /proc/mdstat

# 查看详细信息
for md in /dev/md*; do
    echo "=== ${md} ==="
    mdadm --detail "${md}" 2>/dev/null | grep -E 'State|Active|Failed|Rebuild'
done
```

**处理原则：**
1. 不要在降级状态下随意拔盘
2. 先确认哪块是故障盘（`mdadm --detail` 中 State: faulty）
3. 更换故障盘后，RAID 会自动重建
4. 重建期间 NAS 性能下降，避免大量读写

### 2.2 存储池只读模式

```sh
# 确认只读状态
df -h
mount | grep -E 'ro[,\)]'

# 解除只读（删除快照后）
/etc/init.d/init_lvm.sh

# 文件系统检查（GUI 操作）
# 存储与快照 → 右击卷 → 管理 → 操作 → 检查文件系统
```

> 详细流程参考：`qnap-snapshot-recovery-skill.md`

### 2.3 磁盘指示灯异常

| 灯状态 | 可能原因 | 处理方式 |
|---|---|---|
| 常亮橙色 | RAID 降级 | 立即更换故障盘 |
| 快速闪烁红色 | 磁盘 I/O 错误 | SMART 检查，准备换盘 |
| 持续高频闪烁 | RAID 重建中 | 等待重建完成 |
| 灭灯但磁盘存在 | 磁盘未识别 | 重新插拔，检查接口 |

---

## 三、网络连接故障

### 3.1 无法通过 SMB 访问

```sh
# 1. 服务状态
/etc/init.d/smbd status 2>/dev/null
ss -tlnp | grep ':445'

# 2. 配置检查
testparm 2>/dev/null | head -20

# 3. 防火墙检查
iptables -L INPUT -n | grep -E '445|139'
```

**Windows 11 24H2 用户：**
- 可能是 SMB 签名策略导致速度下降（参见 qnap-network-skill.md）

### 3.2 Docker 容器无法访问外网

```sh
# 检查 Docker 网络
docker network inspect bridge | grep -E 'Subnet|Gateway'

# 检查容器 DNS
docker exec <容器名> cat /etc/resolv.conf
docker exec <容器名> ping -c 3 8.8.8.8
```

解决：在 Compose 中指定 DNS 服务器（`dns: [8.8.8.8, 1.1.1.1]`）

### 3.3 SSH 连接被拒绝

```sh
# 检查 SSH 服务
ss -tlnp | grep ':22'
cat /etc/ssh/sshd_config | grep -E 'Port|PermitRoot|MaxAuth'

# 检查 IP 访问保护（是否 IP 被封锁）
# 控制台 → 安全 → IP 访问保护 → 查看封锁列表
```

---

## 四、QPKG 应用故障

### 4.1 应用无法启动

```sh
# 通用排查流程
QPKG_NAME="<应用名>"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf 2>/dev/null)

# 1. 确认安装
[ -z "${QPKG_ROOT}" ] && echo "未安装" || echo "路径: ${QPKG_ROOT}"

# 2. 确认启用状态
/sbin/getcfg ${QPKG_NAME} Enable -f /etc/config/qpkg.conf

# 3. 查看启动脚本
ls "${QPKG_ROOT}"/*.sh 2>/dev/null
cat "${QPKG_ROOT}/${QPKG_NAME}.sh" 2>/dev/null | head -30

# 4. 查看日志
ls "${QPKG_ROOT}"/log/ 2>/dev/null
ls "${QPKG_ROOT}"/logs/ 2>/dev/null
tail -50 "${QPKG_ROOT}"/log/*.log 2>/dev/null | head -80

# 5. 系统日志
grep -i "${QPKG_NAME}" /var/log/messages | tail -20
```

### 4.2 Container Station 故障

```sh
QPKG_NAME="container-station"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf)

# PATH 问题（CS3 升级后）
export PATH=$PATH:${QPKG_ROOT}/bin:${QPKG_ROOT}/usr/local/lib/docker/cli-plugins

# 验证 docker compose 可用
docker compose version

# CS3 项目路径
ls /share/Container/container-station-data/application/
```

---

## 五、性能类故障

### 5.1 NAS 整体变慢

```sh
# CPU 负载
uptime
top -b -n 1 | head -20

# 内存
free -m

# 磁盘 I/O
iostat -x 1 5 2>/dev/null

# 查找高资源进程
ps aux --sort=-%cpu | head -15
ps aux --sort=-%mem | head -15

# Docker 资源
docker stats --no-stream
```

**常见原因：**
- 媒体扫描（Photo Station/Music Station 后台扫描）
- RAID 重建
- 快照操作
- Docker 容器内存泄漏

### 5.2 磁盘 I/O 持续 100%

```sh
# 查看各磁盘 I/O
iostat -x 5 3

# 查看进程磁盘访问
lsof /share/CACHEDEV1_DATA/ 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | head -10

# 检查是否有 RAID 重建
cat /proc/mdstat | grep -E 'rebuild|recovery|resync'
```

### 5.3 OOM（内存不足）

```sh
# 查看 OOM 事件
grep -i 'OOM\|out of memory\|killed process' /var/log/messages | tail -10
dmesg | grep -i 'OOM\|out of memory' | tail -5
```

解决：通过 Docker `deploy.resources.limits.memory` 限制容器内存，或停止不必要的服务。

---

## 六、已知 Bug 速查

| 版本 | 问题 | 解决方法 |
|---|---|---|
| QTS 5.2.2 Build 20241114 | 升级后无法登录 | 回退到 5.2.1 或 Qfinder 重置网络设置 |
| CS3 升级后 | SSH 中 docker compose 找不到 | 更新 PATH 或使用完整路径 |
| Windows 11 24H2 | SMB 速度骤降 | 启用 NAS 端 SMB 签名支持 |
| 任何版本 | crontab 重启后失效 | 写入 /etc/config/crontab 而非系统 crontab |

---

## 七、日志位置速查

```sh
# 系统主日志
tail -100 /var/log/messages
dmesg | tail -30

# qnap-agent 日志
QPKG_ROOT=$(/sbin/getcfg qnap-agent Install_Path -f /etc/config/qpkg.conf)
tail -50 ${QPKG_ROOT}/log/watchdog.log
tail -50 ${QPKG_ROOT}/log/qnap-agent.log

# Docker 日志
docker logs --tail 100 <容器名>

# 特定应用日志（通过 QPKG 路径）
QPKG_NAME="<应用名>"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf)
ls "${QPKG_ROOT}"/log/ 2>/dev/null
tail -50 "${QPKG_ROOT}"/log/*.log 2>/dev/null | head -80
```
