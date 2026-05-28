---
name: qnap-learning
description: 将新发现的 QNAP/QTS 知识整理成可复用、可分享的本地技能包。
---

# QNAP 学习型技能整理规范

> 适用范围：qnap-agent 在使用过程中学到的新知识沉淀
> 适用场景：把排障经验、命令套路、路径规则、注意事项整理成长期可复用的技能包

---

## 一、什么时候要创建学习型技能

以下情况适合沉淀为学习型技能：

- 新发现的 QTS 命令替代方式
- 某类故障的稳定排查流程
- 某种路径规则或部署约定
- 某个 QNAP 组件的使用方法
- 某种 Docker、共享、媒体、网络问题的固定处理套路

以下情况不用单独建技能：

- 一次性的临时任务记录
- 带有明显设备私有信息的内容
- 代码里直接能看出的路径或实现细节

---

## 二、技能包目录

学习型技能统一放在：

```text
workspace/skills/qnap-learned-<topic>/
```

目录结构：

```text
workspace/skills/qnap-learned-<topic>/
+-- SKILL.md
+-- .skill-origin.json
```

---

## 三、命名规则

- 统一使用小写字母、数字和连字符
- 一次只聚焦一个主题
- 名称要能看出用途

示例：

- `qnap-learned-docker-log-troubleshooting`
- `qnap-learned-smb-access-check`
- `qnap-learned-media-probe-workflow`

---

## 四、隐私处理规则

保存前必须去掉这些信息：

- NAS 序列号
- 主机名
- 公网 IP、内网 IP
- 域名
- 用户名
- Token
- API Key
- 带个人含义的共享目录名
- 具体媒体文件名

替换占位符建议：

- `<nas-host>`
- `<share-name>`
- `<domain>`
- `<container-name>`
- `<qpkg-root>`

---

## 五、SKILL.md 应包含什么

建议结构：

1. 适用范围
2. 触发场景
3. 背景说明
4. 处理步骤
5. 命令示例
6. 风险和确认要求

示例模板：

```markdown
---
name: qnap-learned-<topic>
description: <一句话描述用途>
---

# <标题>

> 适用范围：<范围>
> 适用场景：<场景>

## 一、背景

说明为什么需要这份技能。

## 二、处理步骤

1. 先做什么
2. 再做什么
3. 最后确认什么

## 三、命令示例

```sh
<命令示例>
```

## 四、安全要求

- 哪些操作前要确认
- 哪些路径不能直接写死
```

---

## 六、.skill-origin.json 模板

```json
{
  "version": 1,
  "origin_kind": "qnap_agent_learned",
  "registry": "qnap-agent-local-learning",
  "slug": "qnap-learned-<topic>",
  "registry_url": "local://qnap-agent/learned/qnap-learned-<topic>",
  "installed_version": "1.0.0",
  "installed_at": 0
}
```

---

## 七、更新规则

- 已有同主题技能时，优先更新，不重复建目录
- 内容变多时按主题继续细分
- 所有路径优先写成基于 `${QPKG_ROOT}` 的真实路径
- 涉及第三方 QPKG 应用时，先写明 `qpkg.conf` 动态解析方式和调阅步骤
- 第三方应用目录按只读处理，禁止私自改造

第三方 QPKG 动态路径示例：

```sh
QPKG_NAME="container-station"
QPKG_DIR=$(/bin/sed -nr ":s /^\[$QPKG_NAME\]/ b o; n; b s; :o n; /^\[/ q; /^Install_Path[ ]*=/ {s/.*=[ ]*// p; q;} b o;" "/etc/config/qpkg.conf")
```

当前 qnap-agent 路径基准：

```text
${QPKG_ROOT}/qnap-agent.sh
${QPKG_ROOT}/init-system.sh
${QPKG_ROOT}/watchdog.sh
${QPKG_ROOT}/workspace/
${QPKG_ROOT}/update/
${QPKG_ROOT}/backup/
${QPKG_ROOT}/run/
${QPKG_ROOT}/log/
${QPKG_ROOT}/tools/
```

---

## 八、质量要求

- 中文表达清楚
- 重点写完整
- 命令可直接参考
- 不要写空泛总结
- 不要保留过时路径
