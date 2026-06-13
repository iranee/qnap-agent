---
name: qnap-openlist
description: >
  OpenList 文件管理技能。通过 HTTP API 操作部署在 QNAP 或外部服务器上的
  OpenList 实例，实现目录浏览、文件搜索、获取直链、上传、重命名、
  移动、复制、删除、分享管理和搜索索引维护。适用于用户提到 OpenList 网盘、
  云盘管理、远程文件浏览或需要操作网络存储内容的场景。
---

# OpenList 文件管理技能

通过 `scripts/openlist.sh` 调用 OpenList HTTP API，
实现对 OpenList 实例的完整文件管理能力。

---

## 目录结构

```text
workspace/skills/qnap-openlist/
├── SKILL.md              ← 本文件（Agent 运行时读取）
├── config.json           ← 凭据文件（首次 login 后自动生成，勿手动编辑）
└── scripts/
    └── openlist.sh       ← 核心脚本，所有命令的唯一入口
```

---

## 运行环境要求

- **Shell**：QTS 内置 BusyBox ash（`/bin/sh`），无需 Python
- **工具**：`curl`（系统内置）、`jq`（已下载到 `workspace/tools/jq`）
- **可访问的 OpenList 实例**（本机或远程均可）

---

## 配置

### 方式 A — 自动登录（推荐）

首次使用时执行一次 login，凭据自动保存至 `config.json`：

```bash
sh skills/qnap-openlist/scripts/openlist.sh login \
    --url http://192.168.1.100:5244 \
    --username admin \
    --password yourpassword
```

后续所有命令无需再传 `--url` 和 `--token`，脚本自动读取 `config.json`。

### 方式 B — 每次传参

不依赖配置文件，每次调用时显式传入：

```bash
sh skills/qnap-openlist/scripts/openlist.sh list \
    --url http://192.168.1.100:5244 \
    --token <token> \
    --path /
```

---

## 使用原则

1. **先读后写**：所有修改操作（rename、move、copy、remove）前，先用 `list` 或 `get` 确认目标路径存在且正确。
2. **禁止猜测路径**：不确定路径时先 `list` 逐层浏览，绝对不能用模糊路径直接执行写操作。
3. **remove 需要 `--path`**：`--names` 为逗号分隔的名称列表，`--path` 指定所在目录。
4. **搜索失败勿急于重建索引**：按顺序排查（见"搜索失败处理流程"），`index-build` 是最后手段。
5. **机器读取结果用 `--json`**：自动化场景统一加 `--json`，人工浏览时不加。
6. **QNAP 系统目录禁止操作**：`/etc`、`/usr`、`/bin` 等系统目录不在 OpenList 挂载范围内，无需担心，但仍需注意不要操作 NAS 共享根目录本身。

---

## 命令速查

运行方式：`sh skills/qnap-openlist/scripts/openlist.sh <command> [options]`

### 文件操作

| 命令       | 功能           | 必需参数                      |
|:-----------|:---------------|:------------------------------|
| `login`    | 登录并保存凭据 | `--url --username --password` |
| `list`     | 列出目录内容   | `--path`                      |
| `dirs`     | 仅列出目录     | `--path`                      |
| `get`      | 获取文件/目录元信息 | `--path`                 |
| `search`   | 搜索文件       | `--keyword`                   |
| `mkdir`    | 新建目录       | `--path`                      |
| `rename`   | 重命名         | `--path --new-name`           |
| `move`     | 移动文件或目录 | `--path --dst`                |
| `recursive-move` | 递归移动（含子目录） | `--path --dst`      |
| `copy`     | 复制文件或目录 | `--path --dst`                |
| `remove`   | 删除文件或目录 | `--names --path`（名称列表 + 所在目录）|
| `remove-empty-directory` | 清空空目录 | `--path`         |
| `link`     | 获取下载直链   | `--path`                      |
| `upload`   | 上传本地文件   | `--path --file`               |
| `add-offline-download` | 添加离线下载任务 | `--path --urls` |

### 批量操作

| 命令           | 功能           | 必需参数                                  |
|:---------------|:---------------|:------------------------------------------|
| `batch-rename` | 批量重命名     | `--src-dir --rename-pairs`                |
| `regex-rename` | 正则替换重命名 | `--src-dir --src-regex --dst-regex`       |

### 分享管理

| 命令             | 功能         | 必需参数    |
|:-----------------|:-------------|:------------|
| `share-list`     | 列出所有分享 | 无          |
| `share-create`   | 创建分享链接 | `--files`   |
| `share-get`      | 获取分享详情 | `--id`      |
| `share-update`   | 更新分享设置 | `--id`      |
| `share-delete`   | 删除分享     | `--id`      |

### 索引管理

| 命令               | 功能                         |
|:-------------------|:-----------------------------|
| `index-progress`   | 查看当前索引进度             |
| `index-update`     | 增量更新指定目录的索引       |
| `index-clear`      | 清除全部索引数据             |
| `index-build`      | 全量重建索引（耗时，慎用）   |

### 设置管理（管理员）

| 命令           | 功能         | 必需参数        |
|:---------------|:-------------|:----------------|
| `settings-list`| 列出所有设置 | 无              |
| `settings-get` | 获取单个设置 | `--key`         |
| `settings-save`| 保存设置     | `--key --value` |
| `settings-delete`| 删除设置   | `--key`         |

### 存储管理（管理员）

| 命令             | 功能         | 必需参数          |
|:-----------------|:-------------|:------------------|
| `storage-list`   | 列出存储挂载 | 无                |
| `storage-get`    | 获取存储详情 | `--id`            |
| `storage-create` | 创建存储挂载 | `--driver --mount-path` |
| `storage-update` | 更新存储配置 | `--id --config`   |
| `storage-delete` | 删除存储挂载 | `--id`            |
| `storage-enable` | 启用存储     | `--id`            |
| `storage-disable`| 禁用存储     | `--id`            |
| `storage-load-all`| 重载全部存储| 无                |

### 驱动信息（管理员）

| 命令          | 功能         |
|:--------------|:-------------|
| `driver-list` | 列出所有驱动 |
| `driver-names`| 列出驱动名称 |

---

## 关键参数说明

| 命令 | 补充参数 | 说明 |
|:-----|:---------|:-----|
| `list` | `--page` `--per-page` `--refresh` | `--refresh` 强制刷新目录缓存 |
| `search` | `--path` `--page` `--per-page` `--max-depth` `--no-api` | 默认先走 API 搜索，失败自动降级为目录遍历；`--max-depth` 控制遍历深度（默认 6） |
| `move` / `copy` | `--new-name` | 可选，同时重命名；`--dst` 为目标目录路径 |
| `remove` | `--names --path` | `--names` 为逗号分隔的名称列表，`--path` 为所在目录 |
| `upload` | `--replace` `--async-upload` | `--replace` 覆盖同名文件；`--async-upload` 转为后台任务上传 |
| `share-create` | `--files` `--password` `--expire-hours` | `--files` 为逗号分隔路径列表；`--expire-hours` 设置有效期（小时） |
| `index-update` | `--paths` | 逗号分隔的目录路径，为空则更新全部 |
| `index-build` | `--async` | 加 `--async` 以后台异步方式重建，避免请求超时 |
| 全局 | `--json` `--quiet` | `--json` 输出机器可读 JSON；`--quiet` 只输出核心字段 |

---

## 决策流程

### 目录浏览

```text
用户要查看某个路径的内容
    ↓
list --path <dir> --json
    ↓ 如果路径不确定
list 从父级目录开始，逐层定位
    ↓ 只需确认某对象是否存在
get --path <path>
```

### 搜索失败处理流程

```text
search --keyword <keyword> 无结果
    ↓ 第一步
更换关键词（更短、更模糊、不同扩展名）
    ↓ 仍无结果
list 逐级手动浏览定位
    ↓ 仍找不到，怀疑索引未建立
index-update --paths "/目标目录"   （增量更新，代价小）
    ↓ 仍无结果，且确认索引损坏或首次配置
index-build --async               （最后手段）
```

**禁止在搜索无结果后立即触发 `index-build`。**

### 写操作流程

```text
rename / move / copy / remove 前：
    ↓
先 get --path <path> 确认目标存在且路径正确
    ↓
执行操作
    ↓ 操作完成后（可选）
list 父目录验证结果
```

---

## 输出格式

所有命令统一输出 JSON：

```json
// 成功
{"code": 200, "message": "success", "data": {...}}

// 失败
{"code": 400, "message": "错误说明", "data": null}
```

分享链接格式：`http://<host>/@s/<share_id>`，由 `share-create` 和 `share-get` 的响应中的 `share_link` 字段直接提供，无需手动拼接。

---

## 典型调用示例

```bash
# 列出根目录（JSON 输出）
sh skills/qnap-openlist/scripts/openlist.sh list --path / --json

# 确认路径是否存在
sh skills/qnap-openlist/scripts/openlist.sh get --path /Quark/docs

# 搜索关键词（先走 API，自动降级到遍历）
sh skills/qnap-openlist/scripts/openlist.sh search --path /Quark --keyword report --json

# 获取文件下载直链
sh skills/qnap-openlist/scripts/openlist.sh link --path /Quark/video.mp4 --json

# 上传本地文件（覆盖同名）
sh skills/qnap-openlist/scripts/openlist.sh upload \
    --path /Backup/ --file /share/Download/report.pdf --replace

# 批量正则重命名
sh skills/qnap-openlist/scripts/openlist.sh regex-rename \
    --src-dir /Quark/videos \
    --src-regex "^(.*)\\.MP4$" \
    --dst-regex "\1.mp4"

# 创建带密码的分享链接（24 小时有效）
sh skills/qnap-openlist/scripts/openlist.sh share-create \
    --files /Quark/report.pdf --password abc123 --expire-hours 24 --json

# 增量更新指定目录索引
sh skills/qnap-openlist/scripts/openlist.sh index-update --paths /Quark --json

# 全量重建索引（异步，适合大库）
sh skills/qnap-openlist/scripts/openlist.sh index-build --async --json
```

---

## 注意事项

- `config.json` 存储于 `skills/qnap-openlist/config.json`，包含 token 明文，权限已设为 600，勿复制到其他位置。
- token 有效期由 OpenList 服务端配置决定，若出现 401 错误请重新执行 `login`。
- 上传大文件时建议加 `--async-upload`，避免因 HTTP 请求超时（默认 300 秒）导致失败。
- `index-build` 会对 OpenList 服务端造成较大 I/O 压力，QNAP 低功耗机型在高负载磁盘同时运行时慎用。

---

## 自定义错误码

脚本在无法到达服务端或发生客户端异常时，返回以下自定义错误码：

| 错误码 | 说明 | 处理建议 |
|:-------|:-----|:---------|
| `997`  | 请求超时 | 服务器响应过慢或网络延迟；索引类操作已设为 120s，可检查服务端状态或加 `--async` |
| `998`  | 连接失败 | OpenList 实例地址不可达；检查 `--url` 是否正确、服务是否运行、防火墙是否放行 |
| `999`  | 客户端请求异常 | 参数格式错误（如 `--config` JSON 非法）或未知 Python 异常；检查输入参数 |

注意：`200` 为成功，其他 3 位/4 位错误码为 OpenList 服务端原生错误码。
