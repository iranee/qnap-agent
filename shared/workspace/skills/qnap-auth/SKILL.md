---
name: qnap-auth
description: QNAP QTS HTTP API 身份验证技能包。当需要与 QNAP NAS 进行 HTTP API 交互、获取 sid 会话令牌、处理登录认证、双重验证（2SV）、qtoken 管理、或退出登录时，必须使用此技能包。适用于所有 picoclaw agent 与 QNAP 设备通信的场景。本技能包基于官方白皮书 QTS HTTP API – Authentication v5.1.0（2024年1月）。
---

# QNAP QTS HTTP API — 身份验证技能包

> 官方白皮书：QTS HTTP API – Authentication v5.1.0（2024/1/9）  
> 所有 QNAP HTTP API 调用都必须先通过身份验证，获得 `sid`（会话令牌）后才能执行任何操作。

---

## 核心概念

| 概念 | 说明 |
|------|------|
| `sid` | 会话令牌，每次 API 调用都需要附带 |
| `qtoken` | 持久化令牌，用于"记住我"场景，可换取 `sid` |
| `2SV` | 两步验证（Two-Step Verification），启用后需额外验证 |
| 默认端口 | `8080`（HTTP），`443`（HTTPS） |
| 编码规则 | 密码需 Base64 编码：`encode_string = ezEncode(utf16to8(real_password))`，**注意必须先转 UTF-16-LE，不是 UTF-8** |

---

## 1. 标准密码登录（获取 sid）

### 接口说明
通过用户名+密码登录，获取 `sid` 用于后续 API 调用。

### 请求命令（两种方式）

**方式一：Base64 编码密码**
```
GET http://IP:8080/cgi-bin/authLogin.cgi
  ?user=${username}
  &pwd=${encode_string}          # Base64编码后的密码
  &remme=${remme}                # 1=返回qtoken；0=清除qtoken
  &service=${service}            # 可选，指定服务
  &remote_ip=${remote_ip}        # 可选，仅限localhost调用时指定来源IP
  &device=${device}              # 可选，客户端设备名
  &force_to_check_2sv=${flag}    # 可选，1=强制检查两步验证
  &client_id=${uuid}             # 客户端生成的UUID
  &client_app=${app_name}        # 应用名称（如 picoclaw）
  &client_agent=${agent_str}     # User-Agent字符串
  &gen_client_id=${flag}         # 服务端返回UUID后客户端复用
  &duration=${days}              # token有效期（天），默认90，最小1，-1=永不过期
```

**方式二：明文密码（仅适用于本机 127.0.0.1 调用）**
```
GET http://127.0.0.1:8080/cgi-bin/authLogin.cgi
  ?user=${username}
  &plain_pwd=${password}         # 明文密码
  &remote_ip=${real_remote_ip}   # 实际来源IP
  &device=${device}
```

### 参数详解

| 参数 | 必填 | 说明 |
|------|------|------|
| `user` | 是 | 登录用户名 |
| `pwd` | 是（方式一）| Base64编码密码。若密码为"admin"，编码后为`YWRtaW4%3D` |
| `plain_pwd` | 是（方式二）| 明文密码，仅本机调用时可用 |
| `remme` | 否 | `1`=返回qtoken；`0`=清除qtoken |
| `renew` | 否 | `1`=重新生成qtoken并返回；`0`=不返回 |
| `service` | 否 | 服务代码：`5`=Qsync；`99`=强制检查2SV；`100`+=不生成sid；`101`=Photo Station；`102`=Music Station；`103`=Video Station |
| `force_to_check_2sv` | 否 | `1`=强制检查两步验证（包括127.0.0.1请求） |
| `remote_ip` | 否 | 仅本机请求时指定实际来源IP |
| `device` | 否 | 客户端设备名 |
| `client_id` | 否 | 客户端UUID |
| `client_app` | 否 | 应用名，例如 `picoclaw`、`Qmanager`；WebUI登录时值为 `Web Login` |
| `client_agent` | 否 | 格式：`{app_name}/{version} ({OS} {OS_version}, {device})` 例：`picoclaw/1.0 (Linux 5.4, NAS-Agent)` |
| `gen_client_id` | 否 | 服务端返回UUID，客户端需复用该值 |
| `duration` | 否 | token有效期天数，需配合`client_id`使用；默认90；最小1；-1=永不过期 |
| `vtoken` | 否 | 跳过两步验证的临时令牌 |

### 返回值

**成功示例**
```xml
<?xml version="1.0" encoding="UTF-8" ?>
<QDocRoot version="1.0">
  <qtoken><![CDATA[1e29b890910e8135f1692ed4030256fe]]></qtoken>  <!-- remme=1时返回 -->
  <authPassed><![CDATA[1]]></authPassed>
  <authSid><![CDATA[ral08opo]]></authSid>   <!-- 这就是sid，service<100时返回 -->
  <isAdmin><![CDATA[1]]></isAdmin>
</QDocRoot>
```

**失败示例**
```xml
<QDocRoot version="1.0">
  <qtoken>1e29b890910e8135f1692ed4030256fe</qtoken>
  <authPassed>0</authPassed>
  <errorValue>-1</errorValue>
</QDocRoot>
```

**返回字段说明**

| 字段 | 说明 |
|------|------|
| `authPassed` | `1`=成功，`0`=失败 |
| `authSid` | 会话令牌 sid（service<100 时返回） |
| `qtoken` | 持久化令牌（remme=1 时返回） |
| `isAdmin` | `1`=管理员，`0`=普通用户 |
| `en_qrlogin` | `0/1`，用户是否启用二维码登录 |
| `force_qrlogin` | `0/1`，是否强制使用二维码登录 |
| `user_pw_expiry` | `0/1`，密码是否过期 |
| `force_2sv` | `0/1`，是否需要强制两步验证 |

**errorValue 错误码**

| 值 | 说明 |
|----|------|
| `0` | 成功 |
| `-1` | 失败 |
| `-2` | 非管理员 |
| `-3` | 管理员密码已过期 |
| `-4` | 密码已过期 |

### 完整示例

```
# 实际密码为 "admin" → Base64编码后为 YWRtaW4=，URL编码后为 YWRtaW4%3D
GET http://192.168.1.100:8080/cgi-bin/authLogin.cgi?user=admin&pwd=YWRtaW4%3D&remme=1

# 本机明文密码登录（picoclaw 内网调用推荐方式）
GET http://127.0.0.1:8080/cgi-bin/authLogin.cgi?plain_pwd=admin&user=admin&remote_ip=192.168.1.200&device=picoclaw
```

---

## 2. 通过 qtoken 登录（获取 sid）

### 接口说明
使用已保存的 qtoken 换取新的 sid，适合无需每次输入密码的长期运行 agent。

### 请求命令
```
GET http://IP:8080/cgi-bin/authLogin.cgi
  ?user=${username}
  &qtoken=${qtoken}
  &remme=${remme}
  &client_id=${uuid}
  &client_app=${app_name}
  &client_agent=${agent_str}
  &gen_client_id=${flag}
  &duration=${days}
  &vtoken=${vtoken}
```

### 返回值

**成功**
```xml
<QDocRoot version="1.0">
  <authPassed><![CDATA[1]]></authPassed>
  <authSid><![CDATA[ral08opo]]></authSid>
  <isAdmin><![CDATA[1]]></isAdmin>
</QDocRoot>
```

**qtoken 相关返回字段**

| 字段 | 说明 |
|------|------|
| `user_pw_expiry` | 密码是否过期 |
| `force_2sv` | 是否需要两步验证 |
| `user_enable` | `1`=账户启用；`0`=账户禁用 |
| `user_account_expiry` | `1`=账户已过期；`0`=未过期 |
| `user_expiry_year/month/day` | 账户过期的年/月/日 |

---

## 3. 两步验证登录（2SV）

> 当 NAS 启用两步验证时，需要分两步完成登录。  
> 注意：从 127.0.0.1 发起的 HTTP 请求可以绕过两步验证直接获取 sid。

### 3.1 第一步：密码验证

与标准登录相同，但返回值中包含 `need_2sv=1`，表示需要继续第二步。

**请求**
```
GET http://IP:8080/cgi-bin/authLogin.cgi
  ?user=${username}
  &pwd=${encode_string}
  &remme=${remme}
  &serviceKey=1
  &client_id=${uuid}
  &client_app=${app_name}
  &client_agent=${agent_str}
```

**返回示例（需要2SV）**
```xml
<QDocRoot version="1.0">
  <authPassed>0</authPassed>     <!-- 第一步未完成，authPassed=0 -->
  <need_2sv>1</need_2sv>         <!-- 需要两步验证 -->
  <lost_phone>1</lost_phone>     <!-- 1=可发送应急邮件；2=安全问题验证 -->
  <emergency_try_count>0</emergency_try_count>
  <emergency_try_limit>5</emergency_try_limit>
  <username>admin</username>
</QDocRoot>
```

**第一步返回字段说明**

| 字段 | 类型 | 说明 |
|------|------|------|
| `authPassed` | int | 第一步密码验证：`0`=需要继续2SV；`1`=已通过（无需2SV） |
| `need_2sv` | int | `1`=需要两步验证 |
| `lost_phone` | int | `1`=可发送应急邮件（8位数字码）；`2`=安全问题验证 |
| `emergency_try_count` | int | 已尝试次数 |
| `emergency_try_limit` | int | 最大尝试次数（默认5） |

### 3.2 第二步：安全码验证

**请求**
```
GET http://IP:8080/cgi-bin/authLogin.cgi
  ?user=${username}
  &pwd=${encode_string}
  &remme=${remme}
  &security_code=${code}         # 6位安全码，或8位应急码
  &dont_verify_2sv_again=${0/1}  # 必须提供此参数；1=下次不再验证
  &serviceKey=1
  &client_id=${uuid}
  &client_app=${app_name}
  &client_agent=${agent_str}
  &duration=${days}
```

**成功返回**
```xml
<QDocRoot version="1.0">
  <authPassed>1</authPassed>
  <authSid>mxz01een</authSid>    <!-- 获得最终 sid -->
  <need_2sv>1</need_2sv>
  <isAdmin>1</isAdmin>
  <vtoken>xxxxxxxx</vtoken>      <!-- 后续可跳过2SV的令牌 -->
</QDocRoot>
```

**失败返回（错误安全码）**
```xml
<QDocRoot version="1.0">
  <authPassed>0</authPassed>
  <need_2sv>1</need_2sv>
  <emergency_try_count>1</emergency_try_count>
  <emergency_try_limit>5</emergency_try_limit>
</QDocRoot>
```

**第二步返回字段说明**

| 字段 | 类型 | 说明 |
|------|------|------|
| `authPassed` | int | `1`=成功；`0`=失败 |
| `vtoken` | string | 后续调用可携带此令牌跳过2SV |
| `timezone` | string | 时区，如 `(GMT+08:00) Taipei` |
| `timestamp` | int | Unix 时间戳（秒） |
| `date_format_index` | int | 日期格式索引（1=年/月/日，4=月/日/年，7=日/月/年等） |
| `time_format` | int | `24`=24小时制；`12`=12小时制 |

### 3.3 发送应急邮件（lost_phone=1 时）

**请求**
```
GET http://IP:8080/cgi-bin/authLogin.cgi
  ?user=${username}
  &pwd=${encode_string}
  &send_mail=1
  &remme=${remme}
  &serviceKey=1
```

**返回**
```xml
<QDocRoot version="1.0">
  <send_result>1</send_result>          <!-- 1=发送成功；0=失败；-1=未启用邮件通知 -->
  <emergency_try_count>3</emergency_try_count>
  <emergency_try_limit>5</emergency_try_limit>
</QDocRoot>
```

### 3.4 获取安全问题（lost_phone=2 时）

**请求**
```
GET http://IP:8080/cgi-bin/authLogin.cgi
  ?user=${username}
  &pwd=${encode_string}
  &get_question=1
  &serviceKey=1
  &q_lang=${lang}   # 可选：ENG/SCH/TCH/JPN/KOR 等
```

**返回**
```xml
<QDocRoot version="1.0">
  <security_question_no>4</security_question_no>   <!-- 1-3为预设题；4=自定义 -->
  <security_question_text>how are you?</security_question_text>  <!-- 自定义题目文本 -->
</QDocRoot>
```

**预设题号**
- `1` = "What is your pet's name?"
- `2` = "What is your favorite sport?"
- `3` = "What is your favorite color?"
- `4` = 自定义题目

### 3.5 安全问题验证

**请求**
```
GET http://IP:8080/cgi-bin/authLogin.cgi
  ?user=${username}
  &pwd=${encode_string}
  &security_answer=${answer}
  &dont_verify_2sv_again=${0/1}
  &serviceKey=1
  &client_id=${uuid}
  &client_app=${app_name}
  &client_agent=${agent_str}
```

**成功返回**
```xml
<QDocRoot version="1.0">
  <authPassed>1</authPassed>
  <authSid>m9x71gxw</authSid>
  <isAdmin>1</isAdmin>
</QDocRoot>
```

---

## 4. 使用 sid 验证会话（Login with sid）

### 接口说明
验证 sid 是否有效，并获取设备详细信息。

### 请求命令
```
GET http://IP:8080/cgi-bin/authLogin.cgi?sid=${sid}
```

### 完整返回字段说明

| 字段 | 说明 |
|------|------|
| `authPassed` | `1`=sid有效；`0`=sid无效 |
| `isAdmin` | 是否管理员 |
| `user` / `username` | 用户名 |
| `userid` | 用户ID |
| `userType` | `local`=本地用户 |
| `force_change_pw` | 是否强制改密码 |
| `model/modelName` | 设备型号（如 TS-670） |
| `model/platform` | 平台（如 TS-NASX86） |
| `firmware/version` | 固件版本 |
| `firmware/build` | 固件构建号 |
| `hostname` | NAS 主机名 |
| `HTTPHost` | NAS HTTP 访问地址 |
| `webAccessPort` | Web 访问端口（默认8080） |
| `stunnelPort` | SSL 端口（默认443） |
| `wfmURL` | File Station URL |
| `connet_ip` | 客户端连接来源IP |
| `role_delegation` | 角色委派信息（权限列表） |

**角色委派 ID 含义**

| ID | 角色 |
|----|------|
| 1 | System Management（系统管理） |
| 2 | Application Management（应用管理） |
| 3 | Access Management（访问管理） |
| 4 | System Monitoring（系统监控） |
| 5 | User and Group Management（用户与组管理） |
| 6 | Shared Folder Management（共享文件夹管理） |
| 7 | Backup Management（备份管理） |

---

## 5. 退出登录（Logout）

### 请求命令
```
GET http://IP:8080/cgi-bin/authLogout.cgi?sid=${sid}
```

### 扩展参数

| 参数 | 说明 |
|------|------|
| `logout` | `1`=执行退出 |
| `sid` | 要退出的 sid |
| `del_user_session` | `1`=删除该用户所有sid和qtoken；`2`=仅删除sid；`3`=删除sid和qtoken（保留QNAP Authenticator的qtoken） |
| `del_client` | 验证qtoken后删除指定客户端的qtoken |
| `qtoken` | 要删除的 qtoken（配合 del_client 使用） |
| `client_id` | 要删除qtoken的客户端ID（配合 del_client 使用） |
| `user` | 要删除qtoken的用户名（配合 del_client 使用） |

### 返回值
```xml
<QDocRoot version="1.0">
  <authPassed><![CDATA[0]]></authPassed>
</QDocRoot>
```

---

## 6. picoclaw Agent 推荐实现方案

### 认证策略选择

```
场景一：短期任务（推荐）
  → 每次任务开始时用 plain_pwd 本机登录 → 获取 sid → 执行操作 → 退出

场景二：长期运行 Agent（推荐）
  → 首次用密码登录，设 remme=1 获取 qtoken
  → 将 qtoken 安全存储（加密保存）
  → 后续每次用 qtoken 换取新 sid
  → sid 过期后自动用 qtoken 重新登录

场景三：NAS 本机运行
  → 使用 plain_pwd + remote_ip 方式，无需密码编码
  → 最安全，适合 picoclaw 直接部署在 NAS 上
```

### Python 示例代码

```python
import requests
import base64
from xml.etree import ElementTree as ET

class QNAPAuth:
    def __init__(self, host, port=8080):
        self.base_url = f"http://{host}:{port}"
        self.sid = None
        self.qtoken = None
    
    def _encode_password(self, password: str) -> str:
        """QNAP 专用密码编码：先转 UTF-16-LE，再 Base64
        
        注意：必须用 UTF-16-LE，不能用 UTF-8。
        错误（ASCII 密码碰巧正确，中文密码失败）：base64.b64encode(pwd.encode('utf-8'))
        正确：base64.b64encode(pwd.encode('utf-16-le'))
        """
        return base64.b64encode(password.encode('utf-16-le')).decode('ascii')
    
    def login(self, username: str, password: str, remember=True) -> dict:
        """标准密码登录"""
        encoded_pwd = self._encode_password(password)
        params = {
            'user': username,
            'pwd': encoded_pwd,
            'remme': 1 if remember else 0,
            'client_app': 'picoclaw',
            'client_agent': 'picoclaw/1.0 (Linux, NAS-Agent)',
        }
        resp = requests.get(f"{self.base_url}/cgi-bin/authLogin.cgi", params=params)
        root = ET.fromstring(resp.text)
        
        result = {
            'auth_passed': root.findtext('authPassed') == '1',
            'sid': root.findtext('authSid'),
            'qtoken': root.findtext('qtoken'),
            'is_admin': root.findtext('isAdmin') == '1',
            'need_2sv': root.findtext('need_2sv') == '1',
        }
        
        if result['auth_passed']:
            self.sid = result['sid']
            self.qtoken = result['qtoken']
        
        return result
    
    def login_with_qtoken(self, username: str, qtoken: str) -> dict:
        """使用 qtoken 换取 sid"""
        params = {
            'user': username,
            'qtoken': qtoken,
            'client_app': 'picoclaw',
        }
        resp = requests.get(f"{self.base_url}/cgi-bin/authLogin.cgi", params=params)
        root = ET.fromstring(resp.text)
        
        if root.findtext('authPassed') == '1':
            self.sid = root.findtext('authSid')
            return {'auth_passed': True, 'sid': self.sid}
        return {'auth_passed': False}
    
    def login_local(self, username: str, password: str, remote_ip: str) -> dict:
        """本机明文密码登录（仅适用于 NAS 本地部署）"""
        params = {
            'user': username,
            'plain_pwd': password,
            'remote_ip': remote_ip,
            'device': 'picoclaw',
            'client_app': 'picoclaw',
        }
        resp = requests.get(f"http://127.0.0.1:8080/cgi-bin/authLogin.cgi", params=params)
        root = ET.fromstring(resp.text)
        
        if root.findtext('authPassed') == '1':
            self.sid = root.findtext('authSid')
            return {'auth_passed': True, 'sid': self.sid}
        return {'auth_passed': False}
    
    def logout(self) -> bool:
        """退出登录"""
        if not self.sid:
            return True
        resp = requests.get(f"{self.base_url}/cgi-bin/authLogout.cgi", 
                           params={'sid': self.sid})
        self.sid = None
        return True
    
    def validate_sid(self) -> bool:
        """验证当前 sid 是否有效"""
        if not self.sid:
            return False
        resp = requests.get(f"{self.base_url}/cgi-bin/authLogin.cgi",
                           params={'sid': self.sid})
        root = ET.fromstring(resp.text)
        return root.findtext('authPassed') == '1'
```

### 注意事项

1. **密码编码（⚠️ 重要）**：`pwd` 参数必须使用 UTF-16-LE 编码后再 Base64（官方文档：`ezEncode(utf16to8(password))`，Python 中等效为 `base64.b64encode(pwd.encode('utf-16-le'))`）。**不是 UTF-8**，对 ASCII 密码两种方式结果碰巧相同，但对中文密码会完全失败。
2. **sid 生命周期**：sid 会过期，长期运行的 agent 应监听 API 返回的认证失败状态，自动用 qtoken 重新登录
3. **2SV 处理**：如果登录返回 `need_2sv=1`，agent 需要有处理两步验证的能力，或者在 NAS 设置中将 agent 的 IP 加入豁免名单
4. **安全建议**：永远不要在代码中硬编码密码，使用环境变量或加密配置文件存储 qtoken

---

## 7. 验证 sid 有效性（File Manager 接口）

除了通过 `authLogin.cgi?sid=${sid}` 验证外，也可使用 File Manager 接口：

```
GET http://IP:8080/cgi-bin/filemanager/utilRequest.cgi?func=check_sid&sid=${sid}
```

**返回示例（JSON 格式）：**

```json
{
  "status": 1,
  "sid": "0",
  "servername": "My-NAS",
  "username": "admin",
  "admingroup": 1,
  "supportACL": 1,
  "enableACL": 0,
  "dateFormat": 1,
  "timeFormat": 24,
  "version": "5.0.0",
  "build": "20151225"
}
```

`status=1` 表示 sid 有效。

---

## 错误码完整参考（errorValue）

| errorValue | 含义 | 处理建议 |
|---|---|---|
| 0 | 成功 | — |
| -1 | 认证失败（密码错误/用户不存在） | 检查用户名密码 |
| -2 | 非管理员账户 | 使用管理员账户重试 |
| -3 | 管理员密码已过期 | 联系管理员重置密码 |
| -4 | 普通用户密码已过期 | 用户自行修改密码 |
