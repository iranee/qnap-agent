# File Station 参考手册 07 — 高级文件搜索、压缩与解压

> 接口基础 URL：`http://IP:8080/cgi-bin/filemanager/utilRequest.cgi`

---

## 一、高级文件搜索（Advanced File Search）

### 1. 发起搜索（search）

```
GET ?func=search
  &sid=${sid}
  &source_path=${搜索起始路径}     # 例：/share/homes
  &search_type=${搜索类型}
  &pattern=${关键词}               # 文件名关键词（支持 * 通配符）
  &start=0
  &limit=100
  &sort=filename
  &order=ASC
  &recursive=${0/1}               # 1=递归子目录
  &file_type=${文件类型过滤}
  &size_from=${最小字节}
  &size_to=${最大字节}
  &date_from=${起始日期 YYYY-MM-DD}
  &date_to=${结束日期 YYYY-MM-DD}
```

**搜索类型（search_type）**

| 值 | 说明 |
|----|------|
| `0` | 按文件名搜索（默认） |
| `1` | 全文检索（需安装全文搜索套件） |
| `2` | 按标签搜索 |

**文件类型过滤（file_type）**

| 值 | 说明 |
|----|------|
| `0` | 全部 |
| `1` | 文档（doc/pdf/xls/ppt等） |
| `2` | 图片（jpg/png/gif等） |
| `3` | 视频（mp4/avi/mkv等） |
| `4` | 音乐（mp3/flac/aac等） |
| `5` | 压缩文件（zip/rar/7z等） |

### 返回（异步）
```json
{
  "status": 1,
  "pid": "77001"
}
```

### 查询搜索结果（get_search_status）
```
GET ?func=get_search_status
  &sid=${sid}
  &pid=${pid}
  &start=0
  &limit=100
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "pid": "77001",
    "status": "finish",          // searching / finish
    "total": 23,
    "results": [
      {
        "filename": "report_2024.pdf",
        "ftype": "file",
        "filesize": 204800,
        "mt": 1700000000,
        "path": "/share/homes/admin/reports/report_2024.pdf"
      }
    ]
  }
}
```

### 取消搜索（cancel_search）
```
GET ?func=cancel_search
  &sid=${sid}
  &pid=${pid}
```

### Python 搜索示例
```python
import requests, time

def search_files(host, sid, root_path, pattern, file_type=0):
    """搜索文件"""
    base_url = f"http://{host}:8080/cgi-bin/filemanager/utilRequest.cgi"
    
    # 发起搜索
    resp = requests.get(base_url, params={
        'func': 'search',
        'sid': sid,
        'source_path': root_path,
        'pattern': pattern,
        'file_type': file_type,
        'recursive': 1,
        'limit': 200,
    })
    pid = resp.json().get('pid')
    
    # 等待完成
    for _ in range(30):
        time.sleep(1)
        resp = requests.get(base_url, params={
            'func': 'get_search_status', 'sid': sid, 'pid': pid, 'limit': 200
        })
        data = resp.json().get('datas', {})
        if data.get('status') == 'finish':
            return data.get('results', [])
    
    return []

# 例：搜索所有 PDF 文件
results = search_files('192.168.1.100', 'my_sid', '/share/homes', '*.pdf', file_type=1)
for r in results:
    print(f"  {r['path']} ({r['filesize']} bytes)")
```

---

## 二、压缩文件（Compress）

### 1. 创建压缩任务（compress）

```
GET ?func=compress
  &sid=${sid}
  &source_total=${数量}
  &source_path=${源路径}          # 路径无索引（单个）
  &source_path1=${第二个路径}
  &dest_path=${目标目录}
  &dest_name=${压缩包文件名}       # 含扩展名，例：archive.zip
  &type=${压缩格式}
  &level=${压缩级别}
  &password=${压缩密码}           # 可选
  &encrypt_type=${加密类型}
```

**压缩格式（type）**

| 值 | 说明 |
|----|------|
| `zip` | ZIP 格式 |
| `tar` | TAR 格式 |
| `tgz` | TAR.GZ 格式 |
| `7z` | 7-Zip 格式（支持加密） |

**压缩级别（level）**

| 值 | 说明 |
|----|------|
| `0` | 仅打包，不压缩 |
| `1` | 最快（压缩率低） |
| `5` | 正常（默认） |
| `9` | 最佳压缩（速度慢） |

**加密类型（encrypt_type，仅7z有效）**

| 值 | 说明 |
|----|------|
| `0` | 不加密 |
| `1` | AES-128 |
| `2` | AES-256 |

### 返回（异步）
```json
{
  "status": 1,
  "pid": "88001"
}
```

### 查询压缩进度（get_compress_status）
```
GET ?func=get_compress_status
  &sid=${sid}
  &pid=${pid}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "pid": "88001",
    "progress": 75,
    "status": "running",        // running / finish / error
    "dest_path": "/share/homes/admin/archive.zip",
    "current_file": "video.mp4"
  }
}
```

### 取消压缩（cancel_compress）
```
GET ?func=cancel_compress
  &sid=${sid}
  &pid=${pid}
```

---

## 三、解压文件（Extract）

### 1. 列出压缩包内容（list_extract）

```
GET ?func=list_extract
  &sid=${sid}
  &path=${压缩包完整路径}
  &password=${解压密码}      # 若有密码保护
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "total": 15,
    "files": [
      {
        "filename": "document.pdf",
        "ftype": "file",
        "filesize": 204800,
        "compressed_size": 180000,
        "compression_ratio": 0.88,
        "mt": 1700000000,
        "path": "docs/document.pdf"   // 压缩包内相对路径
      }
    ]
  }
}
```

### 2. 执行解压（extract）

```
GET ?func=extract
  &sid=${sid}
  &path=${压缩包完整路径}
  &dest_path=${解压目标目录}
  &password=${解压密码}
  &overwrite=${0/1}               # 0=跳过；1=覆盖
  &selected_path=${指定解压的文件} # 可选，只解压部分文件（相对路径）
  &create_sub_folder=${0/1}       # 1=在目标目录下自动创建同名子文件夹
```

### 返回（异步）
```json
{
  "status": 1,
  "pid": "99001"
}
```

### 查询解压进度（get_extract_status）
```
GET ?func=get_extract_status
  &sid=${sid}
  &pid=${pid}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "pid": "99001",
    "progress": 50,
    "status": "running",
    "current_file": "large_video.mp4",
    "total_count": 15,
    "finish_count": 7
  }
}
```

### 取消解压（cancel_extract）
```
GET ?func=cancel_extract
  &sid=${sid}
  &pid=${pid}
```

---

## 四、图片旋转（rotate_image）

### 请求
```
GET ?func=rotate_image
  &sid=${sid}
  &path=${图片完整路径}
  &angle=${旋转角度}      # 90 / 180 / 270
  &overwrite=${0/1}      # 1=覆盖原图；0=另存
  &dest_path=${另存目标} # overwrite=0 时必填
```

### 返回
```json
{
  "status": 1,
  "datas": {
    "path": "/share/homes/admin/photo_rotated.jpg"
  }
}
```
