# File Station 参考手册 09 — 系统存储信息、ISO 挂载、远程连接

> 接口基础 URL：`http://IP:8080/cgi-bin/filemanager/utilRequest.cgi`

---

## 一、存储信息（Storage Info）

### 1. 获取所有存储信息（get_storage_info）

```bash
GET ?func=get_storage_info
  &sid=${sid}
```

**返回**
```json
{
  "status": 1,
  "datas": [
    {
      "share": "DataVol1",
      "label": "DataVol1",
      "path": "/share/DataVol1",
      "type": "volume",           // volume / external / iso / remote
      "fs": "ext4",               // 文件系统类型
      "total": 4398046511104,     // 总容量（字节）
      "used": 1073741824,         // 已用（字节）
      "free": 4397083893760,      // 可用（字节）
      "usage_percent": 0.02,
      "status": "ready",          // ready / degraded / error
      "is_encrypted": 0,
      "is_locked": 0
    },
    {
      "share": "homes",
      "label": "homes",
      "path": "/share/homes",
      "type": "volume",
      "total": 1099511627776,
      "used": 52428800,
      "free": 1099459199000,
      "usage_percent": 0.05
    }
  ]
}
```

**存储类型（type）说明**

| 值 | 说明 |
|----|------|
| `volume` | 内部存储卷（RAID/单盘） |
| `external` | USB/eSATA 外接存储 |
| `iso` | 已挂载的 ISO 文件 |
| `remote` | 远程网络存储 |

### 2. 获取单个共享文件夹存储信息

```bash
GET ?func=get_share_info
  &sid=${sid}
  &path=${共享文件夹路径}
```

**返回格式同上，只返回指定共享的信息。**

---

## 二、主机名与外部 IP

### 1. 获取 NAS 主机名（get_hostname）

```bash
GET ?func=get_hostname
  &sid=${sid}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "hostname": "QNAP-TS670",
    "domain": "local",
    "fqdn": "QNAP-TS670.local"
  }
}
```

### 2. 获取外部 IP 地址（get_external_ip）

```bash
GET ?func=get_external_ip
  &sid=${sid}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "external_ip": "203.0.113.42",
    "ip_type": "IPv4",             // IPv4 / IPv6
    "ddns_hostname": "mynas.myqnapcloud.com"
  }
}
```

---

## 三、ISO 文件挂载/卸载

### 1. 挂载 ISO（mount_iso）

> 将 NAS 上的 ISO 文件挂载为虚拟光驱，在 File Station 中像普通文件夹一样浏览。

```bash
GET ?func=mount_iso
  &sid=${sid}
  &path=${ISO文件完整路径}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "mount_path": "/share/QNAP_ISO/ubuntu-22.04.iso",
    "label": "Ubuntu 22.04 LTS amd64"
  }
}
```

### 2. 卸载 ISO（umount_iso）

```bash
GET ?func=umount_iso
  &sid=${sid}
  &path=${ISO挂载路径}
```

**返回**
```json
{ "status": 1 }
```

### 3. 列出已挂载的 ISO（list_iso）

```bash
GET ?func=list_iso
  &sid=${sid}
```

**返回**
```json
{
  "status": 1,
  "datas": [
    {
      "path": "/share/homes/admin/ubuntu.iso",
      "mount_path": "/share/QNAP_ISO/ubuntu.iso",
      "label": "Ubuntu 22.04",
      "size": 1288490188
    }
  ]
}
```

---

## 四、远程连接管理（Remote Connection）

> 允许将远程 SMB/NFS 网络路径挂载到 NAS 的文件系统中。

### 1. 列出远程连接（list_remote_connection）

```bash
GET ?func=list_remote_connection
  &sid=${sid}
```

**返回**
```json
{
  "status": 1,
  "datas": [
    {
      "id": "rc_001",
      "name": "办公室NAS",
      "protocol": "smb",          // smb / nfs / ftp / webdav
      "host": "192.168.2.100",
      "port": 445,
      "path": "/share/backup",
      "mount_path": "/share/RemoteConn/办公室NAS",
      "status": "connected",       // connected / disconnected / error
      "username": "backup_user",
      "auto_connect": 1
    }
  ]
}
```

### 2. 创建远程连接（create_remote_connection）

```bash
POST ?func=create_remote_connection
  &sid=${sid}

POST Body (JSON):
{
  "name": "远程备份服务器",
  "protocol": "smb",            // smb / nfs / ftp / webdav
  "host": "192.168.2.200",
  "port": 445,
  "path": "/backup",
  "username": "backup_user",
  "password": "secret",
  "auto_connect": 1,
  "mount_path": "/share/RemoteConn/backup_server"
}
```

**协议默认端口**

| 协议 | 默认端口 |
|------|---------|
| SMB | 445 |
| NFS | 2049 |
| FTP | 21 |
| WebDAV | 80（HTTP）/ 443（HTTPS） |

**返回**
```json
{
  "status": 1,
  "datas": {
    "id": "rc_002",
    "mount_path": "/share/RemoteConn/backup_server"
  }
}
```

### 3. 连接/断开远程连接（connect_remote / disconnect_remote）

```bash
GET ?func=connect_remote
  &sid=${sid}
  &id=${连接ID}

GET ?func=disconnect_remote
  &sid=${sid}
  &id=${连接ID}
```

### 4. 删除远程连接（delete_remote_connection）

```bash
GET ?func=delete_remote_connection
  &sid=${sid}
  &id=${连接ID}
```

---

## 五、网络分享访问（外部 SMB/NFS）

### 1. 列出外部 SMB 主机（list_smb_hosts）

```bash
GET ?func=list_smb_hosts
  &sid=${sid}
  &start=0
  &limit=50
```

### 2. 列出 SMB 共享（list_smb_shares）

```bash
GET ?func=list_smb_shares
  &sid=${sid}
  &host=${主机名或IP}
  &username=${用户名}
  &password=${密码}
```

**返回**
```json
{
  "status": 1,
  "datas": [
    { "name": "backup", "type": "Disk" },
    { "name": "media",  "type": "Disk" }
  ]
}
```

---

## 六、Python 存储监控示例

```python
def get_disk_usage_summary(host, sid):
    """获取所有存储卷的使用率摘要"""
    resp = requests.get(
        f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi",
        params={'func': 'get_storage_info', 'sid': sid}
    )
    data = resp.json()
    summary = []
    for vol in data.get('datas', []):
        total_gb = vol['total'] / (1024**3)
        used_gb  = vol['used']  / (1024**3)
        pct = vol.get('usage_percent', used_gb / total_gb) * 100
        summary.append({
            'name':    vol['share'],
            'total':   f"{total_gb:.1f} GB",
            'used':    f"{used_gb:.1f} GB",
            'percent': f"{pct:.1f}%",
            'warning': pct > 85    # 超过85%标记警告
        })
    return summary

def check_low_disk_space(host, sid, threshold_pct=85):
    """检查是否有存储卷即将满载"""
    summary = get_disk_usage_summary(host, sid)
    warnings = [v for v in summary if v['warning']]
    return warnings
```
