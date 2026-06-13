---
name: qnap-agent-upgrade
description: qnap-agent 二进制、技能和脚本更新流程，工作空间备份，以及升级回滚规范。
---

# Agent 自升级操作规程

> 适用范围：qnap-agent 的二进制升级、技能更新、脚本更新和回滚
> 适用场景：用户要求升级 agent，或检查项目是否有新内容

---

## 一、升级类型

| 类型 | 内容 | 执行方式 |
|---|---|---|
| 插件包升级 | qnap-agent 整体（含二进制、技能、脚本） | 下载 `.qpkg` 安装包，通过 App Center 手动安装 |
| 内容热更新 | 单独的技能文件（`.md`）或工具脚本（`.sh`） | 拉取最新文件，比对后增量合并 |
| 二进制升级 | `picoclaw` / `picoclaw-launcher` | 下载到 `${QPKG_ROOT}/update/`，由 `watchdog.sh` 处理 |

---

## 二、更新来源与操作流程

### 2.1 qnap-agent 插件更新

**项目地址：** https://github.com/iranee/qnap-agent/releases

**情况 A：有新安装包（.qpkg）**

1. **先备份**：建议用户将 `workspace/memory/` 和 `workspace/config.json` 备份到安装目录以外的位置（如共享文件夹），防止升级异常导致记忆丢失
2. 告知用户从上述地址下载最新 `.qpkg` 文件
3. 用户通过 QTS App Center → 手动安装 → 上传 `.qpkg` 完成升级
4. 安装过程会自动备份用户数据、更新所有文件、恢复用户数据

**情况 B：无新安装包，仅有单独的技能文件或脚本更新**

1. 从项目仓库拉取最新的 `.md` 或 `.sh` 文件
2. 与当前使用的文件做 **逐行比对**（`diff`）
3. 将更新/修正内容 **增量合并** 到现有文件：
   - **不要整体覆盖**，防止丢失使用期间 Agent 自行沉淀的内容（如 `qnap-learned-*` 技能、用户修改的 MEMORY.md 等）
   - 仅修改变动的部分，保留本地新增内容
4. 涉及脚本更新时提醒用户重启服务：`${QPKG_ROOT}/qnap-agent.sh restart`

### 2.2 picoclaw 二进制更新

**项目地址：** https://github.com/sipeed/picoclaw/releases

1. 根据 NAS 架构（`uname -m`）下载对应的二进制文件
2. 放入 `${QPKG_ROOT}/update/` 目录
3. `watchdog.sh` 每 5 分钟自动扫描，发现后执行：停服务 → 备份 → 替换 → 重启
4. 也可手动触发：`sh ${QPKG_ROOT}/watchdog.sh upgrade`

---

## 三、picoclaw 二进制升级（手动）

```sh
QPKG_NAME="qnap-agent"
CONF=/etc/config/qpkg.conf
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF} 2>/dev/null)
UPDATE_DIR="${QPKG_ROOT}/update"
ARCH=$(uname -m)

LATEST=$(curl -s https://api.github.com/repos/sipeed/picoclaw/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4)

CURRENT=$( "${QPKG_ROOT}/picoclaw" version 2>/dev/null | head -1)

DOWNLOAD_URL="https://github.com/sipeed/picoclaw/releases/download/${LATEST}/picoclaw-linux-${ARCH}"
curl -L "${DOWNLOAD_URL}" -o "${UPDATE_DIR}/picoclaw"
chmod +x "${UPDATE_DIR}/picoclaw"

if "${UPDATE_DIR}/picoclaw" version > /dev/null 2>&1; then
    echo "升级包已就绪，看门狗会自动完成升级。"
fi
```

原则：

- 不要直接替换正在运行的二进制。
- 二进制放到 `update/` 后，让 `watchdog.sh` 完成后续处理。

---

## 四、技能更新

技能目录当前是：

```text
${QPKG_ROOT}/workspace/skills/
```

更新原则：

- 新文件直接加入。
- 已存在文件先比对，再确认覆盖。
- 变动较大时先展示差异，再更新。
- 学习型技能 `qnap-learned-*` 保留用户本地内容。

---

## 五、脚本更新

根目录脚本当前是：

- `${QPKG_ROOT}/qnap-agent.sh`
- `${QPKG_ROOT}/init-system.sh`
- `${QPKG_ROOT}/watchdog.sh`

更新脚本时：

- 先备份旧文件
- 再替换新文件
- 保持执行权限
- 涉及服务行为变化时提醒用户重启服务

---

## 六、看门狗失效时的手动升级

```sh
QPKG_NAME="qnap-agent"
CONF=/etc/config/qpkg.conf
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF} 2>/dev/null)

${QPKG_ROOT}/qnap-agent.sh stop
mv ${QPKG_ROOT}/update/picoclaw ${QPKG_ROOT}/picoclaw
chmod +x ${QPKG_ROOT}/picoclaw
${QPKG_ROOT}/qnap-agent.sh start
```

如果还带有 launcher：

```sh
mv ${QPKG_ROOT}/update/picoclaw-launcher ${QPKG_ROOT}/picoclaw-launcher
chmod +x ${QPKG_ROOT}/picoclaw-launcher
```

---

## 七、回滚

```sh
BACKUP_DIR="${QPKG_ROOT}/backup"

cp "${BACKUP_DIR}/picoclaw.bak" "${QPKG_ROOT}/picoclaw"
chmod +x "${QPKG_ROOT}/picoclaw"

if [ -f "${BACKUP_DIR}/picoclaw-launcher.bak" ]; then
    cp "${BACKUP_DIR}/picoclaw-launcher.bak" "${QPKG_ROOT}/picoclaw-launcher"
    chmod +x "${QPKG_ROOT}/picoclaw-launcher"
fi

${QPKG_ROOT}/qnap-agent.sh start
```

---

## 八、版本与日志检查

```sh
${QPKG_ROOT}/picoclaw version
tail -50 ${QPKG_ROOT}/log/watchdog.log
tail -50 ${QPKG_ROOT}/log/qnap-agent.log
cat ${QPKG_ROOT}/log/qnap-agent-init.log
```

---

## 九、工作空间定期备份

### 9.1 为什么需要备份

workspace 目录包含 agent 的全部运行时数据：config.json（网关核心配置）、memory/（对话记忆）、skills/（技能知识）、state/（系统状态）。插件升级、磁盘故障、误操作都可能导致数据丢失。**建议用户在 QNAP 共享文件夹中设置一个专用备份目录，定期保存完整 workspace 快照。**

### 9.2 设置备份目录

建议用户在 QNAP 共享文件夹中创建一个专用目录，例如：

```text
/share/<共享文件夹名>/qnap-agent-backup/
```

> 选择用户自己可以读写的位置（如 Public、home 等），确保升级或重装插件时不会被覆盖。

### 9.3 备份内容

| 备份目标 | 路径 | 重要程度 |
|---------|------|---------|
| 网关配置 | `workspace/config.json` | 必须 |
| 对话记忆 | `workspace/memory/` | 必须 |
| 技能知识 | `workspace/skills/` | 建议 |
| 系统状态 | `workspace/state/` | 可选 |

### 9.4 备份脚本

Agent 可在用户确认后将以下脚本保存到 `scripts/workspace-backup.sh`：

```sh
#!/bin/sh
# workspace 定期备份脚本
# 用法: sh scripts/workspace-backup.sh [备份目标目录]

QPKG_NAME="qnap-agent"
CONF=/etc/config/qpkg.conf
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF} 2>/dev/null)
WORKSPACE="${QPKG_ROOT}/workspace"

# 备份目标目录（参数1，或使用默认路径）
BACKUP_DIR="${1:-/share/Public/qnap-agent-backup}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/workspace-backup-${TIMESTAMP}.tar.gz"

# 检查源目录
if [ ! -d "${WORKSPACE}" ]; then
    echo "错误: workspace 目录不存在: ${WORKSPACE}"
    exit 1
fi

# 创建备份目录
mkdir -p "${BACKUP_DIR}"

# 打包备份（排除不需要的临时文件）
tar czf "${BACKUP_FILE}" \
    --exclude='*.tmp' \
    --exclude='__pycache__' \
    -C "$(dirname ${WORKSPACE})" \
    "$(basename ${WORKSPACE})"

if [ $? -eq 0 ]; then
    SIZE=$(du -sh "${BACKUP_FILE}" | cut -f1)
    echo "备份完成: ${BACKUP_FILE} (${SIZE})"
else
    echo "备份失败"
    exit 1
fi

# 自动清理：仅保留最近 5 份备份
cd "${BACKUP_DIR}" && ls -1t workspace-backup-*.tar.gz | tail -n +6 | xargs rm -f 2>/dev/null
echo "当前备份数量: $(ls -1 workspace-backup-*.tar.gz 2>/dev/null | wc -l)"
```

### 9.5 定期执行

用户可通过 QTS 任务计划或 picoclaw cron 设置定期备份，例如每天凌晨 3 点：

```sh
# QTS crontab 方式
echo "0 3 * * * /bin/sh ${QPKG_ROOT}/workspace/scripts/workspace-backup.sh /share/Public/qnap-agent-backup >> ${QPKG_ROOT}/log/backup.log 2>&1" >> /etc/config/crontab
/etc/init.d/crond.sh restart
```

### 9.6 恢复备份

```sh
# 1. 先停止服务
${QPKG_ROOT}/qnap-agent.sh stop

# 2. 备份当前 workspace（以防恢复失败）
cp -r ${QPKG_ROOT}/workspace ${QPKG_ROOT}/workspace.pre-restore

# 3. 解压恢复（覆盖）
tar xzf /share/Public/qnap-agent-backup/workspace-backup-XXXXXXXX_XXXXXX.tar.gz \
    -C ${QPKG_ROOT}/

# 4. 重启服务
${QPKG_ROOT}/qnap-agent.sh start
```

### 9.7 升级前备份提醒

在执行任何升级操作（插件包升级、二进制升级、技能更新）之前，**必须先提醒用户运行一次手动备份**：

> 建议先运行 `sh scripts/workspace-backup.sh` 备份当前工作空间，再进行升级操作。

---

## 十、安全要求

- 升级前先确认当前版本和目标版本。
- 更新技能或脚本时先备份。
- 二进制替换优先走看门狗。
- 回滚前先确认最近备份目录内容。

当前真实路径：

- 服务脚本：`${QPKG_ROOT}/qnap-agent.sh`
- 初始化脚本：`${QPKG_ROOT}/init-system.sh`
- 看门狗脚本：`${QPKG_ROOT}/watchdog.sh`
- 主程序：`${QPKG_ROOT}/picoclaw`
- Launcher：`${QPKG_ROOT}/picoclaw-launcher`
- 升级目录：`${QPKG_ROOT}/update`
- 备份目录：`${QPKG_ROOT}/backup`
- 工作空间备份：`/share/Public/qnap-agent-backup`（用户自定义）
---
name: qnap-agent-upgrade
description: qnap-agent 二进制、技能和脚本更新流程，工作空间备份，以及升级回滚规范。
---




## 十一、工具调用失败回退策略（三问原则）

> 工具调用失败时，不盲目重试同类方案，执行系统化"三问"评估后再决定下一步。

### 触发条件

以下任一情况发生时立即进入三问流程：

- 工具调用被安全规则拦截
- 工具调用返回错误（命令不存在、权限不足、执行失败）
- 连续两次在同一方向上失败
- 用户指出"你一直在试同一个方向"

### 三问流程

**第一问：B 计划是什么？**
执行前必须明确备选方案和执行路径。没有 B 计划则直接告知用户，停止尝试。

**第二问：失败原因与本质区别？**
每次失败后必须说明：上次失败原因是什么？这次有什么本质不同？如果本质相同（如只是换了个包管理器），禁止继续。

**第三问：继续尝试 vs 告知用户？**
同一方向失败 2 次后必须评估：有明确新路径则继续，否则告知用户限制并提供替代方案，让用户自主决策。

### 决策规则

| 规则 | 说明 |
|------|------|
| 无 B 计划，不尝试 | 没有备选方案就告知用户 |
| 本质相同，不重试 | 换了个名字不算新方案 |
| 两次失败，必评估 | 同一方向失败 2 次必须评估价值 |
| 失败后，必回复 | 每次失败必须在回复中说明原因 |

---

## 十二、重启后上下文恢复

> 重启不是断点，而是延续。Agent 执行 restart 后必须恢复上下文连续性。

### 临时记忆文件路径

使用 workspace 相对路径，agent 可直接读写：

```
workspace/tmp/restart_context.json
```

对应完整路径（用于 shell 脚本）：

```sh
QPKG_ROOT=$(/sbin/getcfg qnap-agent Install_Path -f /etc/config/qpkg.conf 2>/dev/null)
CONTEXT_FILE="${QPKG_ROOT}/workspace/tmp/restart_context.json"
mkdir -p "${QPKG_ROOT}/workspace/tmp"
```

### 重启前：保存上下文快照

每次准备执行 restart 前，先写入：

```json
{
  "timestamp": "2026-06-10 14:00:00",
  "trigger": "触发原因描述",
  "last_command": "qnap-agent.sh restart",
  "pending_tasks": [
    "重启后需要继续的任务1",
    "重启后需要继续的任务2"
  ],
  "conversation_context": "当前对话的简要上下文"
}
```

必填字段：`timestamp`、`trigger`、`last_command`、`pending_tasks`、`conversation_context`

### 重启后：立即恢复

服务恢复后第一时间：

```sh
CONTEXT_FILE="${QPKG_ROOT}/workspace/tmp/restart_context.json"
if [ -f "${CONTEXT_FILE}" ]; then
    cat "${CONTEXT_FILE}"
    rm "${CONTEXT_FILE}"
fi
```

恢复步骤：读取文件 → 向用户报告"服务已重启，我刚才在执行 [xxx]，现在继续..." → 执行 pending_tasks → 清理文件

### 注意事项

- `workspace/tmp/` 在系统重启后会清空（与 `/tmp` 不同，这里是磁盘路径，但语义上用于临时数据）
- 不要在 pending_tasks 中包含破坏性操作（删除、格式化等）
- 上下文文件是纯 JSON，便于程序化解析
