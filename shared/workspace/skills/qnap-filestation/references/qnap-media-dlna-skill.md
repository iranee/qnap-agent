# File Station 参考手册 08 — 媒体库、DLNA、转码与文本编辑器

> 接口基础 URL：`http://IP:8080/cgi-bin/filemanager/utilRequest.cgi`

---

## 一、媒体库管理（Media Library）

### 1. 扫描媒体库（scan_media_library）

> 触发媒体库扫描，更新媒体索引。

```bash
GET ?func=scan_media_library
  &sid=${sid}
  &type=${0/1/2}    # 0=全部；1=照片；2=视频；3=音乐
```

### 返回
```json
{ "status": 1 }
```

### 2. 获取媒体库扫描状态（get_media_library_status）

```bash
GET ?func=get_media_library_status
  &sid=${sid}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "scan_status": "idle",      // idle / scanning / error
    "last_scan_time": 1700000000,
    "total_photos": 12345,
    "total_videos": 678,
    "total_music": 9012
  }
}
```

### 3. 添加媒体文件夹（add_media_folder）

```bash
GET ?func=add_media_folder
  &sid=${sid}
  &path=${文件夹路径}
  &type=${1/2/3}    # 1=照片；2=视频；3=音乐
```

### 4. 移除媒体文件夹（remove_media_folder）

```bash
GET ?func=remove_media_folder
  &sid=${sid}
  &path=${文件夹路径}
  &type=${1/2/3}
```

---

## 二、DLNA 管理

### 1. 获取 DLNA 状态（get_dlna_status）

```bash
GET ?func=get_dlna_status
  &sid=${sid}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "enabled": 1,                     // 1=DLNA服务已启用
    "server_name": "QNAP-NAS",
    "port": 8200,
    "media_folders": [
      { "path": "/share/homes/admin/Music", "type": "music" },
      { "path": "/share/homes/admin/Videos", "type": "video" }
    ]
  }
}
```

### 2. 启用/禁用 DLNA（set_dlna_status）

```bash
GET ?func=set_dlna_status
  &sid=${sid}
  &enabled=${0/1}
  &server_name=${服务器名称}
```

### 3. 刷新 DLNA 内容（refresh_dlna）

```bash
GET ?func=refresh_dlna
  &sid=${sid}
```

---

## 三、视频转码（Media Library Transcode）

### 1. 创建转码任务（create_transcode）

```bash
GET ?func=create_transcode
  &sid=${sid}
  &source_path=${视频完整路径}
  &dest_path=${输出目录}
  &format=${输出格式}
  &resolution=${分辨率}
  &bitrate=${码率kbps}
  &audio_codec=${音频编码}
```

**输出格式（format）**

| 值 | 说明 |
|----|------|
| `mp4` | MP4（H.264/AAC） |
| `mkv` | MKV |
| `webm` | WebM（VP8/Vorbis） |

**分辨率（resolution）**

| 值 | 说明 |
|----|------|
| `360p` | 640×360 |
| `480p` | 854×480 |
| `720p` | 1280×720（HD） |
| `1080p` | 1920×1080（Full HD） |
| `original` | 保持原始分辨率 |

### 返回（异步）
```json
{
  "status": 1,
  "task_id": "transcode_abc123"
}
```

### 2. 查询转码进度（get_transcode_status）

```bash
GET ?func=get_transcode_status
  &sid=${sid}
  &task_id=${task_id}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "task_id": "transcode_abc123",
    "progress": 45,
    "status": "running",          // queued / running / finish / error
    "source_path": "/share/.../video.mkv",
    "dest_path": "/share/.../video_720p.mp4",
    "elapsed_seconds": 120,
    "estimated_seconds": 146
  }
}
```

### 3. 取消转码（cancel_transcode）

```bash
GET ?func=cancel_transcode
  &sid=${sid}
  &task_id=${task_id}
```

### 4. 列出转码任务（list_transcode）

```bash
GET ?func=list_transcode
  &sid=${sid}
  &status=${all/running/finish/error}
  &start=0
  &limit=50
```

---

## 四、文本编辑器（Text Editor）

### 1. 读取文本文件（read_text_file）

```bash
GET ?func=read_text_file
  &sid=${sid}
  &path=${文本文件完整路径}
  &encoding=${字符编码}    # UTF-8（默认）/ UTF-16 / GBK / BIG5 / ISO-8859-1
  &start_line=1           # 从第几行开始读（分页用）
  &line_count=200         # 读取行数
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "content": "文件内容...",
    "encoding": "UTF-8",
    "total_lines": 500,
    "start_line": 1,
    "end_line": 200
  }
}
```

### 2. 写入文本文件（write_text_file）

```bash
POST ?func=write_text_file
  &sid=${sid}
  &path=${文本文件完整路径}
  &encoding=${字符编码}

POST Body:
  content=${文件内容}
  mode=${write/append}     # write=覆盖；append=追加
```

**返回**
```json
{ "status": 1 }
```

### 3. 创建新文本文件（create_text_file）

```bash
POST ?func=create_text_file
  &sid=${sid}
  &path=${目标目录}
  &filename=${文件名}
  &encoding=${字符编码}

POST Body:
  content=${初始内容}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "path": "/share/homes/admin/note.txt"
  }
}
```

### 4. 获取支持的字符编码（get_text_encoding）

```bash
GET ?func=get_text_encoding
  &sid=${sid}
  &path=${文件路径}      # 自动检测该文件的编码
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "detected_encoding": "UTF-8",
    "supported_encodings": ["UTF-8", "UTF-16", "GBK", "BIG5", "ISO-8859-1"]
  }
}
```

---

## 五、Python 媒体与文本示例

```python
def read_log_file(host, sid, log_path, last_n_lines=100):
    """读取日志文件最后N行"""
    base_url = f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi"
    
    # 先获取总行数
    resp = requests.get(base_url, params={
        'func': 'read_text_file', 'sid': sid, 'path': log_path,
        'start_line': 1, 'line_count': 1
    })
    total_lines = resp.json().get('datas', {}).get('total_lines', 0)
    
    # 读取最后N行
    start = max(1, total_lines - last_n_lines + 1)
    resp = requests.get(base_url, params={
        'func': 'read_text_file', 'sid': sid, 'path': log_path,
        'start_line': start, 'line_count': last_n_lines
    })
    return resp.json().get('datas', {}).get('content', '')


def append_to_log(host, sid, log_path, message):
    """向日志文件追加内容"""
    base_url = f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi"
    resp = requests.post(
        f"{base_url}?func=write_text_file&sid={sid}&path={log_path}",
        data={'content': message + '\n', 'mode': 'append'}
    )
    return resp.json()
```
