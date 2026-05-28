---
name: qnap-agent-upgrade
description: qnap-agent 二进制、技能和脚本更新流程，以及升级回滚规范。
---

# Agent 自升级操作规程

> 适用范围：qnap-agent 的二进制升级、技能更新、脚本更新和回滚
> 适用场景：用户要求升级 agent，或检查项目是否有新内容

---

## 一、升级类型

| 类型 | 内容 | 执行方式 |
|---|---|---|
| 二进制升级 | `picoclaw` / `picoclaw-launcher` | 下载到 `${QPKG_ROOT}/update/`，由 `watchdog.sh` 处理 |
| 内容更新 | `skills/`、文档、脚本 | 比对后更新 |

当前真实路径：

- 服务脚本：`${QPKG_ROOT}/qnap-agent.sh`
- 初始化脚本：`${QPKG_ROOT}/init-system.sh`
- 看门狗脚本：`${QPKG_ROOT}/watchdog.sh`
- 主程序：`${QPKG_ROOT}/workspace/workspace`
- Launcher：`${QPKG_ROOT}/workspace/picoclaw-launcher`
- 升级目录：`${QPKG_ROOT}/update`
- 备份目录：`${QPKG_ROOT}/backup`

---

## 二、picoclaw 二进制升级

```sh
QPKG_NAME="qnap-agent"
CONF=/etc/config/qpkg.conf
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF} 2>/dev/null)
UPDATE_DIR="${QPKG_ROOT}/update"
ARCH=$(uname -m)

LATEST=$(curl -s https://api.github.com/repos/sipeed/picoclaw/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4)

CURRENT=$( "${QPKG_ROOT}/workspace/workspace" --version 2>/dev/null | head -1)

DOWNLOAD_URL="https://github.com/sipeed/picoclaw/releases/download/${LATEST}/picoclaw-linux-${ARCH}"
curl -L "${DOWNLOAD_URL}" -o "${UPDATE_DIR}/picoclaw"
chmod +x "${UPDATE_DIR}/picoclaw"

if "${UPDATE_DIR}/picoclaw" --version > /dev/null 2>&1; then
    echo "升级包已就绪，看门狗会自动完成升级。"
fi
```

原则：

- 不要直接替换正在运行的二进制。
- 二进制放到 `update/` 后，让 `watchdog.sh` 完成后续处理。

---

## 三、技能更新

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

## 四、脚本更新

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

## 五、看门狗失效时的手动升级

```sh
QPKG_NAME="qnap-agent"
CONF=/etc/config/qpkg.conf
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF} 2>/dev/null)

${QPKG_ROOT}/qnap-agent.sh stop
mv ${QPKG_ROOT}/update/workspace ${QPKG_ROOT}/workspace/workspace
chmod +x ${QPKG_ROOT}/workspace/workspace
${QPKG_ROOT}/qnap-agent.sh start
```

如果还带有 launcher：

```sh
mv ${QPKG_ROOT}/update/picoclaw-launcher ${QPKG_ROOT}/workspace/picoclaw-launcher
chmod +x ${QPKG_ROOT}/workspace/picoclaw-launcher
```

---

## 六、回滚

```sh
BACKUP_DIR="${QPKG_ROOT}/backup"
LATEST_BACKUP=$(ls -dt "${BACKUP_DIR}"/[0-9]* | head -1)

cp "${LATEST_BACKUP}/workspace" "${QPKG_ROOT}/workspace/workspace"
chmod +x "${QPKG_ROOT}/workspace/workspace"

if [ -f "${LATEST_BACKUP}/picoclaw-launcher" ]; then
    cp "${LATEST_BACKUP}/picoclaw-launcher" "${QPKG_ROOT}/workspace/picoclaw-launcher"
    chmod +x "${QPKG_ROOT}/workspace/picoclaw-launcher"
fi

${QPKG_ROOT}/qnap-agent.sh start
```

---

## 七、版本与日志检查

```sh
${QPKG_ROOT}/workspace/workspace --version
tail -50 ${QPKG_ROOT}/log/watchdog.log
tail -50 ${QPKG_ROOT}/log/qnap-agent.log
cat /var/log/qnap-agent-init.log
```

---

## 八、安全要求

- 升级前先确认当前版本和目标版本。
- 更新技能或脚本时先备份。
- 二进制替换优先走看门狗。
- 回滚前先确认最近备份目录内容。
