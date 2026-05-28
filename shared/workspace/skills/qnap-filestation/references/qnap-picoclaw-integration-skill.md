# File Station 参考手册 10 — picoclaw Agent 完整安全集成指南

> ⚠️ 这是 picoclaw 与 QNAP NAS 交互的**权威参考**  
> 核心原则：**所有删除操作必须走回收站，绝不绕过**

---

## 一、整体架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                      picoclaw Agent 架构                         │
│                                                                 │
│  用户指令                                                        │
│     │                                                           │
│     ▼                                                           │
│  ┌─────────────────┐                                            │
│  │  QNAPClient     │  ← 统一入口，管理 sid 生命周期              │
│  │  (认证管理器)    │                                            │
│  └────────┬────────┘                                            │
│           │                                                     │
│    ┌──────┴──────────────────────────┐                          │
│    │                                │                          │
│    ▼                                ▼                          │
│  ┌──────────────┐         ┌──────────────────┐                  │
│  │  SafeDelete  │         │  FileOperations  │                  │
│  │  (回收站守卫) │         │  (复制/移动/搜索) │                  │
│  └──────────────┘         └──────────────────┘                  │
│                                                                 │
│  HTTP API → QNAP NAS (utilRequest.cgi)                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 二、完整 Python 客户端实现

```python
#!/usr/bin/env python3
"""
picoclaw QNAP HTTP API 客户端
安全地通过官方 HTTP API 管理 QNAP NAS 文件
"""

import requests
import base64
import time
import os
import json
from xml.etree import ElementTree as ET
from typing import Optional, List, Dict, Any
from dataclasses import dataclass, field


# ─────────────────────────── 数据结构 ───────────────────────────

@dataclass
class QNAPConfig:
    host: str
    port: int = 8080
    username: str = ""
    password: str = ""
    qtoken: str = ""           # 优先使用 qtoken 登录，避免每次传密码
    use_https: bool = False
    verify_ssl: bool = False
    timeout: int = 30


@dataclass
class FileItem:
    filename: str
    ftype: str                 # "file" / "dir"
    path: str
    filesize: int = 0
    mt: int = 0
    privilege: str = ""
    owner: str = ""
    is_shared: int = 0


@dataclass
class DeleteResult:
    success: bool
    pid: Optional[str] = None
    recycle_bin_used: bool = False
    warning: Optional[str] = None
    error: Optional[str] = None


# ─────────────────────────── 认证管理器 ───────────────────────────

class QNAPAuth:
    """管理 QNAP 认证会话（sid + qtoken）"""
    
    def __init__(self, config: QNAPConfig):
        self.config = config
        self.sid: Optional[str] = None
        self._session = requests.Session()
        if not config.verify_ssl:
            self._session.verify = False
            import urllib3
            urllib3.disable_warnings()
    
    @property
    def base_url(self):
        scheme = "https" if self.config.use_https else "http"
        return f"{scheme}://{self.config.host}:{self.config.port}"
    
    def _encode_password(self, pwd: str) -> str:
        return base64.b64encode(pwd.encode('utf-8')).decode('ascii')
    
    def _parse_auth_xml(self, text: str) -> dict:
        try:
            root = ET.fromstring(text)
            return {
                'auth_passed': root.findtext('authPassed') == '1',
                'sid':         root.findtext('authSid'),
                'qtoken':      root.findtext('qtoken'),
                'is_admin':    root.findtext('isAdmin') == '1',
                'need_2sv':    root.findtext('need_2sv') == '1',
            }
        except ET.ParseError:
            return {'auth_passed': False, 'error': 'XML 解析失败'}
    
    def login(self) -> bool:
        """自动选择最佳登录方式"""
        # 优先使用 qtoken
        if self.config.qtoken:
            ok = self._login_with_qtoken()
            if ok:
                return True
        # 降级为密码登录
        return self._login_with_password()
    
    def _login_with_qtoken(self) -> bool:
        resp = self._session.get(
            f"{self.base_url}/cgi-bin/authLogin.cgi",
            params={
                'user':       self.config.username,
                'qtoken':     self.config.qtoken,
                'client_app': 'picoclaw',
            },
            timeout=self.config.timeout
        )
        result = self._parse_auth_xml(resp.text)
        if result['auth_passed']:
            self.sid = result['sid']
            return True
        return False
    
    def _login_with_password(self) -> bool:
        resp = self._session.get(
            f"{self.base_url}/cgi-bin/authLogin.cgi",
            params={
                'user':       self.config.username,
                'pwd':        self._encode_password(self.config.password),
                'remme':      1,        # 获取 qtoken，下次免密
                'client_app': 'picoclaw',
                'client_agent': 'picoclaw/1.0 (NAS-Agent)',
            },
            timeout=self.config.timeout
        )
        result = self._parse_auth_xml(resp.text)
        if result['auth_passed']:
            self.sid = result['sid']
            # 保存 qtoken 以备下次使用
            if result.get('qtoken'):
                self.config.qtoken = result['qtoken']
            return True
        return False
    
    def logout(self):
        if self.sid:
            try:
                self._session.get(
                    f"{self.base_url}/cgi-bin/authLogout.cgi",
                    params={'sid': self.sid},
                    timeout=10
                )
            except Exception:
                pass
            self.sid = None
    
    def ensure_logged_in(self) -> bool:
        """确保 sid 有效，无效时自动重新登录"""
        if self.sid:
            # 快速验证 sid 是否仍有效
            try:
                resp = self._session.get(
                    f"{self.base_url}/cgi-bin/authLogin.cgi",
                    params={'sid': self.sid}, timeout=5
                )
                result = self._parse_auth_xml(resp.text)
                if result['auth_passed']:
                    return True
            except Exception:
                pass
        return self.login()


# ─────────────────────────── 回收站守卫 ───────────────────────────

class RecycleBinGuard:
    """确保所有删除操作都经过回收站的守卫类"""
    
    def __init__(self, auth: QNAPAuth):
        self.auth = auth
        self._recycle_status_cache: Dict[str, bool] = {}
        self._cache_ttl = 300    # 缓存5分钟
        self._cache_time: Dict[str, float] = {}
    
    def _api(self, params: dict) -> dict:
        params['sid'] = self.auth.sid
        resp = self.auth._session.get(
            f"{self.auth.base_url}/cgi-bin/filemanager/utilRequest.cgi",
            params=params,
            timeout=self.auth.config.timeout
        )
        return resp.json()
    
    def _get_share_path(self, file_path: str) -> str:
        """从文件完整路径提取共享文件夹路径（如 /share/homes）"""
        parts = file_path.strip('/').split('/')
        if len(parts) >= 2:
            return '/' + '/'.join(parts[:2])
        return '/' + parts[0]
    
    def is_recycle_bin_enabled(self, share_path: str) -> bool:
        """检查指定共享文件夹的回收站是否启用（带缓存）"""
        now = time.time()
        if (share_path in self._recycle_status_cache and
                now - self._cache_time.get(share_path, 0) < self._cache_ttl):
            return self._recycle_status_cache[share_path]
        
        result = self._api({'func': 'get_recyclebin_status', 'path': share_path})
        enabled = False
        if result.get('status') == 1:
            for share in result.get('datas', []):
                if share.get('enabled') == 1:
                    enabled = True
                    break
        
        self._recycle_status_cache[share_path] = enabled
        self._cache_time[share_path] = now
        return enabled
    
    def safe_delete(self, paths: List[str], strict=True) -> DeleteResult:
        """
        安全删除文件（强制走回收站）。
        
        Args:
            paths:  要删除的文件/文件夹路径列表
            strict: True=回收站未启用时拒绝执行；False=警告但继续
        
        Returns:
            DeleteResult
        """
        if not paths:
            return DeleteResult(success=False, error="路径列表为空")
        
        # 检查所有涉及的共享文件夹的回收站状态
        shares_without_recycle = []
        for path in paths:
            share = self._get_share_path(path)
            if not self.is_recycle_bin_enabled(share):
                shares_without_recycle.append(share)
        
        if shares_without_recycle:
            unique = list(set(shares_without_recycle))
            msg = f"以下共享文件夹未启用回收站：{', '.join(unique)}"
            if strict:
                return DeleteResult(
                    success=False,
                    error=f"⚠️ 操作已中止。{msg}\n"
                          f"请在 File Station → 设置 → 网络回收站 中启用。",
                    recycle_bin_used=False
                )
            warning = f"⚠️ {msg}，文件将被永久删除！"
        else:
            warning = None
        
        # 构造删除请求（force=0 确保走回收站）
        params = {'func': 'delete', 'total': len(paths), 'force': 0}
        for i, p in enumerate(paths):
            params[f'path{i}'] = p
        
        result = self._api(params)
        
        if result.get('status') != 1:
            return DeleteResult(
                success=False,
                error=f"删除失败（error_code={result.get('error_code')}）"
            )
        
        return DeleteResult(
            success=True,
            pid=result.get('pid'),
            recycle_bin_used=(len(shares_without_recycle) == 0),
            warning=warning
        )
    
    def wait_for_delete(self, pid: str, timeout=120) -> bool:
        """阻塞等待删除任务完成"""
        start = time.time()
        while time.time() - start < timeout:
            result = self._api({'func': 'get_del_status', 'pid': pid})
            if result.get('status') == 1:
                status = result.get('datas', {}).get('status')
                if status == 'finish':
                    return True
                if status == 'error':
                    return False
            time.sleep(1)
        return False
    
    def list_recycle_bin(self, share_path: str, limit=200) -> List[FileItem]:
        """列出回收站内容"""
        recycle = share_path.rstrip('/') + '/.recycle'
        result = self._api({
            'func': 'get_list', 'is_iso': 0, 'node': 'share',
            'dir': recycle, 'limit': limit
        })
        items = []
        for d in result.get('datas', []):
            items.append(FileItem(
                filename=d['filename'], ftype=d['ftype'],
                path=d['path'], filesize=d.get('filesize', 0),
                mt=d.get('mt', 0)
            ))
        return items
    
    def recover_file(self, recycle_path: str, dest_path: str) -> dict:
        """从回收站恢复文件"""
        return self._api({
            'func': 'recycle_bin_recovery',
            'path': recycle_path,
            'dest_path': dest_path
        })


# ─────────────────────────── 主客户端 ───────────────────────────

class QNAPClient:
    """picoclaw QNAP 主客户端，统一对外接口"""
    
    def __init__(self, config: QNAPConfig):
        self.config = config
        self.auth = QNAPAuth(config)
        self.recycle = RecycleBinGuard(self.auth)
    
    def connect(self) -> bool:
        return self.auth.login()
    
    def disconnect(self):
        self.auth.logout()
    
    def __enter__(self):
        self.connect()
        return self
    
    def __exit__(self, *args):
        self.disconnect()
    
    def _api(self, params: dict) -> dict:
        self.auth.ensure_logged_in()
        params['sid'] = self.auth.sid
        resp = self.auth._session.get(
            f"{self.auth.base_url}/cgi-bin/filemanager/utilRequest.cgi",
            params=params,
            timeout=self.config.timeout
        )
        return resp.json()
    
    # ── 文件列表 ──────────────────────────────────────
    
    def list_dir(self, path: str, start=0, limit=200,
                 sort='filename', order='ASC') -> dict:
        """列出目录内容"""
        return self._api({
            'func': 'get_list', 'is_iso': 0, 'node': 'share',
            'dir': path, 'start': start, 'limit': limit,
            'sort': sort, 'order': order
        })
    
    def list_all(self, path: str) -> List[FileItem]:
        """分页获取目录所有文件"""
        all_items = []
        start = 0
        limit = 200
        while True:
            result = self.list_dir(path, start=start, limit=limit)
            if result.get('status') != 1:
                break
            items = result.get('datas', [])
            for d in items:
                all_items.append(FileItem(**{
                    k: d[k] for k in
                    ['filename', 'ftype', 'path', 'filesize', 'mt', 'privilege', 'owner', 'is_shared']
                    if k in d
                }))
            total = result.get('total', 0)
            start += limit
            if start >= total:
                break
        return all_items
    
    def stat(self, path: str) -> dict:
        """获取文件/文件夹属性"""
        return self._api({'func': 'stat', 'path': path})
    
    # ── 文件操作 ──────────────────────────────────────
    
    def create_dir(self, parent_path: str, name: str) -> dict:
        return self._api({'func': 'createdir', 'dest_path': parent_path, 'dest_folder': name})
    
    def rename(self, path: str, new_name: str) -> dict:
        return self._api({'func': 'rename', 'path': path, 'newname': new_name})
    
    def copy(self, sources: List[str], dest: str, mode=2) -> dict:
        """复制文件/文件夹。mode: 0=跳过, 1=覆盖, 2=自动重命名"""
        params = {'func': 'copy', 'source_total': len(sources), 'dest_path': dest, 'mode': mode}
        for i, s in enumerate(sources):
            params['source_path' if i == 0 else f'source_path{i}'] = s
        return self._api(params)
    
    def move(self, sources: List[str], dest: str, mode=2) -> dict:
        """移动文件/文件夹"""
        params = {'func': 'move', 'source_total': len(sources), 'dest_path': dest, 'mode': mode}
        for i, s in enumerate(sources):
            params['source_path' if i == 0 else f'source_path{i}'] = s
        return self._api(params)
    
    # ── 安全删除（核心功能） ──────────────────────────
    
    def delete(self, paths: List[str], strict=True) -> DeleteResult:
        """
        ⚠️ picoclaw 的唯一删除入口 — 强制使用回收站
        
        strict=True（默认）: 回收站未启用时拒绝删除
        strict=False:       回收站未启用时警告但继续（永久删除）
        """
        self.auth.ensure_logged_in()
        result = self.recycle.safe_delete(paths, strict=strict)
        if result.success and result.pid:
            self.recycle.wait_for_delete(result.pid)
        return result
    
    def list_recycle(self, share_path: str) -> List[FileItem]:
        """列出回收站内容"""
        return self.recycle.list_recycle_bin(share_path)
    
    def recover(self, recycle_path: str, dest_path: str) -> dict:
        """从回收站恢复文件"""
        return self.recycle.recover_file(recycle_path, dest_path)
    
    # ── 搜索 ──────────────────────────────────────────
    
    def search(self, root: str, pattern: str, file_type=0) -> List[FileItem]:
        """搜索文件，等待完成后返回结果"""
        self.auth.ensure_logged_in()
        start_resp = self._api({
            'func': 'search', 'source_path': root,
            'pattern': pattern, 'file_type': file_type,
            'recursive': 1, 'limit': 500
        })
        pid = start_resp.get('pid')
        if not pid:
            return []
        
        for _ in range(60):
            time.sleep(1)
            result = self._api({'func': 'get_search_status', 'pid': pid, 'limit': 500})
            if result.get('datas', {}).get('status') == 'finish':
                return [
                    FileItem(filename=d['filename'], ftype=d['ftype'],
                             path=d['path'], filesize=d.get('filesize', 0))
                    for d in result.get('datas', {}).get('results', [])
                ]
        return []
    
    # ── 存储信息 ──────────────────────────────────────
    
    def storage_info(self) -> List[dict]:
        result = self._api({'func': 'get_storage_info'})
        return result.get('datas', [])
    
    def check_disk_warning(self, threshold=85) -> List[str]:
        """返回使用率超过阈值的存储卷名列表"""
        warnings = []
        for vol in self.storage_info():
            if vol['total'] > 0:
                pct = vol['used'] / vol['total'] * 100
                if pct >= threshold:
                    warnings.append(f"{vol['share']}: {pct:.1f}%")
        return warnings
    
    # ── 文本文件 ──────────────────────────────────────
    
    def read_text(self, path: str, start_line=1, line_count=200) -> str:
        result = self._api({
            'func': 'read_text_file', 'path': path,
            'start_line': start_line, 'line_count': line_count
        })
        return result.get('datas', {}).get('content', '')
    
    def write_text(self, path: str, content: str, mode='write') -> bool:
        self.auth.ensure_logged_in()
        resp = self.auth._session.post(
            f"{self.auth.base_url}/cgi-bin/filemanager/utilRequest.cgi",
            params={'func': 'write_text_file', 'sid': self.auth.sid, 'path': path},
            data={'content': content, 'mode': mode},
            timeout=self.config.timeout
        )
        return resp.json().get('status') == 1


# ─────────────────────────── 使用示例 ───────────────────────────

if __name__ == '__main__':
    
    # 初始化配置（建议从环境变量读取敏感信息）
    config = QNAPConfig(
        host=os.environ.get('QNAP_HOST', '192.168.1.100'),
        username=os.environ.get('QNAP_USER', 'admin'),
        password=os.environ.get('QNAP_PASS', ''),
        qtoken=os.environ.get('QNAP_QTOKEN', ''),   # 有 qtoken 时优先使用
    )
    
    # 使用 with 语句确保自动退出
    with QNAPClient(config) as client:
        
        # ✅ 1. 安全删除（自动检查回收站状态）
        print("=== 安全删除演示 ===")
        result = client.delete([
            '/share/homes/admin/临时文件.txt',
            '/share/homes/admin/旧目录/',
        ])
        if result.success:
            print(f"✅ 删除成功，回收站保护：{result.recycle_bin_used}")
        else:
            print(f"❌ 删除失败：{result.error}")
        
        # ✅ 2. 列出回收站内容
        print("\n=== 回收站内容 ===")
        items = client.list_recycle('/share/homes')
        for item in items:
            print(f"  📁 {item.filename} ({item.filesize} bytes)")
        
        # ✅ 3. 从回收站恢复
        if items:
            recover_result = client.recover(
                items[0].path,
                '/share/homes/admin/recovered/'
            )
            print(f"\n恢复结果：{recover_result}")
        
        # ✅ 4. 搜索文件
        print("\n=== 搜索 PDF 文件 ===")
        results = client.search('/share/homes', '*.pdf', file_type=1)
        for r in results[:5]:
            print(f"  📄 {r.path}")
        
        # ✅ 5. 磁盘使用告警
        print("\n=== 磁盘使用告警 ===")
        warnings = client.check_disk_warning(threshold=80)
        if warnings:
            for w in warnings:
                print(f"  ⚠️ {w}")
        else:
            print("  ✅ 所有存储卷使用率正常")
```

---

## 三、环境变量配置（推荐）

```bash
# ~/.env 或 docker-compose.yml
QNAP_HOST=192.168.1.100
QNAP_PORT=8080
QNAP_USER=admin
QNAP_PASS=your_password          # 首次登录后可删除此行，改用 qtoken
QNAP_QTOKEN=                     # 首次登录后自动填入

# 安全策略
QNAP_STRICT_DELETE=true          # true=回收站未启用时拒绝删除
QNAP_RECYCLE_CHECK_INTERVAL=300  # 回收站状态缓存时间（秒）
```

---

## 四、picoclaw 工具函数注册（LangChain/Claude Tools 风格）

```python
# 将 QNAP 操作注册为 agent 可调用的工具

QNAP_TOOLS = [
    {
        "name": "qnap_list_files",
        "description": "列出 QNAP NAS 指定目录下的文件和文件夹",
        "parameters": {
            "path": {"type": "string", "description": "目录的完整路径，如 /share/homes/admin"},
            "limit": {"type": "integer", "description": "最多返回条数，默认100"},
        },
    },
    {
        "name": "qnap_safe_delete",
        "description": "安全删除 QNAP NAS 上的文件/文件夹（通过回收站，可恢复）。注意：绝不使用永久删除。",
        "parameters": {
            "paths": {"type": "array", "items": {"type": "string"}, "description": "要删除的完整路径列表"},
        },
    },
    {
        "name": "qnap_recover_file",
        "description": "从 QNAP 回收站恢复文件到指定位置",
        "parameters": {
            "recycle_path": {"type": "string", "description": "文件在回收站中的路径"},
            "dest_path": {"type": "string", "description": "恢复到的目标目录"},
        },
    },
    {
        "name": "qnap_copy_file",
        "description": "复制 QNAP 上的文件/文件夹到另一位置",
        "parameters": {
            "sources": {"type": "array", "items": {"type": "string"}, "description": "源路径列表"},
            "dest": {"type": "string", "description": "目标目录路径"},
        },
    },
    {
        "name": "qnap_move_file",
        "description": "移动 QNAP 上的文件/文件夹到另一位置",
        "parameters": {
            "sources": {"type": "array", "items": {"type": "string"}, "description": "源路径列表"},
            "dest": {"type": "string", "description": "目标目录路径"},
        },
    },
    {
        "name": "qnap_search_files",
        "description": "在 QNAP NAS 中搜索文件（支持通配符 *）",
        "parameters": {
            "root": {"type": "string", "description": "搜索起始路径"},
            "pattern": {"type": "string", "description": "文件名关键词或通配符，如 *.pdf"},
        },
    },
    {
        "name": "qnap_list_recycle",
        "description": "列出 QNAP 回收站中的文件（查看可恢复的已删除文件）",
        "parameters": {
            "share_path": {"type": "string", "description": "共享文件夹路径，如 /share/homes"},
        },
    },
    {
        "name": "qnap_disk_status",
        "description": "检查 QNAP NAS 各存储卷的磁盘使用情况和剩余空间",
        "parameters": {},
    },
]
```

---

## 五、常见问题与注意事项

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 删除返回成功但文件消失 | 回收站未启用 | 在 File Station → 设置 → 网络回收站中启用 |
| sid 过期（401/未授权） | sid 有生命周期 | 使用 `ensure_logged_in()` 自动重新登录 |
| 中文文件名乱码 | URL 编码问题 | requests 会自动处理，但避免手动拼接 URL |
| 大文件上传超时 | 默认超时太短 | 使用分块上传，或增大 timeout 设置 |
| qtoken 失效 | NAS 重启或手动注销 | 捕获认证失败，重新用密码登录获取新 qtoken |
| HTTPS 证书错误 | 自签名证书 | 设置 `verify_ssl=False`（仅内网使用） |
| 回收站满了 | 长期未清理 | 定期调用 `clean_recyclebin` 或设置自动清理天数 |
