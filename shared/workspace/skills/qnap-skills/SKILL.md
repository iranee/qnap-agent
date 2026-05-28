---
name: qnap-skills
description: "QNAP 技能包总目录。包含所有 QNAP 相关技能的完整索引：系统知识库（qnap-knowledge）、HTTP API 认证（qnap-auth）、File Station API（qnap-filestation）。"
---

# QNAP 技能包总目录

> 本文件是所有 QNAP 相关技能的主索引。
> 即使此文件从 Agent 技能列表中被删除，实际技能文件仍保留在对应目录中。
> 在 AGENT.md 中已内嵌精简版索引，确保技能始终可用。

---

## 技能分类总览

### 一、QNAP 系统知识库（qnap-knowledge）

> 纯知识类技能，不涉及 HTTP API 调用。适用于所有 Agent 在 QNAP QTS 环境下执行系统操作。

| 技能文件 | 描述 |
|---|---|
| `skills/qnap-knowledge/Readme.md` | 知识库入口索引 |
| `skills/qnap-knowledge/qnap-system-skill.md` | QTS 系统架构、命令差异、QPKG 管理 |
| `skills/qnap-knowledge/qnap-quirks-skill.md` | RAM disk 陷阱、重启后失效、crontab 持久化 |
| `skills/qnap-knowledge/qnap-storage-skill.md` | 存储架构、空间分析、共享文件夹 |
| `skills/qnap-knowledge/qnap-raid-skill.md` | RAID 状态、降级恢复、磁盘更换 |
| `skills/qnap-knowledge/qnap-snapshot-recovery-skill.md` | 快照恢复实战、只读存储池修复、跨存储池迁移 |
| `skills/qnap-knowledge/qnap-network-skill.md` | 网络配置、SMB/NFS、远程访问 |
| `skills/qnap-knowledge/qnap-docker-skill.md` | Docker、Container Station、Compose |
| `skills/qnap-knowledge/qnap-media-skill.md` | ffmpeg、媒体文件分析、媒体服务 |
| `skills/qnap-knowledge/qnap-application-skill.md` | QuMagie、Video Station、QVR、虚拟化 |
| `skills/qnap-knowledge/qnap-backup-skill.md` | HBS3、快照、3-2-1 备份策略 |
| `skills/qnap-knowledge/qnap-security-skill.md` | 安全加固、勒索病毒应急 |
| `skills/qnap-knowledge/qnap-performance-skill.md` | SMB 性能优化、iSCSI、Qtier |
| `skills/qnap-knowledge/qnap-firmware-skill.md` | 固件升级、版本管理 |
| `skills/qnap-knowledge/qnap-ssl-skill.md` | QTS SSL/TLS 证书生成、管理指南 |
| `skills/qnap-knowledge/qnap-plugins-skill.md` | ZeroTier、OpenList、NPS、GoCron |
| `skills/qnap-knowledge/qnap-forbidden-skill.md` | 禁止操作与安全红线 |
| `skills/qnap-knowledge/qnap-cli-reference-skill.md` | 命令速查参考 |
| `skills/qnap-knowledge/qnap-shares-skill.md` | 共享文件夹、SMB、NFS、FTP |
| `skills/qnap-knowledge/qnap-qnap-entware.md` | Entware 包管理器 |
| `skills/qnap-knowledge/qnap-troubleshooting-skill.md` | 常见故障诊断与排查 |
| `skills/qnap-knowledge/qnap-learning-skill.md` | 新知识沉淀整理规范 |

---

### 二、QNAP HTTP API 认证（qnap-auth）

> HTTP API 类技能，通过网络 API 与 QNAP NAS 交互。需要先获取 sid 会话令牌。

| 技能文件 | 描述 |
|---|---|
| `skills/qnap-auth/SKILL.md` | QTS HTTP API 认证（密码/qtoken/2SV 登录、sid 管理） |

**来源：** QNAP 官方白皮书 QTS HTTP API – Authentication v5.1.0

**重要提示（密码编码）：**
```python
# 正确：UTF-16-LE 再 Base64
base64.b64encode(password.encode('utf-16-le'))
# 错误（对非 ASCII 密码会失败）：
base64.b64encode(password.encode('utf-8'))
```

---

### 三、QNAP File Station API（qnap-filestation）

> HTTP API 类技能，通过 File Station HTTP API 操作 QNAP 上的文件。前置依赖：qnap-auth。

| 技能文件 | 描述 |
|---|---|
| `skills/qnap-filestation/SKILL.md` | File Station API 总览、快速索引 |
| `skills/qnap-filestation/references/qnap-basic-operations-skill.md` | 创建/重命名/复制/移动/删除 |
| `skills/qnap-filestation/references/qnap-upload-download-skill.md` | 上传/下载/断点续传/缩略图 |
| `skills/qnap-filestation/references/qnap-recycle-bin-skill.md` | 安全删除、回收站恢复（⚠️ 核心安全机制） |
| `skills/qnap-filestation/references/qnap-file-list-skill.md` | 文件树/列表/搜索 |
| `skills/qnap-filestation/references/qnap-acl-permissions-skill.md` | 权限读取与设置 |
| `skills/qnap-filestation/references/qnap-share-links-skill.md` | 共享链接创建与管理 |
| `skills/qnap-filestation/references/qnap-search-compress-skill.md` | 搜索/ISO挂载/压缩解压 |
| `skills/qnap-filestation/references/qnap-media-dlna-skill.md` | 媒体转码、DLNA |
| `skills/qnap-filestation/references/qnap-storage-info-skill.md` | 存储容量、主机名 |
| `skills/qnap-filestation/references/qnap-picoclaw-integration-skill.md` | Agent 集成最佳实践 |
| `skills/qnap-filestation/references/qnap-error-codes-skill.md` | File Station 错误码完整参考 |

**来源：** QNAP 官方白皮书 QNAP QTS File Station HTTP API v5

---

## 技能调用原则

1. **先读 SOUL.md** — 任何操作前确认行为边界
2. **系统操作用知识库** — 不需要 HTTP API 时，直接参考 qnap-knowledge
3. **文件操作用 File Station API** — 需要操作文件时，先认证（qnap-auth），再调用（qnap-filestation）
4. **两套技能相互独立** — qnap-knowledge 和 API 技能互不混用
5. **WEB UI 优先** — 参见 SOUL.md 第一原则

---

## 快速决策树

```
用户任务是什么？
  ├── 系统信息/状态查询 → qnap-knowledge/qnap-system-skill.md
  ├── 存储/RAID 查询 → qnap-knowledge/qnap-storage-skill.md + qnap-raid-skill.md
  ├── 网络问题 → qnap-knowledge/qnap-network-skill.md
  ├── Docker 容器 → qnap-knowledge/qnap-docker-skill.md
  ├── 备份/快照 → qnap-knowledge/qnap-backup-skill.md
  │                （只读状态查询，创建任务引导用户去 GUI）
  ├── 文件操作（通过 HTTP API）
  │   ├── 登录获取 sid → qnap-auth/SKILL.md
  │   └── 文件操作 → qnap-filestation/SKILL.md + references/
  ├── 故障排查 → qnap-knowledge/qnap-troubleshooting-skill.md
  └── 不确定操作是否允许 → qnap-knowledge/qnap-forbidden-skill.md + SOUL.md
```
