# File Station 参考手册 03 — 网络回收站（安全删除核心）

> ⚠️ **这是 picoclaw Agent 最重要的参考文档**  
> SSH/命令行删除文件 = 永久丢失，无法恢复  
> 通过 HTTP API（`force=0`）删除文件 = 进入回收站，可恢复  
> 本文档涵盖回收站的完整 API 操作。

---

## 回收站工作原理

```
┌─────────────────────────────────────────────────────────────┐
│                      文件删除决策树                           │
│                                                             │
│  picoclaw 发起删除请求                                        │
│          │                                                  │
│          ▼                                                  │
│   force=0 (默认) ─────────────────┐                         │
│          │                       │                         │
│          ▼                       │                         │
│   回收站是否已启用？               │ force=1                 │
│    ├── 是 → 移入 .recycle/  ✅    │ ⚠️ 永久删除，禁止！      │
│    └── 否 → 直接删除！  ⚠️        └──────────────────────   │
│                                                             │
│  回收站路径：每个共享文件夹下的 .recycle/ 隐藏文件夹           │
│  例：/share/homes/admin/.recycle/                           │
└─────────────────────────────────────────────────────────────┘
```

---

## 前置条件：确认并启用回收站

在使用回收站 API 之前，必须先在 NAS 的 File Station 设置中启用每个共享文件夹的"网络回收站"。  
也可通过 API 查询状态（见下方"获取回收站状态"）。

---

## 1. 获取回收站文件树（get_tree + recycle_root）

> 列出所有共享文件夹中的回收站内容。

### 请求
```
GET ?func=get_tree
  &sid=${sid}
  &node=recycle_root          # 固定值，指定回收站根节点
  &is_iso=0
```

### 返回
```json
{
  "status": 1,
  "datas": [
    {
      "text": "homes",             // 共享文件夹名
      "id": "/share/homes",
      "recycle_path": "/share/homes/.recycle",
      "has_child": true,
      "file_count": 12,            // 回收站内文件数量
      "size": 10485760             // 回收站总占用字节
    },
    {
      "text": "Public",
      "id": "/share/Public",
      "recycle_path": "/share/Public/.recycle",
      "has_child": false,
      "file_count": 0,
      "size": 0
    }
  ]
}
```

---

## 2. 浏览回收站内容（get_list）

> 列出某个共享文件夹回收站中的具体文件。

### 请求
```
GET ?func=get_list
  &sid=${sid}
  &is_iso=0
  &node=share
  &dir=/share/homes/.recycle    # 回收站路径
  &limit=${每页数量，默认100}
  &start=${起始偏移，默认0}
  &sort=filename                # 排序字段：filename/mt/filesize/ftype
  &order=ASC                    # ASC / DESC
```

### 返回
```json
{
  "status": 1,
  "total": 5,
  "datas": [
    {
      "filename": "旧文档.docx",
      "ftype": "file",
      "filesize": 51200,
      "mt": 1700000000,
      "path": "/share/homes/.recycle/旧文档.docx",
      "original_path": "/share/homes/admin/旧文档.docx"  // 原始位置（部分版本支持）
    }
  ]
}
```

---

## 3. 从回收站恢复文件（recycle_bin_recovery）

> 将回收站中的文件/文件夹恢复到指定位置。

### 请求
```
GET ?func=recycle_bin_recovery
  &sid=${sid}
  &path=${回收站中的文件路径}      # 例：/share/homes/.recycle/旧文档.docx
  &dest_path=${恢复目标路径}       # 例：/share/homes/admin（不含文件名）
```

### 批量恢复（多个文件）
```
GET ?func=recycle_bin_recovery
  &sid=${sid}
  &path0=/share/homes/.recycle/file1.txt
  &path1=/share/homes/.recycle/file2.docx
  &total=2
  &dest_path=/share/homes/admin
```

### 返回（异步）
```json
{
  "status": 1,
  "pid": "55001"
}
```

### 查询恢复进度
```
GET ?func=get_recycle_bin_recovery_status
  &sid=${sid}
  &pid=${pid}
```

**返回**
```json
{
  "status": 1,
  "datas": {
    "pid": "55001",
    "progress": 100,
    "total_count": 1,
    "finish_count": 1,
    "status": "finish",      // running / finish / error
    "error_files": []
  }
}
```

---

## 4. 取消恢复操作（cancel_recycle_bin_recovery）

```
GET ?func=cancel_recycle_bin_recovery
  &sid=${sid}
  &pid=${pid}
```

**返回**
```json
{ "status": 1 }
```

---

## 5. 清理单个共享文件夹的回收站（clean_recyclebin）

> 清空指定共享文件夹的回收站内容。执行后**不可恢复**，请谨慎使用。

### 请求
```
GET ?func=clean_recyclebin
  &sid=${sid}
  &path=${共享文件夹路径}          # 例：/share/homes（不是 .recycle 路径）
```

### 返回
```json
{
  "status": 1,
  "datas": {
    "cleaned_count": 12,
    "cleaned_size": 10485760
  }
}
```

---

## 6. 清空所有回收站（empty_all_recyclebin）

> QTS 4.4.1+ 支持。一次性清空所有共享文件夹的回收站。

### 请求
```
GET ?func=empty_all_recyclebin
  &sid=${sid}
```

### 返回
```json
{
  "status": 1,
  "datas": {
    "total_cleaned_count": 45,
    "total_cleaned_size": 524288000
  }
}
```

---

## 7. 获取回收站状态（get_recyclebin_status）

> 查询各共享文件夹的回收站启用情况与占用统计。

### 请求
```
GET ?func=get_recyclebin_status
  &sid=${sid}
  &path=${共享文件夹路径}          # 可选，不传则返回所有
```

### 返回
```json
{
  "status": 1,
  "datas": [
    {
      "share": "homes",
      "path": "/share/homes",
      "enabled": 1,             // ⚠️ 1=启用；0=未启用（未启用时删除=永久丢失）
      "size": 10485760,         // 当前回收站占用字节
      "file_count": 12,
      "auto_clean": 1,          // 是否自动清理（超过设定天数自动删除）
      "auto_clean_days": 30     // 自动清理天数
    }
  ]
}
```

---

## 8. picoclaw 完整安全删除实现

```python
import requests
import time
from xml.etree import ElementTree as ET

class QNAPSafeFileManager:
    """picoclaw 安全文件管理器 — 确保删除操作走回收站"""
    
    def __init__(self, host, sid, port=8080):
        self.base_url = f"http://{host}:{port}/cgi-bin/filemanager/utilRequest.cgi"
        self.sid = sid
    
    def _get(self, params):
        params['sid'] = self.sid
        resp = requests.get(self.base_url, params=params)
        return resp.json()
    
    def check_recycle_bin_enabled(self, share_path: str) -> bool:
        """在删除前检查该共享文件夹的回收站是否已启用"""
        result = self._get({'func': 'get_recyclebin_status', 'path': share_path})
        if result.get('status') != 1:
            return False
        for share in result.get('datas', []):
            if share.get('enabled') == 1:
                return True
        return False
    
    def safe_delete(self, paths: list, force_if_no_recycle=False) -> dict:
        """
        安全删除文件/文件夹。
        
        Args:
            paths: 要删除的完整路径列表
            force_if_no_recycle: 回收站未启用时是否继续（False=拒绝执行，True=仍然删除）
        
        Returns:
            {'success': bool, 'pid': str, 'warning': str}
        """
        if not paths:
            return {'success': False, 'error': '路径列表为空'}
        
        # 检查回收站状态
        share_path = '/' + '/'.join(paths[0].strip('/').split('/')[:2])
        recycle_enabled = self.check_recycle_bin_enabled(share_path)
        
        if not recycle_enabled:
            if not force_if_no_recycle:
                return {
                    'success': False,
                    'error': f'⚠️ 回收站未启用于 {share_path}，操作已中止。请先在 File Station 中启用网络回收站。',
                    'recycle_bin_enabled': False
                }
            else:
                warning = f'⚠️ 警告：{share_path} 回收站未启用，文件将被永久删除！'
        else:
            warning = None
        
        # 构造删除请求（force=0，确保走回收站）
        params = {
            'func': 'delete',
            'total': len(paths),
            'force': 0,          # ⚠️ 永远是 0
        }
        for i, path in enumerate(paths):
            params[f'path{i}'] = path
        
        result = self._get(params)
        
        if result.get('status') != 1:
            return {'success': False, 'error': result.get('error_code', '未知错误')}
        
        pid = result.get('pid')
        return {
            'success': True,
            'pid': pid,
            'warning': warning,
            'recycle_bin_enabled': recycle_enabled,
            'message': f'文件已移入回收站（pid={pid}）' if recycle_enabled else f'文件已删除（无回收站保护）',
        }
    
    def wait_for_delete(self, pid: str, timeout=60) -> dict:
        """等待删除任务完成"""
        start = time.time()
        while time.time() - start < timeout:
            result = self._get({'func': 'get_del_status', 'pid': pid})
            if result.get('status') == 1:
                data = result.get('datas', {})
                if data.get('status') == 'finish':
                    return {'done': True, 'error_files': data.get('error_files', [])}
                elif data.get('status') == 'error':
                    return {'done': False, 'error': '删除任务失败'}
            time.sleep(1)
        return {'done': False, 'error': '超时'}
    
    def recover_from_recycle(self, recycle_path: str, dest_path: str) -> dict:
        """从回收站恢复文件"""
        result = self._get({
            'func': 'recycle_bin_recovery',
            'path': recycle_path,
            'dest_path': dest_path,
        })
        return result
    
    def list_recycle_bin(self, share_path: str) -> list:
        """列出指定共享文件夹回收站中的内容"""
        recycle_path = share_path.rstrip('/') + '/.recycle'
        result = self._get({
            'func': 'get_list',
            'is_iso': 0,
            'node': 'share',
            'dir': recycle_path,
        })
        return result.get('datas', [])


# ===================== 使用示例 =====================

if __name__ == '__main__':
    manager = QNAPSafeFileManager('192.168.1.100', 'my_sid_token')
    
    # ✅ 安全删除（走回收站）
    result = manager.safe_delete([
        '/share/homes/admin/旧文件.txt',
        '/share/homes/admin/临时目录/',
    ])
    print(result)
    # {'success': True, 'pid': '55002', 'message': '文件已移入回收站（pid=55002）'}
    
    # 如果回收站未启用，会直接拒绝：
    # {'success': False, 'error': '⚠️ 回收站未启用于 /share/homes，操作已中止。'}
    
    # 等待完成
    if result['success']:
        done = manager.wait_for_delete(result['pid'])
        print(done)
    
    # 列出回收站
    items = manager.list_recycle_bin('/share/homes')
    for item in items:
        print(f"  回收站: {item['filename']} ({item['filesize']} bytes)")
    
    # 从回收站恢复
    recover_result = manager.recover_from_recycle(
        '/share/homes/.recycle/旧文件.txt',
        '/share/homes/admin/已恢复/'
    )
    print(recover_result)
```

---

## 9. 注意事项与最佳实践

| 场景 | 推荐做法 |
|------|---------|
| picoclaw 删除任何文件 | 永远使用 `force=0` + 检查回收站状态 |
| 回收站未启用 | 中止操作，提示用户先在 File Station → 设置 → 网络回收站中启用 |
| 定期维护 | 可设置自动清理（30天），避免回收站占满磁盘 |
| 大量文件删除 | 使用批量 `path0...pathN`，一次请求，减少 API 调用次数 |
| SSH/Terminal 误删 | 立即停止操作，检查 .recycle 目录（`ls /share/homes/.recycle/`），用 API 恢复 |
| 跨共享文件夹删除 | 每个共享文件夹需单独检查回收站启用状态 |
