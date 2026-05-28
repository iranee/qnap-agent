# File Station 参考手册 06 — 共享链接（Share Link）

> 接口基础 URL：`http://IP:8080/cgi-bin/filemanager/utilRequest.cgi`

---

## 共享链接概述

QNAP 共享链接允许将 NAS 上的文件/文件夹通过公开 URL 分享给外部用户，支持：
- 有效期控制（永久/指定日期/指定次数）
- 密码保护
- 上传权限（允许外部用户向共享文件夹上传）
- 查看/下载权限分离
- 访客用户管理

---

## 1. 创建共享链接（create_share_link）

### 请求
```
GET ?func=create_share_link
  &sid=${sid}
  &path=${文件或文件夹完整路径}
  &type=${共享类型}
  &expiry_type=${过期类型}
  &expiry_date=${过期日期}           # expiry_type=1 时必填，格式：YYYY-MM-DD
  &access_limit_count=${访问次数}    # expiry_type=2 时必填
  &password=${访问密码}              # 可选，留空表示无密码
  &allow_upload=${0/1}              # 1=允许上传（仅文件夹类型）
  &notify_email=${通知邮件}          # 可选，有人访问时通知
  &access_enable_download=${0/1}   # 0=仅查看；1=允许下载
  &link_name=${链接名称}             # 可选，自定义名称
```

**共享类型（type）**

| 值 | 说明 |
|----|------|
| `0` | 文件链接（下载链接） |
| `1` | 文件夹链接（浏览链接） |

**过期类型（expiry_type）**

| 值 | 说明 |
|----|------|
| `0` | 永不过期 |
| `1` | 指定日期后过期 |
| `2` | 指定访问次数后失效 |

### 返回
```json
{
  "status": 1,
  "datas": {
    "link_id": "AbCdEfGhIjKl",
    "url": "https://yournas.myqnapcloud.com:443/share/AbCdEfGhIjKl",
    "short_url": "https://qnap.to/AbCdEfGhIjKl",
    "path": "/share/homes/admin/document.pdf",
    "created_time": 1700000000,
    "expiry_type": 0
  }
}
```

---

## 2. 更新共享链接（update_share_link）

### 请求
```
GET ?func=update_share_link
  &sid=${sid}
  &link_id=${链接ID}
  &expiry_type=${过期类型}
  &expiry_date=${过期日期}
  &access_limit_count=${访问次数}
  &password=${新密码}
  &allow_upload=${0/1}
  &access_enable_download=${0/1}
```

### 返回
```json
{ "status": 1 }
```

---

## 3. 删除共享链接（delete_share_link）

### 请求
```
GET ?func=delete_share_link
  &sid=${sid}
  &link_id=${链接ID}
```

### 批量删除
```
GET ?func=delete_share_link
  &sid=${sid}
  &link_id0=${链接ID1}
  &link_id1=${链接ID2}
  &total=2
```

### 返回
```json
{ "status": 1 }
```

---

## 4. 列出所有共享链接（list_share_link）

### 请求
```
GET ?func=list_share_link
  &sid=${sid}
  &start=0
  &limit=50
  &sort=created_time
  &order=DESC
```

### 返回
```json
{
  "status": 1,
  "total": 3,
  "datas": [
    {
      "link_id": "AbCdEfGhIjKl",
      "url": "https://...",
      "path": "/share/homes/admin/document.pdf",
      "filename": "document.pdf",
      "ftype": "file",
      "created_time": 1700000000,
      "expiry_type": 1,
      "expiry_date": "2025-12-31",
      "access_count": 5,            // 已被访问次数
      "access_limit_count": 10,     // 最大访问次数（type=2时）
      "has_password": 1,
      "allow_upload": 0,
      "created_by": "admin"
    }
  ]
}
```

---

## 5. 获取共享链接成员列表（get_share_link_members）

> 查看谁有权访问密码保护的共享链接。

### 请求
```
GET ?func=get_share_link_members
  &sid=${sid}
  &link_id=${链接ID}
```

### 返回
```json
{
  "status": 1,
  "datas": [
    {
      "member_id": "guest_001",
      "type": "guest",          // guest / user
      "name": "访客001",
      "access_count": 3,
      "last_access": 1700050000
    }
  ]
}
```

---

## 6. 通过共享链接下载文件（无需 sid）

> 外部用户访问共享链接时使用的接口（无需 NAS 账号）。

### 请求
```
GET http://IP:8080/cgi-bin/filemanager/utilRequest.cgi
  ?func=access_share_link
  &link_id=${链接ID}
  &password=${密码}     # 若有密码保护则必填
```

### 返回
```json
{
  "status": 1,
  "datas": {
    "link_id": "AbCdEfGhIjKl",
    "filename": "document.pdf",
    "filesize": 204800,
    "download_url": "http://IP:8080/cgi-bin/filemanager/utilDownload.cgi?token=xxx",
    "allow_download": 1,
    "allow_upload": 0
  }
}
```

---

## 7. 通过共享链接上传文件（无需 sid）

### 请求
```
POST http://IP:8080/cgi-bin/filemanager/utilRequest.cgi
  ?func=upload_to_share_link
  &link_id=${链接ID}
  &password=${密码}

Content-Type: multipart/form-data
file = ${文件内容}
```

---

## 8. 获取共享链接内的文件列表（get_share_link_items）

> 对于文件夹类型的共享链接，列出其中的内容。

### 请求
```
GET ?func=get_share_link_items
  &link_id=${链接ID}
  &password=${密码}
  &dir=${子目录路径}   # 可选，浏览子文件夹
  &start=0
  &limit=100
```

---

## 9. 获取共享链接文件缩略图（share_link_thumbnail）

### 请求
```
GET ?func=share_link_thumbnail
  &link_id=${链接ID}
  &password=${密码}
  &path=${文件路径}
  &size=${small/medium/large}
```

---

## 10. 获取共享链接文件 stat（share_link_stat）

### 请求
```
GET ?func=share_link_stat
  &link_id=${链接ID}
  &password=${密码}
  &path=${文件路径}
```

---

## 11. Python 共享链接管理示例

```python
def create_temp_share_link(host, sid, path, days=7, password=None):
    """创建 N 天后过期的共享链接"""
    from datetime import datetime, timedelta
    
    expiry_date = (datetime.now() + timedelta(days=days)).strftime('%Y-%m-%d')
    
    params = {
        'func': 'create_share_link',
        'sid': sid,
        'path': path,
        'type': 0 if '.' in path.split('/')[-1] else 1,  # 简单判断文件/文件夹
        'expiry_type': 1,
        'expiry_date': expiry_date,
        'access_enable_download': 1,
    }
    if password:
        params['password'] = password
    
    resp = requests.get(
        f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi", params=params
    )
    return resp.json()

def list_all_share_links(host, sid):
    """列出所有共享链接"""
    resp = requests.get(
        f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi",
        params={'func': 'list_share_link', 'sid': sid, 'limit': 200}
    )
    return resp.json().get('datas', [])

def cleanup_expired_links(host, sid):
    """清理所有已创建超过有效期的链接"""
    links = list_all_share_links(host, sid)
    import time
    now = int(time.time())
    
    to_delete = []
    for link in links:
        if link.get('expiry_type') == 1:
            # 检查是否已过期（需解析日期）
            pass  # 根据实际逻辑处理
    
    return to_delete
```
