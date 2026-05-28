---
name: qnap-filestation
description: >
  QNAP QTS File Station HTTP API 完整技能包（中文版）。
  涵盖文件/文件夹的创建、重命名、复制、移动、安全删除（回收站）、上传下载、
  ACL权限管理、共享链接、高级搜索、媒体转码、DLNA、文字编辑器、存储信息、ISO挂载等所有功能。
  当 picoclaw agent 需要对 QNAP NAS 进行任何文件操作时必须使用此技能包。
  本技能包基于官方白皮书 QNAP QTS File Station HTTP API v5（最新版）。
  前置依赖：必须先通过 qnap-auth 技能包获取 sid 后才可调用。

references:
  - qnap-basic-operations-skill.md       # 创建文件夹、重命名、复制、移动、删除（含回收站与永久删除对比）
  - qnap-upload-download-skill.md        # 上传（标准/分块断点续传）、下载、缩略图、压缩解压、文件状态
  - qnap-recycle-bin-skill.md            # 网络回收站完整操作（Agent 安全删除核心，必读）
  - qnap-file-list-skill.md              # get_tree、get_list、用户列表、媒体文件夹、总大小
  - qnap-acl-permissions-skill.md        # ACL权限读取/设置、用户组列表、设置文件所有者
  - qnap-share-links-skill.md            # 创建/更新/删除/列出共享链接、下载/上传共享、成员管理
  - qnap-search-compress-skill.md        # 高级搜索条件、ISO挂载/卸载、旋转图片
  - qnap-media-dlna-skill.md              # 媒体库转码、DLNA配置、视频格式支持
  - qnap-storage-info-skill.md           # 存储容量、主机名、外网IP、远程连接
  - qnap-picoclaw-integration-skill.md   # picoclaw 完整集成代码、安全规范、最佳实践（必读）
  - qnap-error-codes-skill.md            # File Station API 完整错误码参考
---

# QNAP File Station HTTP API — 技能包总览

> 官方白皮书：QNAP QTS File Station HTTP API v5
> 所有请求基础路径：`http://IP:8080/cgi-bin/filemanager/utilRequest.cgi`
> 所有请求必须携带 `&sid=${sid}` 参数

---

## 快速 API 索引

| 操作 | func 参数值 | 详细文档 |
|------|------------|---------|
| 列出文件夹树 | `get_tree` | qnap-file-list-skill.md |
| 列出文件列表 | `get_list` | qnap-file-list-skill.md |
| 创建文件夹 | `createdir` | qnap-basic-operations-skill.md |
| 重命名 | `rename` | qnap-basic-operations-skill.md |
| 复制 | `copy` | qnap-basic-operations-skill.md |
| 移动 | `move` | qnap-basic-operations-skill.md |
| **安全删除（进回收站）** | `delete`（force=0） | **qnap-recycle-bin-skill.md ⚠️** |
| 永久删除（危险）| `delete&force=1` | qnap-basic-operations-skill.md |
| 上传文件 | `upload` | qnap-upload-download-skill.md |
| 分块上传 | `start_chunked_upload` | qnap-upload-download-skill.md |
| 下载文件 | `download` | qnap-upload-download-skill.md |
| 图片/视频缩略图 | `thumbnail` | qnap-upload-download-skill.md |
| 文件状态/属性 | `stat` / `get_property` | qnap-upload-download-skill.md |
| 文件校验值 | `get_checksum` | qnap-upload-download-skill.md |
| 压缩文件 | `compress` | qnap-upload-download-skill.md |
| 解压文件 | `extract` | qnap-upload-download-skill.md |
| 查看回收站 | `get_tree&node=recycle_root` | qnap-recycle-bin-skill.md |
| 从回收站恢复 | `recycle_bin_recovery` | qnap-recycle-bin-skill.md |
| 清空回收站（单个）| `clean_recyclebin` | qnap-recycle-bin-skill.md |
| 清空所有回收站 | `empty_all_recyclebin` | qnap-recycle-bin-skill.md |
| 回收站状态查询 | `get_recyclebin_status` | qnap-recycle-bin-skill.md |
| 查看ACL权限 | `getACLPrivilege` | qnap-acl-permissions-skill.md |
| 设置ACL权限 | `setACLPrivilege` | qnap-acl-permissions-skill.md |
| 创建共享链接 | `create_share_link` | qnap-share-links-skill.md |
| 高级文件搜索 | `search` | qnap-search-compress-skill.md |
| 挂载ISO | `mount_iso` | qnap-search-compress-skill.md |
| 卸载ISO | `umount_iso` | qnap-search-compress-skill.md |
| 媒体库转码 | `get_transcode_info` | qnap-media-dlna-skill.md |
| 获取存储信息 | `get_storage_info` | qnap-storage-info-skill.md |
| 获取主机名 | `get_hostname` | qnap-storage-info-skill.md |
| 获取外网IP | `get_external_ip` | qnap-storage-info-skill.md |

---

## 通用请求规范

```
GET http://IP:8080/cgi-bin/filemanager/utilRequest.cgi
  ?func=${function_name}
  &sid=${sid}
  &[其他参数...]
```

### 路径格式
- 共享文件夹根路径：`/share/ShareName` 或 `/ShareName`
- 子路径示例：`/share/homes/admin/documents/file.txt`
- 回收站路径：`/share/ShareName/.recycle/`

### 通用返回结构
```json
{ "status": 1, "func": "createdir", "datas": [] }
```

| status | 含义 |
|--------|------|
| `1` | 成功 |
| `0` | 失败 |

---

## picoclaw Agent 核心安全原则

```
删除文件时，永远不使用 force=1 参数！

  func=delete（无 force 或 force=0） → 进入网络回收站，可以恢复  ✅
  func=delete&force=1               → 永久删除，无法恢复          ❌
  SSH 的 rm 命令                     → 等同于永久删除              ❌

完整实现见 references/qnap-picoclaw-integration-skill.md
```
---

## 附录 A：安全删除对比示例

> `safe-rm.sh` 是推荐的删除方式。以下对比展示 SSH 命令行删除 vs File Station HTTP API 删除的区别，供参考。

```python
# ❌ 旧方式：SSH 命令（永久删除，无法恢复）
ssh.exec("rm -rf /share/Public/old_file.txt")

# ✅ 新方式 A：使用 safe-rm.sh（推荐，移入 @Recycle 回收站）
#   tools/safe-rm.sh /share/Public/old_file.txt

# ✅ 新方式 B：File Station HTTP API（同样进回收站，适合需要 API 集成时）
import requests, base64
from xml.etree import ElementTree as ET

# Step 1: 登录获取 sid
resp = requests.get("http://NAS-IP:8080/cgi-bin/authLogin.cgi", params={
    "user": "admin",
    "pwd": base64.b64encode("your_password".encode()).decode(),
    "client_app": "picoclaw",
})
sid = ET.fromstring(resp.text).findtext("authSid")

# Step 2: 安全删除（进回收站）—— 绝不加 force=1
del_resp = requests.get(
    "http://NAS-IP:8080/cgi-bin/filemanager/utilRequest.cgi",
    params={
        "func":  "delete",
        "sid":   sid,
        "path0": "/share/Public/old_file.txt",
        "total": 1,
        "force": 0,   # ← 关键！0 = 进回收站；1 = 永久删除（禁用）
    }
).json()
# 返回: {"status": 1, "pid": "55002"}  → 文件在回收站，随时可恢复

# Step 3: 如需从回收站恢复
recover_resp = requests.get(
    "http://NAS-IP:8080/cgi-bin/filemanager/utilRequest.cgi",
    params={
        "func":      "recycle_bin_recovery",
        "sid":       sid,
        "path":      "/share/Public/.recycle/old_file.txt",
        "dest_path": "/share/Public/",
    }
).json()
```

---

## 附录 B：Python 系统信息查询示例

> 以下代码通过 HTTP API 查询 NAS 系统信息，使用前替换 SID 和 NAS IP。

```python
import subprocess, re, json

SID    = "你的SID"
NAS_IP = "NAS-IP:5000"
COOKIE = f"NAS_SID={SID}"
BASE   = f"https://{NAS_IP}/cgi-bin"

def curl_get(path, params=""):
    url = f"{BASE}/{path}?{params}&sid={SID}" if params else f"{BASE}/{path}?sid={SID}"
    r = subprocess.run(
        ["curl", "-s", "--noproxy", "*", "-k", "-b", COOKIE, url],
        capture_output=True, text=True
    )
    return r.stdout

def xml_val(xml, tag):
    m = re.findall(rf"<{tag}><!\[CDATA\[([^\]]*)\]\]>", xml)
    return m[0].strip() if m else "N/A"

def get_volumes():
    xml = curl_get("disk/disk_manage.cgi", "func=get_volume")
    return [
        {
            "label":    xml_val(row, "vol_label"),
            "used_pct": xml_val(row, "used_percent"),
            "raid":     xml_val(row, "raid_level"),
        }
        for row in re.findall(r"<row>(.*?)</row>", xml, re.DOTALL)
    ]
```
