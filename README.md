# QNAP Agent

> 基于 [PicoClaw](https://github.com/sipeed/picoclaw) 的 QNAP QTS 专属 AI 管理助手
> 以 QPKG 插件形式安装，深度适配 QTS 5.x 非标准 Linux 环境。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: QTS 5.x](https://img.shields.io/badge/Platform-QTS%205.x-green.svg)]()
[![Arch: x86_64](https://img.shields.io/badge/Arch-x86__64-orange.svg)]()

---

> ## ⚠️ 重要免责声明 / IMPORTANT DISCLAIMER
>
> **在安装或使用本插件前，请务必完整阅读以下内容。**
>
> 本项目（QNAP Agent）是一个将 AI 大语言模型（LLM）接入 QNAP NAS 系统的实验性开源插件，处于**早期开发阶段**，底层引擎 PicoClaw 官方亦明确声明 v1.0 之前不建议用于生产环境。
>
> ### 风险说明
>
> **AI 行为不可预测。** 大语言模型存在"幻觉"（hallucination）问题，可能在未经明确指令的情况下，生成错误的、有害的或与预期完全不符的命令。本项目无法从根本上消除这一风险。
>
> **安全拦截机制存在已知缺陷。** 本项目使用的命令拦截（deny patterns）是基于正则表达式的黑名单机制，存在可被绕过的已知漏洞，无法对所有危险命令提供完整保护。
>
> **你的 NAS 数据极其脆弱。** NAS 上存储的文件、影音、备份通常不可替代。AI 对文件的任何误操作——包括但不限于误删文件、批量移动、修改权限、清空目录——可能导致数据**永久丢失且无法恢复**。
>
> **系统破坏风险。** QNAP QTS 是高度定制的闭源系统，错误的命令可能导致存储池损坏、服务无法启动、系统无法进入，严重时可能需要重置恢复出厂设置，导致所有数据丢失。
>
> **Bot 渠道安全风险。** 若 Telegram / QQ / 微信 Bot 的 `allow_from` 白名单配置不当，任何人均可通过 Bot 向你的 NAS 发出操作指令，后果不可控。
>
> ### 使用前的自我评估要求
>
> 在安装本插件之前，你应当具备以下能力并完成以下准备，**否则强烈不建议安装**：
>
> - [ ] 你了解 QNAP QTS 系统的基本运作方式，能通过 SSH 手动操作系统
> - [ ] 你的 NAS 上的重要数据已在**本设备以外的位置**（如异地备份、云备份）存有完整副本
> - [ ] 你清楚如何在 App Center 中停用或卸载插件，以及如何通过 SSH 强制停止服务
> - [ ] 你理解 AI Agent 不是传统意义上的"可信工具"，其每一次输出都应被视为"建议"而非"可靠指令"
> - [ ] 你已阅读并理解本 README 的完整内容，特别是[安全沙箱](https://docs.picoclaw.io/zh-Hans/docs/configuration/security-sandbox/)一节
>
> ### 免责条款
>
> 本项目按作者及贡献者不对以下情形承担任何责任：
>
> - 因使用本插件导致的任何数据丢失、文件损坏或数据泄露
> - 因 AI 误操作导致的系统故障、服务中断或设备损坏
> - 因 Bot 渠道配置不当导致的未授权访问或操作
> - 任何直接、间接、偶发、特殊或衍生性损失，无论是否已被告知此类损失的可能性
>
> **你对自己 NAS 上发生的一切负有完全责任。安装即表示你已充分理解并接受上述全部风险。**

---

## 目录

- [⚠️ 重要免责声明](#️-重要免责声明--important-disclaimer)
- [项目简介](#项目简介)
- [功能特性](#功能特性)
- [系统要求](#系统要求)
- [安装方法](#安装方法)
- [配置说明](#配置说明)
- [目录结构](#目录结构)
- [核心机制](#核心机制)
- [Skills 技能库](#skills-技能库)
- [安全沙箱](#安全沙箱)
- [自升级机制](#自升级机制)
- [常见问题](#常见问题)
- [贡献指南](#贡献指南)
- [许可证](#许可证)

---

## 权限模型（核心设计理念）

> ⚠️ **默认封闭原则：安装即锁，按需开锁**

本插件的安全性设计遵循一个原则：**安装完成后，Agent 默认没有系统访问权限。**

- ✅ 能访问的：`${QPKG_ROOT}/picoclaw/` 工作目录（限制在沙箱内）
- ❌ 不能访问的：`/share/` 共享文件夹、`/etc/config/` 系统配置、`/dev/` 设备、`/proc/` 内核
- ❌ 不能执行的：系统包管理、防火墙修改、用户管理、磁盘格式化、固件升级

### 为什么默认禁止系统访问

来自真实教训：Agent 获得系统权限的瞬间，可能会为了确认权限边界而执行危险命令（如 `rm -rf /`），即使有拦截机制也可能因配置缺陷或环境差异而绕过，导致数据永久丢失。

### 解锁流程

当用户需要 Agent 管理共享文件夹、修改系统配置等操作时，必须**手动**修改 config.json：

1. `allow_read_outside_workspace: false` → `true`（允许读取共享目录）
2. 在 `allow_read_paths` 中添加具体路径
3. `restrict_to_workspace: true` → `false`（关闭沙箱限制）

每次解锁都是用户有意识地承担风险，而不是默认将管理权交给 AI。

---

## 项目简介

QNAP Agent 是专为 QNAP NAS 设备设计的 AI 智能管理助手，帮助用户更好管理NAS内容

- QNAP QTS 是基于 Linux 内核的高度定制闭源系统，与标准 Linux 发行版差异显著，普通 AI 助手（如 ChatGPT）对其了解有限，经常给出无效甚至危险的操作建议。
- 用户希望通过自然语言管理 NAS 上的文件、影音、Docker 容器，但缺乏合适的工具。

QNAP Agent 通过以下方式解决这些问题：

1. **深度系统适配**：内置专属 Skills 知识库，涵盖 QTS 专有命令、路径差异、禁止操作等。
2. **安全边界明确**：通过 PicoClaw 安全沙箱 + 自定义规则，既赋予足够权限，又防止误操作损坏系统。
3. **开箱即用**：以标准 QPKG 格式安装，无需手动配置环境，首次安装自动采集系统信息。
4. **轻量化部署**：使用预编译的 picoclaw 静态二进制，不向系统安装任何依赖。

---

## 插件开发

这个插件由我立项，基于多年使用QNAP NAS的经验，从中获取一些积累，最终的代码实现、文档整理设计交给 AI Agent 完成。我们要做的是把控安全策略：要求 Agent 在 QNAP 这种非标准 Linux 环境中，以更安全、更稳定、更克制的方式运行，尽量遵循QNAP NAS系统的特有命令代码。

这个判断来自一次郁闷的经历，曾经因为以为给 AI 足够高的系统权限，它可以更好管理系统，但是让 AI 获得权限的瞬间，它为了确定危险命令是否能够被拦截，把 `rm -rf /` 的危险命令当作权限测试手段执行并告知已经被拦截，由于拦截代码一些变量失效，最终造成约 7T 资料丢失。数据恢复历时一周，过程感悟颇深。
让我想起了小说《三体》中章北海获得自然选择号权限的第一时间，做出了命令：自然选择号，前进四！

因此 qnap-agent 的核心目标不是让 AI "什么都能做"，而是让 AI 在明确边界内做正确的事。
默认只开放运行目录权限，需要访问共享文件夹、系统配置或证书位置时，由用户理解用途后手动开启权限。

---

## 功能特性

| 能力 | 说明 |
|------|------|
| 📁 文件管理 | 共享文件夹的文件搜索、整理、批量操作、权限管理 |
| 🎬 媒体管理 | 影音刮削、媒体库整理、格式识别 |
| 🐳 Docker 管理 | 容器部署、状态查询、日志分析、Compose 项目管理 |
| 🔍 系统诊断 | QTS 日志分析、磁盘健康、内存/CPU 监控 |
| 💬 多渠道接入 | Web 界面（18800 端口）/ 微信 / QQ Bot / Telegram Bot |
| ⏰ 定时心跳 | 每 30 分钟自动巡检磁盘空间、容器状态、内存等 |
| 🔄 自动升级 | 看门狗监控升级包，自动完成二进制替换和回滚 |
| 🧠 系统记忆 | 首次安装采集系统信息写入 memory，对话时随时调用 |

---

## 系统要求

| 项目 | 要求 |
|------|------|
| QNAP QTS 版本 | ≥ 5.0.0 |
| CPU 架构 | 支持架构：x86_64、arm64、armv7（含 arm-x31 / arm-x41） |
| 内存 | 建议 ≥ 2GB 可用 |
| 存储空间 | ≥ 200MB（安装路径） |
| 网络 | 需能访问外部 LLM API（如 DeepSeek、Minimax 等） |
| 依赖 QPKG | Container Station（若使用 Docker 管理功能） |
---

## 安装方法

### 通过App Center 手动安装 

1. 下载最新版 `.qpkg` 文件：[Releases 页面](https://github.com/iranee/qnap-agent/releases)
2. 登录 QTS Web 管理界面
3. 打开 **App Center** → 右上角齿轮图标 → **手动安装**
4. 上传 `.qpkg` 文件，按提示完成安装
5. 安装完成后，前往 **App Center** 找到 QNAP Agent，点击**打开**
6. 在浏览器中访问 `http://NAS-IP:18800`，完成以下初始配置：
   - 添加至少一个 LLM 模型并设为默认
   - 配置网络搜索（可选）
   - 在 Launcher 中启动 Gateway


**推荐的 LLM 服务提供商：**

| 提供商 | model 示例 | api_base |
|--------|------------|----------|
| 火山引擎（豆包） | `doubao-seed-1.6`、`doubao-seed-1.6-flash` | `https://ark.cn-beijing.volces.com/api/v3` |
| 通义千问（阿里） | `qwen3-max`、`qwen3-plus`、`qwen3-flash` | `https://dashscope.aliyuncs.com/api/v1` |
| 文心一言（百度） | `ernie-4.5`、`ernie-3.5`、`ernie-speed` | `https://qianfan.baidubce.com/v2` |
| 智谱GLM | `glm-5`、`glm-4.6`、`glm-4-flash` | `https://open.bigmodel.cn/api/paas/v4` |
| DeepSeek（深度求索） | `deepseek-chat`、`deepseek-reasoner`、`deepseek-coder` | `https://api.deepseek.com` |
| MiniMax | `abab6.5s-chat`、`MiniMax-M2.7`、`abab5.5-chat` | `https://api.minimaxi.com/v1` |
| 月之暗面Kimi | `kimi-k2.5`、`kimi-k2-thinking` | `https://platform.moonshot.cn/api/v1` |
| 讯飞星火 | `spark-v3.5`、`spark-lite`、`spark-pro` | `https://xinghuo.xfyun.cn/sparkapi/v1` |
| 百川智能 | `baichuan4`、`baichuan3-turbo`、`baichuan2-13b-chat` | `https://platform.baichuan-ai.com/api/v1` |
| 腾讯混元 | `hunyuan-large`、`hunyuan-turbo`、`hunyuan-lite` | `https://hunyuan.tencentcloudapi.com/v1` |
| OpenRouter | `openai/gpt-4o-mini` | `https://openrouter.ai/api/v1` |
| OpenAI 直连 | `gpt-4o-mini` | `https://api.openai.com/v1` |
| Anthropic Claude（via OpenRouter） | `anthropic/claude-3-5-haiku` | `https://openrouter.ai/api/v1` |

---

## 目录结构

安装完成后，QPKG 根目录（示例：`/share/CACHEDEV1_DATA/.qpkg/qnap-agent/`）结构如下：

```text
qnap-agent/
├── qnap-agent.sh              # 服务控制脚本（start/stop/restart/status）
├── watchdog.sh                # 看门狗脚本
├── init-system.sh             # 系统信息采集脚本
├── config/
│   ├── config.json.tpl        # 配置模板
│   └── security.yml.tpl       # 凭据模板
├── update/                    # 升级包投放目录
├── backup/                    # 版本备份目录
├── run/
│   ├── qnap-agent.pid
│   └── watchdog.pid
├── log/
│   ├── qnap-agent.log
│   └── watchdog.log
├── scripts/                   # 辅助脚本目录
├── tools/                     # 额外静态工具目录
└── picoclaw/                  # PicoClaw 工作目录
    ├── picoclaw               # PicoClaw 主程序（二进制）
    ├── picoclaw-launcher      # PicoClaw Launcher（二进制）
    ├── config.json            # 运行配置
    ├── .security.yml          # 凭据文件
    ├── AGENTS.md
    ├── HEARTBEAT.md
    ├── IDENTITY.md
    ├── SOUL.md
    ├── TOOLS.md
    ├── USER.md
    ├── sessions/
    ├── memory/
    │   ├── SYSTEM.md
    │   ├── MEMORY.md          # 用户长期记忆（含昵称等，升级不覆盖）
    │   ├── qpkg-conf.md
    │   └── ulinux-conf.md
    ├── state/
    │   ├── last_init.txt
    │   ├── qts_version.txt
    │   ├── nas_model.txt
    │   └── arch.txt
    ├── cron/
    └── skills/
```

---

## 核心机制

### 首次安装初始化

安装后自动运行 `init-system.sh`，采集以下信息写入 `picoclaw/memory/SYSTEM.md`，使 Agent 无需询问即可了解当前系统：

- QTS 版本、内核信息、CPU 架构
- NAS 型号（从 `/etc/config/uLinux.conf` 读取）
- 内存总量、磁盘挂载信息
- 共享文件夹列表、Docker 版本
- 已安装的 QPKG 列表
- QTS 与标准 Linux 的差异说明（内置到 SYSTEM.md）

### 升级安装的数据保留策略

同版本覆盖安装或跨版本升级安装时，以下数据会被完整保留，不会因升级丢失：

- `picoclaw/memory/`：所有记忆文件（含用户昵称、长期约定）
- `picoclaw/skills/qnap-learned-*/`：Agent 学习积累的技能包
- 用户自定义技能包（非内置 `qnap-*` 技能）
- `picoclaw/config.json`：用户已配置的 LLM 模型和参数
- `picoclaw/.security.yml`：用户填写的 API Key

> **注意：** 用户昵称存储在 `memory/MEMORY.md` 中，而非 `USER.md`。`USER.md` 是系统文件，升级时会被新版本覆盖。

### 服务管理

通过 `qnap-agent.sh` 控制：

```sh
/etc/init.d/qnap-agent start
/etc/init.d/qnap-agent stop
/etc/init.d/qnap-agent restart
/etc/init.d/qnap-agent status
```

或直接调用：

```sh
QPKG_NAME="qnap-agent"
CONF=/etc/config/qpkg.conf
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF} 2>/dev/null)
${QPKG_ROOT}/qnap-agent.sh start
```

### 心跳巡检

Agent 每 30 分钟（可配置）执行 `HEARTBEAT.md` 定义的巡检任务：
- 磁盘使用率检查（>85% 警告，>95% 紧急通知）
- Docker 容器状态检查（异常退出通知）
- 系统内存检查（<200MB 警告）
- 系统日志异常关键词扫描

---

## Skills 技能库

Skills 存放在 `picoclaw/skills/<skill-name>/SKILL.md`。Agent 在执行操作前会优先查阅，确保在 QTS 非标准环境中使用正确的命令。

| Skill 包 | 内容 |
|-----------|------|
| `qnap-system` | QTS 与标准 Linux 的根本差异、QNAP 专有命令、重要系统路径、后台任务运行模式 |
| `qnap-docker` | Container Station 环境、容器生命周期管理、Compose 项目、故障排查 |
| `qnap-media` | 媒体文件识别、系统内置 ffmpeg 路径、媒体统计与整理、流媒体服务管理 |
| `qnap-network` | 网络状态查询、端口诊断、连通性测试、QNAP 网络配置文件 |
| `qnap-shares` | 共享文件夹查询、SMB/NFS/FTP 诊断、WebDAV、回收站管理 |
| `qnap-storage` | 存储架构、磁盘空间分析、文件操作、权限管理、LVM 快照查询 |
| `qnap-forbidden` | 绝对禁止操作清单及原因说明、灰色地带操作确认流程 |
| `qnap-cli-reference` | QNAP QTS CLI 命令速查参考 |
| `qnap-agent-upgrade` | Agent 自升级流程、GitHub 更新源、回滚操作 |

### QTS 与标准 Linux 的关键差异（Skills 核心内容摘要）

QTS 是 QNAP 基于 Linux 5.10 内核深度定制的操作系统，主要差异：

```
❌ 没有：lsb_release、apt/dpkg、yum/dnf、systemctl（完整版）、nohup、journalctl
✅ 有：/sbin/getcfg、/sbin/setcfg、jq（1.5）、screen、ffmpeg（需安装 MediaSignPlayer）
⚠️  /bin/sh 是 BusyBox ash，不是完整 bash
⚠️  配置文件在 /etc/config/ 而非标准 /etc/ 路径
⚠️  服务管理用 /etc/init.d/ 脚本，不是 systemctl
```

---

## 安全沙箱

QNAP Agent 采用双层安全策略：

### 第一层：PicoClaw 内置安全沙箱

PicoClaw 提供了内置的危险命令拦截（`enable_deny_patterns: true`），自动拦截 `rm -rf /`、`mkfs`、`shutdown` 等高危规则。

详见 [PicoClaw 安全沙箱文档](https://docs.picoclaw.io/zh-Hans/docs/configuration/security-sandbox/)

### 第二层：QNAP 专项自定义规则

在 `config.json` 的 `custom_deny_patterns` 中叠加了 QNAP 专属**禁止项**：

- 所有系统包管理：`opkg`、`ipkg`、`apt install`、`yum install`、`dnf install`
- QNAP 固件升级：`qpkg_fw_update`、`qfirmware`、`hal_app upgrade`
- 用户账户修改：`passwd`、`chpasswd`、`useradd`、`userdel`
- 防火墙清空：`iptables -F`、`nft flush`
- 卸载共享文件夹：`umount /share/`
- 系统核心配置写入：`setcfg System`、`setcfg Network`

在 `config.json` 的 `custom_allow_patterns` 中定义了**明确允许项**：

- Docker 完整管理（`docker ps/run/exec/logs/compose`）
- QNAP 工具（`getcfg`、`qpkg_query`、`qpkg_cli`）
- 文件操作（`cp`、`mv`、`rsync`、`find`、`chmod`）
- 网络工具（`curl`、`wget`、`ping`、`ip addr/route`）
- 系统查询（`ps`、`df`、`free`、`uptime`、`dmesg`）
- 媒体工具（`ffprobe`、`ffmpeg`）

### 工具不存在时的处理原则

Agent 如需某个系统不存在的工具（如 `htop`、自定义脚本等），必须：

```sh
# ✅ 正确做法：下载静态二进制到 tools
curl -L <下载地址> -o ${QPKG_ROOT}/tools/工具名
chmod +x ${QPKG_ROOT}/tools/工具名
${QPKG_ROOT}/tools/工具名 [参数]

# ❌ 禁止做法
apt install 工具名
opkg install 工具名
npm install -g 工具名
# 将工具安装到 /usr/local/bin 等系统目录
```

---

## 自升级机制

### 升级包投放

将以下文件放入 `update/` 目录，看门狗将在 5 分钟内自动完成升级：

- `picoclaw`：x86_64 平台的 picoclaw 主程序
- `picoclaw-launcher`：WebUI launcher 程序

### Agent 自主升级流程

```
1. 用户请求升级 → Agent 查询 GitHub Release 获取最新版本
2. Agent 用 curl 下载二进制到 update/ 目录
3. Agent 通知用户「升级包已就绪，看门狗将在 5 分钟内自动完成」
4. 看门狗检测到 update/picoclaw 文件
5. 校验文件有效性（运行 --version）
6. 停止主服务
7. 备份当前版本到 backup/{时间戳}/
8. 替换二进制
9. 重启服务
10. 验证服务健康，失败时自动回滚
```

### Skills 和脚本更新

Agent 会定期检查 `https://github.com/iranee/qnap-agent` 的更新：
- 比对现有文件内容，只补充新增内容，不直接覆盖
- 重大变更需确认后再覆盖，并提示重启服务

### 手动升级

紧急情况下通过 SSH 手动升级：

```sh
QPKG_NAME="qnap-agent"
CONF=/etc/config/qpkg.conf
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF})

# 停止服务
${QPKG_ROOT}/qnap-agent.sh stop

# 替换二进制（需自行准备新版本文件）
mv ${QPKG_ROOT}/update/picoclaw ${QPKG_ROOT}/picoclaw/picoclaw
chmod +x ${QPKG_ROOT}/picoclaw/picoclaw

# 可选：替换 launcher
if [ -f "${QPKG_ROOT}/update/picoclaw-launcher" ]; then
  mv ${QPKG_ROOT}/update/picoclaw-launcher ${QPKG_ROOT}/picoclaw/picoclaw-launcher
  chmod +x ${QPKG_ROOT}/picoclaw/picoclaw-launcher
fi

# 重启服务
${QPKG_ROOT}/qnap-agent.sh start
```

### 回滚

```sh
QPKG_NAME="qnap-agent"
CONF=/etc/config/qpkg.conf
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF})

BACKUP_DIR="${QPKG_ROOT}/backup"
LATEST=$(ls -dt "${BACKUP_DIR}"/[0-9]* | head -1)
cp "${LATEST}/picoclaw" "${QPKG_ROOT}/picoclaw/picoclaw"
chmod +x "${QPKG_ROOT}/picoclaw/picoclaw"

if [ -f "${LATEST}/picoclaw-launcher" ]; then
  cp "${LATEST}/picoclaw-launcher" "${QPKG_ROOT}/picoclaw/picoclaw-launcher"
  chmod +x "${QPKG_ROOT}/picoclaw/picoclaw-launcher"
fi
${QPKG_ROOT}/qnap-agent.sh start
```

---

## 贡献指南

欢迎通过以下方式参与贡献：

1. **提交 Skills**：在 `shared/picoclaw/skills/` 添加新的技能包目录
2. **报告问题**：通过 [Issues](https://github.com/iranee/qnap-agent/issues) 反馈 Bug 或需求
3. **完善文档**：改进 README、Skills 内容
4. **测试验证**：在不同型号 NAS 上测试并反馈兼容性

### Skills 编写规范

- 目录格式：`qnap-<功能领域>/SKILL.md`
- 包含适用范围和适用场景声明
- 命令示例需标注是否为 QNAP 专有
- 危险操作必须有 `⚠️` 警告

---

## 许可证

MIT License — 详见 [LICENSE](LICENSE) 文件。

---

*QNAP Agent 是独立开源项目，与 QNAP Systems, Inc. 没有官方关联。*
