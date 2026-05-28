# File Station 参考手册 04 — 文件列表与查询

> 接口基础 URL：`http://IP:8080/cgi-bin/filemanager/utilRequest.cgi`

---

## 1. 获取文件/文件夹列表（get_list）

### 请求
```
GET ?func=get_list
  &sid=${sid}
  &is_iso=${0/1}            # 0=普通文件系统；1=ISO挂载内容
  &node=${节点类型}          # 见下方说明
  &dir=${目录路径}           # 要列出的目录
  &limit=${每页条数}         # 默认100，最大1000
  &start=${偏移量}           # 分页用，默认0
  &sort=${排序字段}          # filename / mt / filesize / ftype / privilege
  &order=${排序方向}         # ASC / DESC
  &hidden=1                 # 1=显示隐藏文件；0=不显示
  &dir_only=1               # 1=只返回文件夹
  &pattern=${搜索关键词}     # 在当前目录按文件名过滤
```

**node 节点类型说明**

| 值 | 说明 |
|----|------|
| `share_root` | 根节点，列出所有共享文件夹 |
| `share` | 指定共享文件夹内的内容 |
| `recycle_root` | 回收站根节点（见 03-回收站.md） |
| `media` | 媒体文件夹 |

### 返回
```json
{
  "status": 1,
  "total": 156,               // 当前目录总文件数
  "datas": [
    {
      "filename": "documents",
      "ftype": "dir",           // dir / file
      "filesize": 0,
      "mt": 1700000000,         // 最后修改时间（Unix 时间戳）
      "ct": 1699000000,         // 创建时间
      "path": "/share/homes/admin/documents",
      "is_shared": 0,           // 是否已创建共享链接
      "privilege": "rwxr-xr-x", // Unix 权限字符串
      "owner": "admin",
      "group": "administrators",
      "isReadOnly": 0,
      "isHidden": 0,
      "is_mountpoint": 0,
      "real_total": 45          // 文件夹内文件总数（仅 dir 类型）
    },
    {
      "filename": "report.pdf",
      "ftype": "file",
      "filesize": 204800,
      "mt": 1700050000,
      "ct": 1700000000,
      "path": "/share/homes/admin/report.pdf",
      "media_type": "document", // image / video / audio / document / others
      "thumb_small": "/cgi-bin/filemanager/...?func=thumbnail&size=small&...",
      "is_shared": 1,
      "privilege": "rw-r--r--"
    }
  ]
}
```

### 返回字段完整说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `filename` | string | 文件/文件夹名 |
| `ftype` | string | `file` / `dir` |
| `filesize` | int | 字节数（文件夹为0） |
| `mt` | int | 修改时间（Unix 时间戳） |
| `ct` | int | 创建时间（Unix 时间戳） |
| `path` | string | 完整路径 |
| `privilege` | string | Unix 权限字符串（如 `rw-r--r--`） |
| `owner` | string | 文件所有者 |
| `group` | string | 所属组 |
| `media_type` | string | 媒体类型分类 |
| `is_shared` | int | `1`=已有共享链接 |
| `isReadOnly` | int | `1`=只读 |
| `isHidden` | int | `1`=隐藏文件 |
| `is_mountpoint` | int | `1`=挂载点 |
| `real_total` | int | 文件夹内的总条目数 |
| `thumb_small/medium/large` | string | 缩略图 URL |

---

## 2. 获取文件夹树状结构（get_tree）

> 递归获取目录树，适合构建文件夹选择器。

### 请求
```
GET ?func=get_tree
  &sid=${sid}
  &node=${节点类型}           # share_root / share / recycle_root / iso
  &is_iso=0
  &dir=${起始目录路径}
```

### 返回
```json
{
  "status": 1,
  "datas": [
    {
      "text": "homes",
      "id": "/share/homes",
      "has_child": true,
      "children": [
        {
          "text": "admin",
          "id": "/share/homes/admin",
          "has_child": true
        }
      ]
    },
    {
      "text": "Public",
      "id": "/share/Public",
      "has_child": false
    }
  ]
}
```

---

## 3. 获取文件夹总大小（get_total_size）

> 异步计算，适合大文件夹。

### 请求
```
GET ?func=get_total_size
  &sid=${sid}
  &source_total=${数量}
  &source_path=/share/homes/admin
```

### 返回（异步）
```json
{
  "status": 1,
  "pid": "66001"
}
```

### 查询大小计算进度
```
GET ?func=get_total_size_status
  &sid=${sid}
  &pid=${pid}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "pid": "66001",
    "status": "finish",        // running / finish
    "total_size": 10737418240, // 字节（10GB）
    "file_count": 2345,
    "folder_count": 123
  }
}
```

---

## 4. 获取用户列表（get_user_list）

> 列出 NAS 上的所有用户，用于 ACL 权限设置。

### 请求
```
GET ?func=get_user_list
  &sid=${sid}
  &type=${0/1/2}     # 0=本地用户；1=本地组；2=全部
  &start=0
  &limit=100
```

### 返回
```json
{
  "status": 1,
  "total": 5,
  "datas": [
    {
      "username": "admin",
      "uid": 0,
      "is_admin": 1,
      "user_type": "local"
    },
    {
      "username": "john",
      "uid": 1000,
      "is_admin": 0,
      "user_type": "local"
    }
  ]
}
```

---

## 5. 获取媒体文件夹列表（get_media_folder）

> 返回媒体库中已配置的媒体文件夹路径。

### 请求
```
GET ?func=get_media_folder
  &sid=${sid}
  &type=${类型}    # photo / video / music / all
```

### 返回
```json
{
  "status": 1,
  "datas": [
    {
      "path": "/share/homes/admin/Photos",
      "type": "photo",
      "enabled": 1
    }
  ]
}
```

---

## 6. 分页列表示例（Python）

```python
def list_all_files(host, sid, dir_path):
    """分页获取目录下的所有文件（自动处理分页）"""
    base_url = f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi"
    all_files = []
    start = 0
    limit = 200
    
    while True:
        resp = requests.get(base_url, params={
            'func': 'get_list',
            'sid': sid,
            'is_iso': 0,
            'node': 'share',
            'dir': dir_path,
            'start': start,
            'limit': limit,
            'sort': 'filename',
            'order': 'ASC',
        })
        data = resp.json()
        
        if data.get('status') != 1:
            break
        
        items = data.get('datas', [])
        all_files.extend(items)
        
        total = data.get('total', 0)
        start += limit
        
        if start >= total:
            break
    
    return all_files
```
