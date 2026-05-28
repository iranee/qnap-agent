# QNAP File Station API — 基础文件操作

> 基础路径：`http://IP:8080/cgi-bin/filemanager/utilRequest.cgi`
> 所有请求必须附带 `&sid=${sid}`

---

## 1. 创建文件夹（createdir）

### 请求
```
GET .../utilRequest.cgi
  ?func=createdir
  &sid=${sid}
  &dest_path=${parent_path}     # 父目录路径，如 /Public
  &dest_folder=${folder_name}   # 要创建的文件夹名
```

### 参数说明

| 参数 | 必填 | 说明 |
|------|------|------|
| `dest_path` | 是 | 父目录路径，例如 `/Public` 或 `/homes/admin` |
| `dest_folder` | 是 | 新文件夹名称 |

### 返回值
```json
{
  "status": 1,
  "func": "createdir",
  "path": "/Public/新文件夹"
}
```

**status 说明**

| 值 | 说明 |
|----|------|
| `1` | 创建成功 |
| `0` | 失败（权限不足或路径不存在） |
| `2` | 文件夹已存在 |

---

## 2. 重命名（rename）

### 请求
```
GET .../utilRequest.cgi
  ?func=rename
  &sid=${sid}
  &path=${file_or_folder_path}   # 要重命名的完整路径
  &newname=${new_name}           # 新名称（不含路径）
```

### 参数说明

| 参数 | 必填 | 说明 |
|------|------|------|
| `path` | 是 | 目标文件或文件夹完整路径，如 `/Public/old_name.txt` |
| `newname` | 是 | 新名称，如 `new_name.txt` |

### 返回值
```json
{
  "status": 1,
  "func": "rename"
}
```

**status 说明**

| 值 | 说明 |
|----|------|
| `1` | 重命名成功 |
| `2` | 新名称已存在 |
| `4` | 无权限 |
| `5` | 名称包含非法字符 |

---

## 3. 复制文件/文件夹（copy）

### 请求
```
GET .../utilRequest.cgi
  ?func=copy
  &sid=${sid}
  &path=${src_path}              # 源路径（支持多个，用逗号分隔）
  &dest_path=${dest_path}        # 目标目录路径
  &overwrite=${0/1}              # 1=覆盖同名文件
```

### 批量复制（多个源）
```
# 多文件路径用 path[]=xxx 方式传递（POST 表单）或逗号分隔
POST .../utilRequest.cgi
Body: func=copy&sid=${sid}&path[]=../file1.txt&path[]=/Public/file2.txt&dest_path=/Backup&overwrite=0
```

### 参数说明

| 参数 | 必填 | 说明 |
|------|------|------|
| `path` | 是 | 源文件或文件夹路径，多个用数组形式 `path[]=...` |
| `dest_path` | 是 | 目标目录路径 |
| `overwrite` | 否 | `1`=覆盖同名；`0`=不覆盖（默认） |

### 返回值
```json
{
  "status": 1,
  "func": "copy",
  "pid": "12345"
}
```

> `pid` 为后台任务 ID，可用 `func=get_copy_status&pid=12345` 查询进度

### 查询复制进度
```
GET .../utilRequest.cgi
  ?func=get_copy_status
  &sid=${sid}
  &pid=${pid}
```

**返回值**
```json
{
  "status": 1,
  "func": "get_copy_status",
  "datas": {
    "percent": 75,
    "total": 100,
    "current_file": "/Public/file.txt",
    "is_finished": 0
  }
}
```

---

## 4. 移动文件/文件夹（move）

### 请求
```
GET .../utilRequest.cgi
  ?func=move
  &sid=${sid}
  &path=${src_path}              # 源路径
  &dest_path=${dest_path}        # 目标目录路径
  &overwrite=${0/1}
```

### 参数说明

| 参数 | 必填 | 说明 |
|------|------|------|
| `path` | 是 | 源文件或文件夹路径，多个用 `path[]=` |
| `dest_path` | 是 | 目标目录路径 |
| `overwrite` | 否 | `1`=覆盖同名；`0`=不覆盖（默认） |

### 返回值
```json
{
  "status": 1,
  "func": "move",
  "pid": "12346"
}
```

---

## 5. 删除文件/文件夹（delete）

> ⚠️ **最重要的操作！请务必区分两种删除模式！**

### 5.1 安全删除 — 进入回收站（推荐 picoclaw 使用）

```
GET .../utilRequest.cgi
  ?func=delete
  &sid=${sid}
  &path=${path}                  # 要删除的路径（多个用 path[]=）
```

**不传 `force` 参数，或设置 `force=0`，文件将进入网络回收站，可以恢复。**

### 5.2 永久删除 — 不可恢复（禁止 picoclaw 使用）

```
GET .../utilRequest.cgi
  ?func=delete
  &sid=${sid}
  &path=${path}
  &force=1                       # ← 这个参数会绕过回收站！永久删除！
```

### 参数说明

| 参数 | 必填 | 说明 |
|------|------|------|
| `path` | 是 | 要删除的文件或文件夹路径，多个用 `path[]=` |
| `force` | 否 | `1`=永久删除（绕过回收站）；`0`或不传=进入回收站 |

### 返回值
```json
{
  "status": 1,
  "func": "delete",
  "pid": "12347"
}
```

### 查询删除进度
```
GET .../utilRequest.cgi
  ?func=get_del_status
  &sid=${sid}
  &pid=${pid}
```

**返回值**
```json
{
  "status": 1,
  "datas": {
    "percent": 100,
    "is_finished": 1,
    "total": 3,
    "current_file": "/Public/file3.txt"
  }
}
```

---

## 6. 打开/获取文件查看器（open_file / get_viewer）

### open_file
```
GET .../utilRequest.cgi
  ?func=open_file
  &sid=${sid}
  &path=${file_path}
```

返回适合该文件的查看器 URL。

### get_viewer
```
GET .../utilRequest.cgi
  ?func=get_viewer
  &sid=${sid}
  &path=${file_path}
  &type=${viewer_type}
```

**viewer_type 可选值**

| 值 | 说明 |
|----|------|
| `photo` | 图片查看器 |
| `video` | 视频播放器 |
| `music` | 音乐播放器 |
| `doc` | 文档查看器 |

---

## 7. Python 示例代码

```python
import requests

class QNAPFileOps:
    def __init__(self, host, sid, port=8080):
        self.base_url = f"http://{host}:{port}/cgi-bin/filemanager/utilRequest.cgi"
        self.sid = sid
    
    def _get(self, params: dict) -> dict:
        params['sid'] = self.sid
        resp = requests.get(self.base_url, params=params)
        return resp.json()
    
    def create_dir(self, parent_path: str, folder_name: str) -> dict:
        """创建文件夹"""
        return self._get({'func': 'createdir', 'dest_path': parent_path, 'dest_folder': folder_name})
    
    def rename(self, path: str, new_name: str) -> dict:
        """重命名文件或文件夹"""
        return self._get({'func': 'rename', 'path': path, 'newname': new_name})
    
    def copy(self, src_paths: list, dest_path: str, overwrite=False) -> dict:
        """复制文件/文件夹到目标目录"""
        params = {'func': 'copy', 'dest_path': dest_path, 'overwrite': 1 if overwrite else 0}
        resp = requests.get(self.base_url, params={**params, 'sid': self.sid,
                            **{f'path[{i}]': p for i, p in enumerate(src_paths)}})
        return resp.json()
    
    def move(self, src_paths: list, dest_path: str, overwrite=False) -> dict:
        """移动文件/文件夹到目标目录"""
        params = {'func': 'move', 'dest_path': dest_path, 'overwrite': 1 if overwrite else 0}
        resp = requests.get(self.base_url, params={**params, 'sid': self.sid,
                            **{f'path[{i}]': p for i, p in enumerate(src_paths)}})
        return resp.json()
    
    def safe_delete(self, paths: list) -> dict:
        """安全删除：文件进入回收站（推荐）"""
        # 注意：绝不添加 force=1 参数！
        params = {'func': 'delete'}
        resp = requests.get(self.base_url, params={**params, 'sid': self.sid,
                            **{f'path[{i}]': p for i, p in enumerate(paths)}})
        return resp.json()
    
    def permanent_delete(self, paths: list) -> dict:
        """永久删除：不可恢复！仅在明确需要时使用"""
        params = {'func': 'delete', 'force': 1}
        resp = requests.get(self.base_url, params={**params, 'sid': self.sid,
                            **{f'path[{i}]': p for i, p in enumerate(paths)}})
        return resp.json()
    
    def get_delete_status(self, pid: str) -> dict:
        """查询删除任务进度"""
        return self._get({'func': 'get_del_status', 'pid': pid})
```
