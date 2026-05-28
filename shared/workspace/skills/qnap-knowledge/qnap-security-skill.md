---
name: qnap-security
description: QNAP NAS 安全加固、勒索病毒（Deadbolt/QLocker）应急处理、漏洞防护、访问控制最佳实践与远程访问安全方案。
---

# QNAP 安全防护与应急处理

> 适用范围：QTS 5.x 安全管理
> 适用场景：安全加固、勒索病毒应急、漏洞应对、访问控制

---

## 一、安全基本原则

```
QNAP NAS 的最大安全威胁来自公网暴露。
不直接将 NAS 管理端口暴露到公网 = 规避 90% 的攻击风险。

三条必做（顺序执行）：
1. 禁用路由器对 NAS 的端口转发（8080/443）
2. 禁用 myQNAPcloud 的 UPnP 自动端口映射
3. 远程访问改用 VPN（Tailscale/WireGuard/ZeroTier）
```

---

## 二、安全加固清单

### 2.1 关闭公网暴露

```sh
# 检查 UPnP 配置
/sbin/getcfg myQNAPcloud AutoRouterConfig -f /etc/config/uLinux.conf 2>/dev/null
```

**GUI 操作（必须）：**
1. **myQNAPcloud → 自动路由器配置 → 禁用 UPnP 端口转发**
2. **路由器管理界面 → 删除 NAS 的端口转发规则（8080/443）**

### 2.2 账户安全

```sh
# 查看当前用户列表（只读）
cat /etc/passwd | grep -v 'nologin\|false\|/sbin' | grep -v '^#'
```

**账户安全操作（通过 QTS GUI）：**
- 更改 admin 默认密码（16 位以上混合字符）
- 启用双重认证（2FA）：控制台 → 权限 → 用户 → 管理员账户
- 关闭不使用的账户
- 配置 IP 访问保护（控制台 → 安全 → IP 访问保护）

### 2.3 SSH 安全

```sh
# 检查 SSH 监听
ss -tlnp | grep ':22'
cat /etc/ssh/sshd_config | grep -E 'Port|PermitRoot|PasswordAuth|MaxAuth'
```

**SSH 安全配置建议：**
- 非必要不开 SSH，开启后改为非标准端口（如 22222）
- 只允许来自特定 IP 的 SSH 连接（IP 访问保护）
- 使用 SSH 密钥认证替代密码认证（更安全）
- 不要直接将 SSH 端口暴露到公网

### 2.4 服务最小化

```sh
# 检查正在监听的端口
ss -tlnp
ss -ulnp
```

关闭不需要的服务（控制台 → 网络与文件服务）：
- 不需要 Telnet → 关闭
- 不需要 FTP → 关闭（改用 SFTP）
- 不需要 WebDAV → 关闭（如有替代方案）
- 媒体服务（Photo Station/Music Station）不用 → 关闭（这些服务曾是 Deadbolt 攻击入口）

---

## 三、远程访问安全方案

**绝对禁止**将管理端口（8080/443）或 SSH（22）直接暴露到公网。

**推荐方案（按安全性从高到低）：**

```
1. Tailscale QPKG（App Center → Communications → Tailscale）
   → 零配置，无需端口转发，基于 WireGuard，个人免费
   
2. QVPN WireGuard
   → 只需开放一个 UDP 端口（51820），配置简单，性能最好
   
3. ZeroTier（qnap-zerotier QPKG 或 Docker 方式）
   → 需要在 my.zerotier.com 管理授权，25设备免费
   
4. myQNAPcloud Link（中继方式，不开放端口）
   → 速度受 QNAP 服务器限制，适合低频访问
```

---

## 四、勒索病毒 Deadbolt 应急处理

### 4.1 识别特征

- NAS 登录页面被替换为勒索提示（要求比特币支付）
- 文件被加密，扩展名变为 `.deadbolt`
- 无法通过正常 URL 登录 QTS

### 4.2 立即行动（发现后第一时间）

```
顺序不能错：
1. 断开 NAS 与互联网的连接（拔网线或在路由器上隔离）
   → 保持局域网连通，以便后续操作
2. 不要关机（可能截断加密进程）
3. 截图保存勒索页面
4. 检查外部备份是否完好
```

### 4.3 通过备用 URL 访问 QTS（绕过勒索页面）

```
https://NAS_IP/cgi-bin/index.cgi
http://NAS_IP:8080/cgi-bin/index.cgi
```

### 4.4 如果加密仍在进行中——紧急停止

```sh
# SSH 连入 NAS
ps -ef | grep -iE 'deadbolt|crypt|enc'
# 找到可疑进程 PID，强制终止
kill -9 <PID>
```

### 4.5 有备份情况下的完整恢复步骤

```
1. 通过备用 URL 登录 QTS
2. myQNAPcloud → 禁用 UPnP 端口映射
3. 应用中心 → 更新所有应用（尤其是 Malware Remover）
4. Malware Remover → 扫描 → 等待完成
   应看到："Detected and quarantined the DEADBOLT portal"
5. 重启 NAS
6. 控制台 → 固件升级 → 升级到最新稳定版
7. 从外部备份恢复数据
8. 执行安全加固清单（全部重做）
```

### 4.6 无备份情况

Deadbolt 使用 AES-128 加密，**没有密钥无法解密**。

可采取的行动：
- 将所有加密的 `.deadbolt` 文件拷贝到外部存储保存（等待未来可能的解密工具）
- 联系专业数据恢复机构（成功率低且费用高）
- **不建议支付赎金**（无法确保获得有效密钥）

### 4.7 恢复后安全加固（必须全部完成）

```sh
# 验证当前状态
ss -tlnp
/sbin/getcfg myQNAPcloud AutoRouterConfig -f /etc/config/uLinux.conf
```

清单：
- [ ] 路由器删除所有针对 NAS 的端口转发
- [ ] 禁用 UPnP
- [ ] 更改管理员密码
- [ ] 启用 2FA
- [ ] 配置 IP 访问保护
- [ ] SSH 改非标端口（或关闭）
- [ ] 安装并配置 Tailscale/WireGuard 进行远程访问
- [ ] 建立 3-2-1 备份策略

---

## 五、安全中心（Security Center，QTS 5.2+）

```sh
/etc/init.d/SecurityCenter status 2>/dev/null
ls /var/log/ | grep -i security
```

**核心功能：**
- 实时监控文件异常修改（如批量加密行为）
- 检测到异常时自动触发快照保护（给恢复留时间窗口）
- 异常访问告警

在 QTS 5.2+ 上应启用安全中心，可在勒索病毒开始加密时，在所有文件被加密之前触发保护性快照。

---

## 六、已知重要漏洞

| CVE | 影响范围 | 严重程度 | 缓解措施 |
|---|---|---|---|
| CVE-2024-6387 (regreSSHion) | OpenSSH RCE | 严重 | 不暴露 SSH 到公网即不受影响 |
| CVE-2024-48859 | QTS 5.1.x/5.2.x | 高危 | 不暴露管理界面 + 升级固件 |
| CVE-2024-50402/50403 | QTS 5.1.x/5.2.x | 中危 | 需管理员权限才可利用 |
| Deadbolt 系列 | 多版本 QTS | 灾难性 | 不公网暴露 + 保持固件最新 |
| QLocker | QTS 4.x | 严重 | 不公网暴露 + 及时打补丁 |

**根本防护：** 不暴露管理界面到公网 + 保持固件最新版 + 启用 2FA。

---

## 七、Malware Remover 使用

```sh
QPKG_DIR=$(/sbin/getcfg MalwareRemover Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
echo "Malware Remover: ${QPKG_DIR}"

# 查看最近扫描日志
ls "${QPKG_DIR}" 2>/dev/null
```

**GUI 使用：** 应用中心 → Malware Remover → 立即扫描

勒索病毒攻击后必须执行一次完整扫描。

---

## 八、安全事件审计

```sh
# 最近登录记录
last 2>/dev/null | head -30

# 安全相关日志
grep -iE 'failed|denied|unauthorized|invalid|brute' /var/log/messages | tail -30

# 异常进程
ps aux | sort -k3 -rn | head -20

# 异常网络连接（外出连接）
ss -tnp | grep ESTABLISHED | grep -v '127.0.0.1'
netstat -tnp 2>/dev/null | grep ESTABLISHED | grep -v '127.0.0.1'

# 可疑定时任务
crontab -l 2>/dev/null
ls /etc/cron.d/ 2>/dev/null
cat /var/spool/cron/crontabs/admin 2>/dev/null
```

---

## 九、安全要求

- 安全状态查询：只读，无需确认
- 勒索病毒迹象出现时：**优先建议用户断网**，再进行诊断
- 密码操作：禁止，通过 QTS GUI 操作
- 防火墙规则修改：必须确认
- 禁止 `iptables -F`
