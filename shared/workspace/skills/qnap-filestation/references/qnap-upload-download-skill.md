# File Station 参考手册 02 — 上传与下载

> 接口基础 URL：`http://IP:8080/cgi-bin/filemanager/utilRequest.cgi`

---

## 1. 标准文件上传（upload）

> 使用 HTTP Multipart POST 上传单个文件。

### 请求
```
POST http://IP:8080/cgi-bin/filemanager/utilRequest.cgi?func=upload&sid=${sid}

Content-Type: multipart/form-data

表单字段：
  type         = "standard"
  overwrite    = ${0/1}        # 0=跳过；1=覆盖
  dest_path    = ${目标目录路径}  # 例：/share/homes/admin
  file         = ${文件二进制内容}
```

### 返回
```json
{
  "status": 1,
  "datas": [
    {
      "file": "document.pdf",
      "exist": 0,           // 0=新上传；1=已存在（覆盖）
      "size": 204800
    }
  ]
}
```

### Python 示例
```python
import requests

def upload_file(host, sid, local_path, dest_path, overwrite=False):
    """上传文件到 QNAP"""
    url = f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi"
    params = {'func': 'upload', 'sid': sid}
    
    with open(local_path, 'rb') as f:
        files = {'file': (local_path.split('/')[-1], f, 'application/octet-stream')}
        data = {
            'type': 'standard',
            'overwrite': '1' if overwrite else '0',
            'dest_path': dest_path,
        }
        resp = requests.post(url, params=params, files=files, data=data)
    
    return resp.json()
```

---

## 2. 分块上传（chunked upload）

> 适合大文件上传，分多个块传输，支持断点续传。

### 第一步：获取上传 Token（get_upload_id）
```
GET ?func=get_upload_id
  &sid=${sid}
  &filename=${文件名}
  &filesize=${文件总字节数}
  &upload_path=${目标目录路径}
  &overwrite=${0/1}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "upload_id": "abc123def456",    // 上传会话 ID
    "chunk_size": 10485760          // 建议的分块大小（字节，通常 10MB）
  }
}
```

### 第二步：分块上传（upload_chunk）
```
POST ?func=upload_chunk&sid=${sid}

Content-Type: multipart/form-data

表单字段：
  upload_id       = ${upload_id}
  chunk_index     = ${当前块序号，从0开始}
  total_chunks    = ${总块数}
  file            = ${当前块的二进制内容}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "upload_id": "abc123def456",
    "chunk_index": 2,
    "received": 3
  }
}
```

### 第三步：确认完成（finish_upload）
```
GET ?func=finish_upload
  &sid=${sid}
  &upload_id=${upload_id}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "path": "/share/homes/admin/bigfile.zip",
    "size": 104857600
  }
}
```

### 分块上传 Python 示例
```python
import requests
import math

def chunked_upload(host, sid, local_path, dest_path, overwrite=False):
    """分块上传大文件"""
    base_url = f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi"
    filename = local_path.split('/')[-1]
    filesize = os.path.getsize(local_path)
    
    # Step 1: 获取 upload_id
    resp = requests.get(base_url, params={
        'func': 'get_upload_id', 'sid': sid,
        'filename': filename, 'filesize': filesize,
        'upload_path': dest_path, 'overwrite': '1' if overwrite else '0',
    })
    data = resp.json()
    upload_id = data['datas']['upload_id']
    chunk_size = data['datas'].get('chunk_size', 10 * 1024 * 1024)
    total_chunks = math.ceil(filesize / chunk_size)
    
    # Step 2: 逐块上传
    with open(local_path, 'rb') as f:
        for i in range(total_chunks):
            chunk = f.read(chunk_size)
            files = {'file': (f'chunk_{i}', chunk, 'application/octet-stream')}
            data = {
                'upload_id': upload_id,
                'chunk_index': str(i),
                'total_chunks': str(total_chunks),
            }
            requests.post(f"{base_url}?func=upload_chunk&sid={sid}",
                         files=files, data=data)
            print(f"上传进度：{i+1}/{total_chunks}")
    
    # Step 3: 确认完成
    resp = requests.get(base_url, params={
        'func': 'finish_upload', 'sid': sid, 'upload_id': upload_id
    })
    return resp.json()
```

---

## 3. 文件下载（download）

### 方式一：直接下载（URL 方式）
```
GET http://IP:8080/cgi-bin/filemanager/utilRequest.cgi
  ?func=download
  &sid=${sid}
  &isfolder=${0/1}       # 0=文件；1=文件夹（自动打包为zip）
  &source_total=${数量}
  &source_path=${路径}
  &source_path1=${路径2}
```

> 此接口直接返回文件的二进制内容（文件流），适合直接在浏览器中触发下载或 requests 流式接收。

### 方式二：获取下载链接 ID（get_download_link）
```
GET ?func=get_download_link
  &sid=${sid}
  &source_total=${数量}
  &source_path=${路径}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "link_id": "dl_abc123",
    "url": "http://IP:8080/cgi-bin/filemanager/utilDownload.cgi?link_id=dl_abc123"
  }
}
```

### 查询下载状态（get_download_status）
```
GET ?func=get_download_status
  &sid=${sid}
  &link_id=${link_id}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "link_id": "dl_abc123",
    "dl_status": "ready",     // preparing / ready / error
    "size": 204800,
    "url": "http://..."
  }
}
```

### 下载 Python 示例（流式接收大文件）
```python
import requests

def download_file(host, sid, remote_path, local_save_path):
    """从 QNAP 下载文件到本地"""
    url = f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi"
    params = {
        'func': 'download',
        'sid': sid,
        'isfolder': 0,
        'source_total': 1,
        'source_path': remote_path,
    }
    
    with requests.get(url, params=params, stream=True) as resp:
        resp.raise_for_status()
        with open(local_save_path, 'wb') as f:
            for chunk in resp.iter_content(chunk_size=8192):
                f.write(chunk)
    
    print(f"下载完成：{local_save_path}")
```

---

## 4. 图片缩略图（thumbnail）

### 请求
```
GET http://IP:8080/cgi-bin/filemanager/utilRequest.cgi
  ?func=thumbnail
  &sid=${sid}
  &path=${图片完整路径}
  &size=${尺寸规格}       # small / medium / large / xlarge / original
  &type=1               # 1=同步（直接返回图片）；2=异步
```

**尺寸规格说明**

| 值 | 尺寸 |
|----|------|
| `small` | 80×80 |
| `medium` | 160×160 |
| `large` | 320×320 |
| `xlarge` | 640×640 |
| `original` | 原始尺寸 |

> 返回值：直接返回 JPEG/PNG 图片二进制流。

---

## 5. 视频缩略图（video_thumbnail）

### 请求
```
GET ?func=video_thumbnail
  &sid=${sid}
  &path=${视频完整路径}
  &time=${秒数}          # 截取哪一秒的画面，默认0
  &size=${尺寸规格}
```

---

## 6. PDF 缩略图（pdf_thumbnail）

### 请求
```
GET ?func=pdf_thumbnail
  &sid=${sid}
  &path=${PDF完整路径}
  &page=${页码，从1开始}
  &size=${尺寸规格}
```

---

## 7. 媒体信息（media_info）

> 获取媒体文件的详细元数据（音视频时长、分辨率、编码等）。

### 请求
```
GET ?func=media_info
  &sid=${sid}
  &path=${媒体文件路径}
```

### 返回
```json
{
  "status": 1,
  "datas": {
    "duration": 3600,           // 时长（秒）
    "width": 1920,
    "height": 1080,
    "video_codec": "h264",
    "audio_codec": "aac",
    "bitrate": 8000000,         // 码率（bps）
    "fps": 30,
    "format": "mp4"
  }
}
```

---

## 8. 文件属性扩展（property）

### 请求
```
GET ?func=property
  &sid=${sid}
  &path=${完整路径}
```

### 返回
```json
{
  "status": 1,
  "datas": {
    "filename": "video.mp4",
    "filesize": 1073741824,
    "ftype": "file",
    "mt": 1700000000,
    "ct": 1699000000,
    "folder_content": {
      "file_count": 0,
      "folder_count": 0,
      "total_size": 0
    },
    "media_type": "video",
    "is_shared": 1,
    "share_link": "https://..."
  }
}
```
