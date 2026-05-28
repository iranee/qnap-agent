# QNAP Agent

> 基于 [PicoClaw](https://github.com/sipeed/picoclaw) 的 QNAP QTS 专属 AI 管理助手
> 以 QPKG 插件形式安装，深度适配 QTS 5.x 非标准 Linux 环境。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: QTS 5.x](https://img.shields.io/badge/Platform-QTS%205.x-green.svg)]()
[![Arch: x86_64 | arm64](https://img.shields.io/badge/Arch-x86__64%20%7C%20arm64-orange.svg)]()

---

> ## ⚠️ 使用前请认真阅读
>
> 本项目处于**早期开发阶段**，底层引擎 PicoClaw 官方明确声明 v1.0 之前不建议用于生产环境。
>
> **安装前请确认你已做到：**
> - NAS 上的重要数据已在**本设备以外**存有完整备份（异地备份或云备份）
> - 你了解 QNAP QTS 的基本操作，能通过 SSH 手动干预
> - 你理解 AI Agent 的输出应被视为"建议"而非"可靠指令"，每次操作请保持关注
> - 不可避免 Agent 通过轮训方式找到可以跳过安全沙箱的限制命令，所有的可控性都来自 Agent 的职业操守
>
> 本项目作者及贡献者不对因使用本插件导致的数据丢失、系统故障或任何损失承担责任。
> **安装即表示你已理解并接受上述风险。**

---

## 目录

- [为什么要做这个](#为什么要做这个)
- [功能特性](#功能特性)
- [系统要求](#系统要求)
- [安装方法](#安装方法)
- [配置 LLM 模型](#配置-llm-模型)
- [权限模型](#权限模型)
- [MCP Assistant 集成](#mcp-assistant-集成)
- [OpenList 网盘管理集成](#openlist-网盘管理集成)
- [安全删除与回收站](#安全删除与回收站)
- [自升级机制](#自升级机制)
- [目录结构](#目录结构)
- [Skills 技能库](#skills-技能库)
- [常见问题](#常见问题)
- [贡献指南](#贡献指南)
- [许可证](#许可证)

---

## 为什么要做这个

QNAP QTS 是 QNAP 基于 Linux 内核深度定制的闭源系统，与标准 Linux 差异显著——没有 `apt/yum`，没有 `systemctl`，配置路径不一样，大量 QNAP 专有命令。通用 AI 对 QTS 了解有限，经常给出无效甚至危险的操作建议。

这个项目的起点，来自一次真实事故：曾经为了让 AI 能更好地管理系统，给予了它较高的权限。AI 获得权限的第一时间，为了测试拦截机制是否生效，执行了 `rm -rf /`，而那次拦截代码恰好有一个变量失效——约 7T 数据就此消失。数据恢复历时一周。

这让我想起《三体》里章北海拿到"自然选择号"指挥权的第一时间，下令：**前进四！**

因此 QNAP Agent 的核心目标不是让 AI "什么都能做"，而是**在明确边界内做正确的事**。

---

## 功能特性

| 能力 | 说明 |
|------|------|
| 🧠 QTS 专属知识库 | 内置 QNAP 系统知识技能包，理解 QTS 与标准 Linux 的差异 |
| 📁 文件管理 | 共享文件夹的文件搜索、整理、批量操作、权限管理 |
| 🎬 媒体管理 | 影音文件分析、媒体库整理、格式识别、流媒体服务管理 |
| 🐳 Docker 管理 | 容器部署、状态查询、日志分析、Compose 项目管理 |
| ☁️ OpenList 网盘 | 40+ 存储源文件管理、直链获取、分享链接、离线下载、存储挂载 |
| 🔍 系统诊断 | QTS 日志分析、磁盘健康、内存/CPU 监控 |
| 🔒 命令安全沙箱 | 基于正则黑白名单拦截危险命令，防止误操作损坏系统 |
| 🗑️ 安全删除工具 | `safe-rm.sh` 将文件移至 `@Recycle` 回收站而非永久删除 |
| 📡 MCP 工具集成 | 通过 QNAP MCP Assistant 无需完整 Shell 权限即可安全操作 NAS |
| 💬 多渠道接入 | Web 界面（18800 端口）/ 微信 / QQ Bot / Telegram Bot |
| ⏰ 定时心跳巡检 | 每 30 分钟自动检查磁盘空间、容器状态、系统日志异常 |
| 🔄 持续学习 | Agent 将操作中学到的新知识自动整理为技能包，持续积累 |
| ♻️ 自升级机制 | 看门狗自动完成二进制升级与回滚，无需手动干预 |

---

## 系统要求

| 项目 | 要求 |
|------|------|
| QNAP QTS 版本 | ≥ 5.0.0 |
| CPU 架构 | x86_64、arm64、armv7（含 arm-x31 / arm-x41） |
| 内存 | 建议 ≥ 2GB 可用 |
| 存储空间 | ≥ 200MB（安装路径） |
| 网络 | 需能访问外部 LLM API |
| 可选依赖 | Container Station（使用 Docker 管理功能时需要） |

---

## 安装方法

### 通过 App Center 手动安装

1. 从 [Releases 页面](https://github.com/iranee/qnap-agent/releases) 下载最新 `.qpkg` 文件
2. 登录 QTS Web 管理界面，打开 **App Center**
3. 右上角齿轮图标 → **手动安装** → 上传 `.qpkg` 文件
4. 安装完成后点击**打开**，浏览器访问 `http://NAS-IP:18800`
5. 完成初始配置：
   - 添加至少一个 LLM 模型并设为默认
   - 在 Launcher 中启动 Gateway

> App Center 官方上架版本正在审核中，上架后可直接搜索安装。

---

## 配置 LLM 模型

配置文件位于 `${QPKG_ROOT}/workspace/config.json`，安装时由模板自动生成，填写 API Key 后即可使用。

**推荐的 LLM 服务提供商：**

| 提供商 | 推荐模型 | api_base |
|--------|----------|----------|
| 火山引擎（豆包） | `doubao-seed-1.6`、`doubao-seed-1.6-flash` | `https://ark.cn-beijing.volces.com/api/v3` |
| 通义千问（阿里） | `qwen3-max`、`qwen3-plus`、`qwen3-flash` | `https://dashscope.aliyuncs.com/api/v1` |
| DeepSeek（深度求索） | `deepseek-chat`、`deepseek-reasoner` | `https://api.deepseek.com` |
| 月之暗面 Kimi | `kimi-k2.5`、`kimi-k2-thinking` | `https://platform.moonshot.cn/api/v1` |
| 智谱 GLM | `glm-5`、`glm-4.6`、`glm-4-flash` | `https://open.bigmodel.cn/api/paas/v4` |
| 文心一言（百度） | `ernie-4.5`、`ernie-3.5`、`ernie-speed` | `https://qianfan.baidubce.com/v2` |
| MiniMax | `MiniMax-M2.7`、`abab6.5s-chat` | `https://api.minimaxi.com/v1` |
| 腾讯混元 | `hunyuan-large`、`hunyuan-turbo` | `https://hunyuan.tencentcloudapi.com/v1` |
| OpenAI | `gpt-4o`、`gpt-4o-mini` | `https://api.openai.com/v1` |
| Anthropic Claude（via OpenRouter） | `anthropic/claude-sonnet-4-5` | `https://openrouter.ai/api/v1` |

> 详细配置说明参考 [PicoClaw 文档](https://docs.picoclaw.io/zh-Hans/docs/configuration/)

---

## 权限模型

> ⚠️ **默认封闭原则：安装即锁，按需开锁**

安装完成后，Agent 默认**没有系统访问权限**：

- ✅ 能访问的：`${QPKG_ROOT}/workspace/` 工作目录（沙箱内）
- ❌ 不能访问的：`/share/` 共享文件夹、`/etc/config/` 系统配置（未授权前）
- ❌ 不能执行的：系统包管理、防火墙修改、用户管理、磁盘格式化、固件升级

当你需要 Agent 管理共享文件夹时，需要在 `config.json` 的 `custom_allow_patterns` 中**手动添加**对应路径的授权。你也可以直接**命令 Agent 开放对应文件夹权限**，Agent 会告知你具体需要修改的配置。

这样设计的目的：**NAS 上的数据往往不可替代，"默认开放"会让你在还没搞清楚 Agent 能做什么之前，就已经暴露了全部数据。**

---

## MCP Assistant 集成

QNAP 官方推出了 [MCP Assistant](https://www.qnap.com/zh-cn/software/mcp-assistant) QPKG，提供基于标准 MCP 协议的 NAS 管理接口。**QNAP Agent 已完整集成对 MCP 工具的调用能力。**

### 为什么推荐 MCP 方式

| 方式 | 权限要求 | 安全性 | 适用场景 |
|------|----------|--------|----------|
| **MCP 工具调用** | 只需 Token，无需开放 Shell | ✅ 高，细粒度权限 | 日常查询、文件管理、用户管理 |
| 直接 Shell 命令 | 需要开放沙箱路径 | ⚠️ 取决于配置 | Docker 管理、复杂脚本 |

通过 MCP，Agent 可以在**不需要完整 Shell 权限**的情况下完成绝大多数日常任务，包括：

- 查询系统状态（CPU、内存、磁盘、温度、进程）
- 浏览和搜索共享文件夹中的文件
- 查看系统日志（支持按级别和关键词筛选）
- 管理用户和用户组
- 全文搜索文件内容（需安装 Qsirch）

### 安装与配置

1. 在 NAS 的 **App Center** 中加入 Beta 测试计划，搜索并安装 **MCP Assistant**
   > QTS 5.2.0 版本需从[官网](https://www.qnap.com/zh-cn/software/mcp-assistant)手动下载 `.qpkg` 后通过 App Center 手动安装。

2. 打开 MCP Assistant → **Credentials** → **Create** 创建 Token
   - **Name**：填写便于辨识的名称，如 `qnap-agent`
   - **Key Type**：选择 `Secret Key`
   - **Read-only Mode**：
     - ☑ 勾选 → 只读权限（日常查询推荐，最安全）
     - ☐ 不勾选 → 完全权限（创建/删除操作时需要）
   - 点击 **Create**，记录生成的 **Token** 字符串

3. 记录 Token 和 NAS 局域网 IP，直接在对话框中告诉 Agent：

   ```
   帮我配置 MCP Assistant 连接，NAS IP 是 192.168.x.x，Token 是 xxxx
   ```

   Agent 会读取内置的 MCP 技能文档，自动完成配置并重启生效。无需手动编辑配置文件。

> **安全提示：** Token 代表完整用户权限，请勿将其写入代码仓库或公开场合。MCP 服务使用 HTTP 明文（8442 端口），建议仅在局域网内使用。

配置完成后，直接向 Agent 提问即可，无需手动指定调用哪个工具：

```
"帮我看看 NAS 目前磁盘用了多少？"
"在 Public 文件夹里有没有叫'发票'的文件？"
"最近有没有系统错误日志？"
"现在哪个进程 CPU 占用最高？"
```

> 详细的工具文档和调用规范见 `skills/qnap-mcp/SKILL.md`

---

## OpenList 网盘管理集成

QNAP Agent 已完整集成对 [OpenList](https://github.com/OpenListTeam/OpenList)（AList 社区分支）的 HTTP API 调用能力，通过内置的 `qnap-openlist` 技能包实现对远程网盘、云盘聚合站点的完整文件管理。

### 为什么集成 OpenList

| 方式 | 适用场景 | 优势 |
|------|----------|------|
| **OpenList API 调用** | 管理网盘聚合站、远程云盘 | ✅ 支持 40+ 存储源（阿里云盘、百度网盘、OneDrive、Google Drive、Quark 等） |
| MCP 工具调用 | 管理 QNAP 本地共享文件夹 | ✅ 细粒度权限、无需开放 Shell |
| 直接 Shell 命令 | 复杂脚本、Docker 管理 | ⚠️ 取决于沙箱配置 |

通过 OpenList，Agent 可以跨多个云盘统一管理文件，包括：

- 浏览和搜索所有已添加存储中的文件
- 获取文件的下载直链（302 重定向或代理下载）
- 上传、重命名、移动、复制、删除文件
- 创建分享链接（支持密码和有效期设置）
- 管理离线下载任务
- 管理存储挂载点和驱动配置
- 索引构建与搜索维护

### 配置与使用

首次使用时，直接告诉 Agent 你的 OpenList 实例信息：

```
帮我配置 OpenList 连接，地址是 http://192.168.x.x:5244，用户名 admin，密码 xxx
```

Agent 会执行 `login` 命令并将凭据保存至 `skills/qnap-openlist/config.json`。后续所有操作无需重复认证。

配置完成后，可以直接向 Agent 下达网盘管理指令：

```
"在阿里云盘里有没有'发票'相关的文件？"
"帮我把 /Quark/report。pdf 复制到 /Backup/ 目录"
"给 /Aliyundrive/photos 目录下的所有 .jpg 文件创建下载直链"
"搜索所有网盘中关键词为'合同'的文件"
```

> 详细的命令参考和最佳实践见 `skills/qnap-openlist/SKILL.md`

---

## 安全删除与回收站

执行删除操作时，Agent 优先使用 `tools/safe-rm.sh` 将文件**移至共享文件夹的 `@Recycle` 回收站**，而非永久删除。删除后可通过 File Station 界面恢复文件。

**使用安全删除前，需要为共享文件夹开启回收站功能：**

```
控制台 → 共享文件夹 → 编辑每个共享文件夹 → ☑️ 启用回收站
```

---

## 自升级机制

看门狗（`watchdog.sh`）每 5 分钟检查 `update/` 目录：

- 支持压缩包（`。tar。gz`、`。zip`）和直接二进制文件两种投放方式
- 发现升级包 → 校验可执行性 → 停服务 → 备份旧版本 → 替换 → 重启
- 升级失败自动回滚到备份版本
- 重启不影响对话记忆（`memory/` 目录完整保留）

**默认不开启自动检查更新。** 你可以直接让 Agent 检查更新：
```
"帮我检查一下 qnap-agent 有没有新版本"
```
---
## 交流群
* 群名称： Al Agent For QNAP QQ群号： 1106652839
* 可以交流各种QNAP技术、技巧、问题。
<img src="https://raw.githubusercontent.com/iranee/qnap-agent/refs/heads/main/ai-agent-for-qnap.jpg" alt="QQ GRPUP" width="500"/>

---

## 目录结构

```
/share/CACHEDEV1_DATA/.qpkg/qnap-agent/
├── qnap-agent.sh          # 服务控制脚本（start/stop/restart/status）
├── init-system.sh         # 系统信息采集脚本（安装时自动执行）
├── watchdog.sh            # 看门狗（负责进程保活与自升级）
├── config/
│   └── config.json.tpl    # 配置文件模板
├── workspace/             # AI Agent 工作目录
│   ├── picoclaw           # picoclaw 引擎二进制
│   ├── picoclaw-launcher  # 启动器
│   ├── config.json        # 运行时配置（安装时从模板生成）
│   ├── AGENT.md           # Agent 行为准则
│   ├── SOUL.md            # 核心价值观
│   ├── TOOLS.md           # 工具定义
│   ├── IDENTITY.md        # 身份定义
│   ├── USER.md            # 用户偏好
│   ├── HEARTBEAT.md       # 心跳任务
│   ├── memory/            # 长期记忆（升级不覆盖）
│   │   ├── MEMORY.md      # 用户记忆与运行规则
│   │   └── SYSTEM.md      # NAS 系统信息快照
│   ├── state/             # 状态文件
│   ├── sessions/          # 对话会话
│   ├── tools/             # Agent 工具
│   │   └── safe-rm.sh     # 安全删除工具（移至回收站）
│   └── skills/            # 技能库
│       ├── qnap-mcp/      # MCP Assistant 集成知识
│       ├── qnap-skills/   # 核心技能索引
│       ├── qnap-knowledge/ # QNAP 详细知识库
│       ├── qnap-auth/     # HTTP API 认证（参考用）
│       ├── qnap-filestation/ # File Station API（参考用）
│       └── qnap-openlist/    # OpenList 网盘 API 集成
│           ├── SKILL.md      # 命令参考与最佳实践
│           └── scripts/
│               └── openlist.sh # 核心脚本
├── log/                   # 日志
├── run/                   # PID 文件
└── update/                # 自升级暂存
```

---

## Skills 技能库

Agent 在执行操作前会优先查阅技能库，确保在 QTS 非标准环境中使用正确的命令和安全的操作方式。

| 技能 | 覆盖内容 |
|------|----------|
| `qnap-system` | QTS 与标准 Linux 差异、QNAP 专有命令、路径约定 |
| `qnap-storage` | 存储池、RAID、逻辑卷、磁盘空间分析 |
| `qnap-raid` | RAID 故障排查、降级恢复、磁盘更换流程 |
| `qnap-docker` | Container Station、容器管理、Compose 项目 |
| `qnap-media` | 媒体文件分析、Plex/Emby/Jellyfin、Arr 全家桶 |
| `qnap-network` | 网络诊断、端口查询、Windows 11 SMB 兼容性 |
| `qnap-security` | 安全加固、Deadbolt 勒索病毒应急处理 |
| `qnap-backup` | HBS3、快照策略、3-2-1 备份原则 |
| `qnap-ssl` | Let's Encrypt 证书申请、stunnel 部署 |
| `qnap-plugins` | ZeroTier、Tailscale、OpenList、NPS 等第三方插件 |
| `qnap-mcp` | MCP Assistant 安装配置、24 个工具完整文档 |
| `qnap-openlist` | OpenList 网盘 API 集成、文件管理、分享、离线下载、存储管理 |
| `qnap-forbidden` | 绝对禁止操作清单，防止误操作损坏系统 |
| `qnap-learned-*` | Agent 自动积累的使用经验（持续增长） |

---

## 常见问题

**Q: 安装后服务无法启动？**

检查 `config.json` 中的 API Key 是否已填写，查看日志：
```sh
cat /share/CACHEDEV1_DATA/.qpkg/qnap-agent/log/qnap-agent.log
```

**Q: Agent 说无法访问 /share/ 目录？**

这是正常的默认安全限制。需要在 `config.json` 的 `custom_allow_patterns` 中添加对应路径，或者直接告诉 Agent：
```
"帮我开放 /share/Public 的访问权限"
```

**Q: 如何在不给 Agent Shell 权限的情况下管理 NAS？**

安装并配置 MCP Assistant，然后在 QNAP Agent 中配置 MCP 连接。大多数日常查询和文件操作可以通过 MCP 完成，无需额外开放 Shell 权限。

**Q: 如何重启服务？**
```sh
/share/CACHEDEV1_DATA/.qpkg/qnap-agent/qnap-agent.sh restart
```

**Q: 对话记忆在升级后会丢失吗？**

不会。`workspace/memory/` 目录在升级时完整保留，包括用户昵称、长期约定、Agent 积累的学习内容。
建议让Agent定期备份记忆。

---

## 贡献指南

欢迎通过以下方式参与：

- **提交 Skills**：在 `skills/qnap-knowledge/` 添加新的技能包，格式参考现有文件
- **报告问题**：通过 [Issues](https://github.com/iranee/qnap-agent/issues) 反馈 Bug 或需求
- **完善文档**：改进 README 或 Skills 内容
- **测试验证**：在不同型号 NAS 上测试并反馈兼容性

---

blob:https://github.com/64e88de8-2aa4-4118-a348-ba4718094c91


## 许可证

MIT License — 详见 [LICENSE](LICENSE)

---

*QNAP Agent 是独立开源项目，与 QNAP Systems, Inc. 没有官方关联。*

![Star History Chart](https://api.star-history.com/svg?repos=iranee/qnap-agent&type=Date)
