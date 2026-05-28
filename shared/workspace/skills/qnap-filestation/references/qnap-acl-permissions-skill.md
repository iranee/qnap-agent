# File Station 参考手册 05 — ACL 权限管理

> 接口基础 URL：`http://IP:8080/cgi-bin/filemanager/utilRequest.cgi`

---

## 1. 获取文件/文件夹 ACL 权限（get_acl_privilege）

### 请求
```
GET ?func=get_acl_privilege
  &sid=${sid}
  &path=${完整路径}
```

### 返回
```json
{
  "status": 1,
  "datas": {
    "path": "/share/homes/admin/docs",
    "owner": "admin",
    "group": "administrators",
    "unix_privilege": "rwxr-xr-x",
    "acl_list": [
      {
        "type": "user",             // user / group
        "name": "john",
        "uid": 1000,
        "privilege": {
          "read": 1,
          "write": 0,
          "execute": 1,
          "delete": 0,
          "change_perm": 0
        },
        "inherit": 1                // 1=继承父级ACL
      },
      {
        "type": "group",
        "name": "developers",
        "gid": 1001,
        "privilege": {
          "read": 1,
          "write": 1,
          "execute": 1,
          "delete": 1,
          "change_perm": 0
        }
      }
    ]
  }
}
```

---

## 2. 设置 ACL 权限（set_acl_privilege）

### 请求
```
POST ?func=set_acl_privilege
  &sid=${sid}
  &path=${完整路径}

POST Body (JSON):
{
  "owner": "admin",
  "group": "administrators",
  "unix_privilege": "rwxr-xr-x",
  "apply_to_children": 1,          // 1=递归应用到子文件夹；0=仅当前
  "acl_list": [
    {
      "type": "user",
      "name": "john",
      "privilege": {
        "read": 1,
        "write": 1,
        "execute": 1,
        "delete": 0,
        "change_perm": 0
      },
      "inherit": 1
    }
  ]
}
```

### 返回
```json
{ "status": 1 }
```

---

## 3. 获取可设置权限的用户/组列表（get_user_group_list）

> 列出所有可分配 ACL 的用户和用户组。

### 请求
```
GET ?func=get_user_group_list
  &sid=${sid}
  &path=${完整路径}
  &type=${0/1/2/3}    # 0=仅用户；1=仅组；2=用户+组；3=全部（含everyone）
```

### 返回
```json
{
  "status": 1,
  "datas": {
    "users": [
      { "name": "admin", "uid": 0, "is_admin": 1 },
      { "name": "john",  "uid": 1000, "is_admin": 0 }
    ],
    "groups": [
      { "name": "administrators", "gid": 0 },
      { "name": "developers",     "gid": 1001 }
    ],
    "special": [
      { "name": "everyone" },
      { "name": "guest" }
    ]
  }
}
```

---

## 4. 设置文件所有者（set_owner）

### 请求
```
GET ?func=set_owner
  &sid=${sid}
  &path=${完整路径}
  &owner=${用户名}
  &group=${组名}
  &apply_to_children=${0/1}   # 1=递归
```

### 返回
```json
{ "status": 1 }
```

---

## 5. Unix 权限字符串说明

```
rwxrwxrwx
│││││││││└── 其他用户：执行
││││││││└─── 其他用户：写
│││││││└──── 其他用户：读
││││││└───── 组：执行
│││││└────── 组：写
││││└─────── 组：读
│││└──────── 所有者：执行
││└───────── 所有者：写
│└────────── 所有者：读
```

**常用权限值**

| 字符串 | 八进制 | 说明 |
|--------|--------|------|
| `rwxr-xr-x` | 755 | 目录标准（所有者完全控制，其他只读执行） |
| `rw-r--r--` | 644 | 文件标准（所有者读写，其他只读） |
| `rwx------` | 700 | 私有目录（仅所有者） |
| `rwxrwxr-x` | 775 | 组协作目录 |
| `rw-rw-r--` | 664 | 组协作文件 |

---

## 6. ACL 权限字段含义

| 字段 | 值 | 说明 |
|------|----|------|
| `read` | 0/1 | 读取文件/列出目录内容 |
| `write` | 0/1 | 写入/修改/创建文件 |
| `execute` | 0/1 | 执行/进入目录 |
| `delete` | 0/1 | 删除文件/子目录 |
| `change_perm` | 0/1 | 修改权限 |
| `inherit` | 0/1 | 是否从父级继承 |

---

## 7. Python 权限管理示例

```python
def get_file_permissions(host, sid, path):
    """获取文件权限"""
    resp = requests.get(
        f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi",
        params={'func': 'get_acl_privilege', 'sid': sid, 'path': path}
    )
    return resp.json()

def set_read_only_for_user(host, sid, path, username):
    """设置某用户对文件/夹只有只读权限"""
    url = f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi"
    params = {'func': 'set_acl_privilege', 'sid': sid, 'path': path}
    body = {
        "apply_to_children": 0,
        "acl_list": [
            {
                "type": "user",
                "name": username,
                "privilege": {
                    "read": 1,
                    "write": 0,
                    "execute": 1,
                    "delete": 0,
                    "change_perm": 0
                }
            }
        ]
    }
    resp = requests.post(url, params=params, json=body)
    return resp.json()
```
