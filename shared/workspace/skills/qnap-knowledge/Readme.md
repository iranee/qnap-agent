---
name: qnap-knowledge
description: "QNAP 系统全量知识库 v3，涵盖存储、RAID、Docker、网络、安全、备份、媒体自动化、性能优化、陷阱规避等完整技能体系。适用于 Agent 在 QNAP QTS 环境下处理各类问题。"
metadata: {"nanobot":{"emoji":"🔧","requires":{},"install":[]}}
---

# QNAP 系统知识库（完整版 v3）

> **⚠️ 核心原则：QTS ≠ Ubuntu/Debian/CentOS**
> - 标准 Linux 操作可能损坏系统或导致数据丢失
> - 处理 QNAP 问题时**必须先阅读**本文件和对应子技能
> - 所有危险操作必须先确认再执行

---

## 子技能索引

| 问题类型 | 读取文件 |
|---|---|
| 系统命令、路径、服务管理、QPKG结构、命令行安装、Apache | `qnap-system-skill.md` |
| **RAM disk陷阱、crontab持久化、重启失效、CS3路径** | `qnap-quirks-skill.md` ← **必读** |
| 存储查询、文件操作、磁盘空间、共享文件夹 | `qnap-storage-skill.md` |
| RAID 故障、降级恢复、磁盘更换 | `qnap-raid-skill.md` |
| 快照恢复、厚卷空间限制、只读存储池修复 | `qnap-snapshot-recovery-skill.md` |
| 网络配置、端口、Windows 11 24H2 SMB、Tailscale | `qnap-network-skill.md` |
| Docker、Compose、Container Station 3、PUID/PGID、镜像源 | `qnap-docker-skill.md` |
| 媒体文件、ffmpeg、Arr全家桶、Plex/Emby/Jellyfin | `qnap-media-skill.md` |
| QuMagie、Photo Station迁移、Video Station、QVR、常用Docker镜像 | `qnap-application-skill.md` |
| 备份、HBS3、快照策略、3-2-1原则 | `qnap-backup-skill.md` |
| 安全加固、Deadbolt勒索病毒、VPN方案 | `qnap-security-skill.md` |
| 性能优化、SMB提速、iSCSI、Qtier | `qnap-performance-skill.md` |
| 固件升级、升级失败恢复、已知 Bug 版本 | `qnap-firmware-skill.md` |
| ZeroTier、OpenList、NPS、GoCron、sherpa | `qnap-plugins-skill.md` |
| Entware 包管理器（3500+工具、opkg） | `qnap-entware.md` |
| 共享文件夹、SMB/NFS/FTP/WebDAV | `qnap-shares-skill.md` |
| 综合故障排查（启动/存储/网络/应用/性能） | `qnap-troubleshooting-skill.md` |
| SSL证书、Let's Encrypt、stunnel、acme.sh、证书续期 | `qnap-ssl-skill.md` |
| 禁止操作与安全红线 | `qnap-forbidden-skill.md` |
| 命令速查 | `qnap-cli-reference-skill.md` |
| Agent 升级或回滚 | `qnap-agent-upgrade-skill.md` |
| 整理新技能包 | `qnap-learning-skill.md` |

---

## 🚫 绝对禁止操作

```text
❌ apt/yum/dnf/pip/npm install          系统包管理（Entware已装则/opt内opkg除外）
❌ reboot / shutdown / poweroff          重启关机（无确认）
❌ rm -rf /share/ 或 rm -rf /           大范围删除
❌ mkfs / fdisk / parted / dd of=/dev/  磁盘格式化
❌ passwd / usermod / useradd            用户管理
❌ iptables -F / nft flush               清空防火墙
❌ 写入 /bin /sbin /usr /etc/passwd      系统目录
❌ mdadm --create/--fail/--remove       RAID操作（无确认）
❌ 写入 .qpkg/<非agent应用>/             第三方QPKG目录
❌ crontab -e（直接编辑）               用 /etc/config/crontab 代替
```

---

## ✅ 操作前必须确认

- 删除任何文件 / 批量操作 / 修改权限
- 重启任何 Docker 容器或应用服务
- 向 /etc/config/ 写入内容
- 任何涉及 RAID 成员盘的操作
- 固件或 QPKG 更新

---

## ⚡ 关键记忆点（高频踩坑）

```text
1. / 根目录是 RAM disk，重启后内容清空
   → 配置放 /etc/config/ 或 /share/，数据放 /share/
   → /root/.bashrc 重启消失！写 /etc/config/profile

2. 查询 QPKG 命令
   → 用 /sbin/getcfg <App> Install_Path -f /etc/config/qpkg.conf

3. crontab -e 重启失效
   → 写入 /etc/config/crontab，再执行 crontab /etc/config/crontab

4. CS3 的 Compose 命令是 docker compose（空格），不是 docker-compose

5. Windows 11 24H2 后 SMB 签名强制开启 → 速度骤降或连接失败
   → QTS 端启用"如客户端要求则签名"

6. 快照不等于备份，不等于额外存储空间
   → 厚卷快照恢复时目标空间必须充足，见 qnap-snapshot-recovery-skill.md

7. QuTS hero 路径 /share/ZFS530_DATA/，不是 CACHEDEV1_DATA/

8. RAID 降级状态下禁止随意拔盘
```

---

## 路径基准

```sh
QPKG_NAME="qnap-agent"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf 2>/dev/null)

${QPKG_ROOT}/workspace/skills/    # 技能目录
${QPKG_ROOT}/tools/              # 额外工具（静态二进制）
/share/CACHEDEV1_DATA/           # 主存储池（QTS）
/share/ZFS530_DATA/              # 主存储池（QuTS hero）
/etc/config/                     # 持久化配置目录
/etc/config/qpkg.conf            # QPKG 安装信息
/etc/config/crontab              # 持久化 crontab
/var/log/messages                # 系统主日志
```

---

## 常见症状快速分类

| 症状 | 首先读取 |
|---|---|
| 文件/配置重启后消失 | **qnap-quirks-skill.md** |
| Win11 升级后 SMB 速度骤降/断连 | qnap-network-skill.md（24H2专节） |
| 快照恢复失败/存储池只读 | qnap-snapshot-recovery-skill.md |
| RAID 降级警告 | qnap-raid-skill.md |
| 文件被加密为 .deadbolt | qnap-security-skill.md |
| Docker 容器无法启动 | qnap-docker-skill.md |
| NAS 整体变慢/CPU高 | qnap-troubleshooting-skill.md |
| 固件升级后无法登录 | qnap-firmware-skill.md |
| ZeroTier/Tailscale配置 | qnap-plugins-skill.md / qnap-network-skill.md |
| HTTPS证书过期/申请失败/续期 | qnap-ssl-skill.md |
| 媒体库自动化（Arr全家桶） | qnap-media-skill.md |
| Photo Station 停用迁移 | qnap-application-skill.md |
| 需要安装系统工具（jq/python3等） | qnap-entware.md |

---

## SSL 证书核心记忆点

```text
/etc/stunnel/stunnel.pem  = HTTPS 核心证书文件（格式：私钥+证书+中间链拼接）
→ 该文件重启后持久（链接到 /mnt/HDA_ROOT/.config/stunnel/）

证书部署：cat privkey.pem fullchain.pem > /etc/stunnel/stunnel.pem
重启服务：/etc/init.d/stunnel.sh stop && start; /etc/init.d/Qthttpd.sh stop && start

申请工具优先级：QTS GUI > acme.sh(DNS-01) > qnap-letsencrypt(HTTP-01)
工具和证书脚本必须放在 /share/ 下（RAM disk 外），不能放 /root/ 或 /etc/ssl/
```
