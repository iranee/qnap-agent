---
name: qnap-ssl
description: QNAP QTS SSL/TLS 证书完整管理指南。包含证书核心路径、stunnel 工作原理、三种申请方式（GUI/acme.sh/qnap-letsencrypt）、证书部署脚本、自动续期、常见问题排查。遇到 HTTPS 证书过期、证书更换、Let's Encrypt 申请失败等问题必读。
---

# QNAP SSL/TLS 证书管理

> 适用范围：QTS 5.x / 4.5.x
> 适用场景：HTTPS 证书申请、更新、部署、自动续期、证书过期排查

---

## 一、核心原理——必须先理解

### 1.1 QTS HTTPS 的工作方式

QTS 使用 **stunnel** 作为 HTTPS 代理层，stunnel 读取证书文件，再将 HTTPS 流量转发到内部 HTTP 服务（Qthttpd）。

```text
用户浏览器 → HTTPS(443) → stunnel（读 stunnel.pem）→ HTTP(8080) → QTS 界面
```

所有 HTTPS 配置的核心是 **`/etc/stunnel/stunnel.pem`** 这一个文件。

### 1.2 证书关键路径

```sh
# 主证书文件（私钥 + 证书链合并，重启后持久！）
/etc/stunnel/stunnel.pem

# 中间证书（CA 证书）
/etc/stunnel/uca.pem

# 上述两个路径实际上是软链接（或挂载）到持久分区
# 真实存储位置：
/mnt/HDA_ROOT/.config/stunnel/stunnel.pem
/mnt/HDA_ROOT/.config/stunnel/uca.pem

# 验证软链接关系
ls -la /etc/stunnel/
```

**重要：** `/etc/stunnel/stunnel.pem` **重启后依然存在**（它在持久分区 `/mnt/HDA_ROOT` 上），不像 `/root/` 或 `/etc/ssl/` 那样重启后消失。

### 1.3 stunnel.pem 的文件格式

`stunnel.pem` 是将多个 PEM 内容**拼接**在一起的单一文件，格式固定：

```text
[私钥 (Private Key)]
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----

[域名证书 (Certificate)]
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----

[中间证书链 (Intermediate CA)]
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
```

**拼接命令：**
```sh
cat domain.key signed.crt intermediate.pem > /etc/stunnel/stunnel.pem
# 或（Let's Encrypt 文件名）
cat privkey.pem fullchain.pem > /etc/stunnel/stunnel.pem
```

---

## 二、证书状态查询

```sh
# 查看当前证书信息（颁发者、有效期、域名）
openssl x509 -noout -text -in /etc/stunnel/stunnel.pem | grep -E 'Subject:|Issuer:|Not After|DNS:'

# 查看证书有效期（简洁）
openssl x509 -noout -dates -in /etc/stunnel/stunnel.pem

# 检查证书是否在 30 天内过期（exit 0=仍有效, exit 1=30天内过期）
openssl x509 -noout -in /etc/stunnel/stunnel.pem -checkend 2592000
echo "退出码 $?：0=距今30天以上有效，1=即将或已过期"

# 查看 stunnel 服务状态
/etc/init.d/stunnel.sh status 2>/dev/null
ss -tlnp | grep ':443'

# 查看证书文件权限（应该是 600）
ls -la /etc/stunnel/stunnel.pem
stat /etc/stunnel/stunnel.pem
```

---

## 三、方式一：QTS 内置 GUI（最简单，推荐新手）

适用场景：使用 myqnapcloud.com 域名，或 QTS 5.0+ 自定义 DDNS 域名

### 3.1 myqnapcloud.com 域名证书

```text
myQNAPcloud 应用 → SSL 证书 → Let's Encrypt
→ 输入你的 myqnapcloud.com 域名和邮箱
→ 勾选"自动续期"
→ 确认
```

### 3.2 自定义域名证书（QTS 5.0+）

```text
控制台 → 安全 → SSL 证书与私钥 → 从 Let's Encrypt 获取证书
→ 输入域名和邮箱 → 确认

⚠️ 已知问题：开启了 Apache 虚拟主机时，该向导可能报错
修复：控制台 → 应用程序 → Web 服务器 → 先关闭所有虚拟主机 → 再申请证书 → 申请完成后重新开启
```

### 3.3 手动上传证书

```text
控制台 → 安全 → SSL 证书与私钥 → 导入证书
→ 分别上传：证书（.crt/.pem）、私钥（.key）、中间证书（可选）
→ 确认导入
```

**导入后 QTS 会自动合并格式并写入 `/etc/stunnel/stunnel.pem`，无需手动操作。**

---

## 四、方式二：acme.sh（推荐，功能最全）

acme.sh 是目前最广泛使用的 ACME 客户端，支持 HTTP-01 和 DNS-01 两种验证方式。DNS-01 验证无需开放端口 80，适合 NAS 不直接暴露公网的场景。

### 4.1 安装 acme.sh

```sh
# 前提：需要 Entware 提供 curl 和 socat（或使用内置 curl）
# 安装路径必须在 /share/ 下（RAM disk 外，重启后持久）

ACME_HOME="/share/CACHEDEV1_DATA/.acme.sh"

curl https://get.acme.sh | sh -s email=your@email.com \
    --home "${ACME_HOME}"

# 如果 curl 不支持 TLS，先用 Entware 安装
# opkg install curl socat
```

### 4.2 申请证书

**方式 A：HTTP-01 验证（需要端口 80 可被外网访问）**

```sh
ACME_HOME="/share/CACHEDEV1_DATA/.acme.sh"

# 先停止占用 80 端口的服务
/etc/init.d/Qthttpd.sh stop

# 申请证书（-d 填写你的域名，-w 填写 web 根目录）
"${ACME_HOME}/acme.sh" --issue \
    -d nas.yourdomain.com \
    -w /share/Web \
    --home "${ACME_HOME}"

# 申请完成后重启 Web 服务
/etc/init.d/Qthttpd.sh start
```

**方式 B：DNS-01 验证（无需开放端口，推荐）**

以 Cloudflare 为例（acme.sh 支持几十个 DNS 提供商）：

```sh
export CF_Token="你的Cloudflare_API_Token"
export CF_Zone_ID="你的Zone_ID"  # 可选

ACME_HOME="/share/CACHEDEV1_DATA/.acme.sh"
"${ACME_HOME}/acme.sh" --issue \
    -d nas.yourdomain.com \
    --dns dns_cf \
    --home "${ACME_HOME}"
```

其他 DNS 提供商参考：https://github.com/acmesh-official/acme.sh/wiki/dnsapi

### 4.3 部署脚本（申请成功后写入 stunnel）

创建部署脚本 `/share/CACHEDEV1_DATA/.acme.sh/stunnel_deploy.sh`：

```sh
#!/bin/sh
# 用法: stunnel_deploy.sh <域名>
# 例如: stunnel_deploy.sh nas.yourdomain.com

set -e

DOMAIN="$1"
ACME_HOME="/share/CACHEDEV1_DATA/.acme.sh"

if [ -z "${DOMAIN}" ]; then
    echo "用法: $0 <域名>"
    exit 1
fi

CERT_DIR="${ACME_HOME}/${DOMAIN}_ecc"
[ -d "${CERT_DIR}" ] || CERT_DIR="${ACME_HOME}/${DOMAIN}"

if [ ! -d "${CERT_DIR}" ]; then
    echo "错误：找不到证书目录 ${CERT_DIR}"
    exit 1
fi

echo "部署证书到 stunnel..."

# 备份旧证书
cp /etc/stunnel/stunnel.pem /etc/stunnel/stunnel.pem.bak 2>/dev/null || true

# 拼接新证书（私钥 + 完整链）
cat "${CERT_DIR}/${DOMAIN}.key" \
    "${CERT_DIR}/${DOMAIN}.cer" \
    "${CERT_DIR}/ca.cer" \
    > /etc/stunnel/stunnel.pem

# 设置正确权限
chmod 600 /etc/stunnel/stunnel.pem

# 更新中间证书
cp "${CERT_DIR}/ca.cer" /etc/stunnel/uca.pem

# 重启服务使证书生效
/etc/init.d/Qthttpd.sh stop
/etc/init.d/stunnel.sh stop
/etc/init.d/stunnel.sh start
/etc/init.d/Qthttpd.sh start

echo "证书部署完成：$(date)"
# 验证新证书
openssl x509 -noout -dates -in /etc/stunnel/stunnel.pem
```

```sh
chmod +x /share/CACHEDEV1_DATA/.acme.sh/stunnel_deploy.sh
```

### 4.4 带自动部署的证书申请（一步完成）

```sh
ACME_HOME="/share/CACHEDEV1_DATA/.acme.sh"
DOMAIN="nas.yourdomain.com"

"${ACME_HOME}/acme.sh" --issue \
    -d "${DOMAIN}" \
    --dns dns_cf \
    --home "${ACME_HOME}" \
    --renew-hook "${ACME_HOME}/stunnel_deploy.sh ${DOMAIN}"

# 首次申请后手动部署一次
"${ACME_HOME}/stunnel_deploy.sh" "${DOMAIN}"
```

### 4.5 配置自动续期（crontab）

```sh
# 查看 acme.sh 建议的 crontab 行
/share/CACHEDEV1_DATA/.acme.sh/acme.sh --install-cronjob --home /share/CACHEDEV1_DATA/.acme.sh
# 注意：acme.sh 会写入系统 crontab，重启后失效！

# 手动写入持久化 crontab（正确方式）
cat >> /etc/config/crontab << 'EOF'
19 0 * * * /share/CACHEDEV1_DATA/.acme.sh/acme.sh --cron --home /share/CACHEDEV1_DATA/.acme.sh > /dev/null 2>&1
EOF

crontab /etc/config/crontab
/etc/init.d/crond.sh restart
```

---

## 五、方式三：qnap-letsencrypt（HTTP-01，需要端口80公网可达）

适用于有公网 IP 且端口 80 可访问的环境，工具会自动停止 Qthttpd、完成 ACME 挑战、部署证书。

### 5.1 安装

```sh
# 前提：Entware 已安装，提供 git 和 python3
opkg install git git-http python3

# 安装到 /share/ 下（必须，不能放在 /root/ 等 RAM disk 路径）
INSTALL_DIR="/share/CACHEDEV1_DATA/qnap-letsencrypt"
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# 下载 CA 根证书并校验（防止中间人攻击）
curl --silent --location --remote-name --insecure https://curl.haxx.se/ca/cacert.pem
# 与本机 hash 比对后再继续

# 配置 git SSL
git config --system http.sslVerify true
git config --system http.sslCAinfo "$(pwd)/cacert.pem"

git clone https://github.com/Yannik/qnap-letsencrypt.git .
```

### 5.2 初始化和申请

```sh
cd /share/CACHEDEV1_DATA/qnap-letsencrypt

# 初始化（生成 account.key 和 domain.key）
./init.sh

# 生成 CSR（替换为你的域名）
DOMAIN="nas.yourdomain.com"
openssl req -new -sha256 \
    -key letsencrypt/keys/domain.key \
    -subj "/CN=${DOMAIN}" \
    > letsencrypt/domain.csr

# 备份原证书
cp /etc/stunnel/stunnel.pem /etc/stunnel/stunnel.pem.orig

# 申请并部署（会自动停止/启动 Qthttpd）
./renew_certificate.sh
```

### 5.3 脚本工作流程（了解原理）

`renew_certificate.sh` 做以下事情：
1. 检查现有证书有效期，若 >30 天则跳过
2. 自动寻找可用的 Python3（依次检查 Entware、QPython3、系统 Python）
3. 停止 Qthttpd（释放端口 80）
4. 启动临时 HTTP 服务处理 ACME 挑战
5. 调用 acme-tiny 完成验证获取证书
6. 拼接证书写入 `/etc/stunnel/stunnel.pem`
7. 重启 stunnel 和 Qthttpd

### 5.4 配置自动续期

```sh
# 添加到持久化 crontab（每晚 3:30 检查，到期前 30 天自动续期）
echo "30 3 * * * /share/CACHEDEV1_DATA/qnap-letsencrypt/renew_certificate.sh >> /share/CACHEDEV1_DATA/qnap-letsencrypt/renew.log 2>&1" \
    >> /etc/config/crontab

crontab /etc/config/crontab
/etc/init.d/crond.sh restart

# 验证
crontab -l | grep qnap-letsencrypt
```

---

## 六、方式四：certbot Docker（DNS 挑战，无需公网端口）

适合已有 Docker 环境，且 DNS 提供商支持 API 的场景：

```sh
# 示例：使用 DNS 挑战申请通配符证书
CERT_STORE="/share/CACHEDEV1_DATA/certs"
mkdir -p "${CERT_STORE}"

docker run --rm -it \
    -v "${CERT_STORE}:/etc/letsencrypt/archive" \
    certbot/certbot certonly \
    --preferred-challenges dns \
    --manual \
    -d "*.yourdomain.com"

# 证书申请完成后，拼接写入 stunnel
cd "${CERT_STORE}/yourdomain.com"
cat fullchain1.pem privkey1.pem > /tmp/stunnel_new.pem
cp /etc/stunnel/stunnel.pem /etc/stunnel/stunnel.pem.bak
mv /tmp/stunnel_new.pem /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem

/etc/init.d/stunnel.sh stop && /etc/init.d/stunnel.sh start
/etc/init.d/Qthttpd.sh stop && /etc/init.d/Qthttpd.sh start
```

---

## 七、证书部署（通用步骤）

无论用什么方式获得证书，最终部署步骤相同：

```sh
# 步骤 1：准备文件（确认格式正确）
# Let's Encrypt 文件名对应关系：
# privkey.pem   = 私钥
# cert.pem      = 域名证书
# chain.pem     = 中间证书
# fullchain.pem = cert.pem + chain.pem 合并

# 步骤 2：备份现有证书
cp /etc/stunnel/stunnel.pem /etc/stunnel/stunnel.pem.$(date +%Y%m%d)

# 步骤 3：拼接并写入
cat privkey.pem fullchain.pem > /etc/stunnel/stunnel.pem
# 或者三段分开拼
cat domain.key signed.crt intermediate.pem > /etc/stunnel/stunnel.pem

# 步骤 4：设置权限
chmod 600 /etc/stunnel/stunnel.pem

# 步骤 5：更新中间证书（可选但推荐）
cp intermediate.pem /etc/stunnel/uca.pem
# 或
cp chain.pem /etc/stunnel/uca.pem

# 步骤 6：重启服务
/etc/init.d/stunnel.sh stop
/etc/init.d/stunnel.sh start
/etc/init.d/Qthttpd.sh stop
/etc/init.d/Qthttpd.sh start

# 步骤 7：验证
openssl x509 -noout -text -in /etc/stunnel/stunnel.pem | grep -E 'Subject:|Not After|DNS:'
```

---

## 八、常见问题排查

### 8.1 证书申请失败（HTTP-01）

```sh
# 检查端口 80 是否被占用
ss -tlnp | grep ':80'
# 如果 Qthttpd 占用，先停止
/etc/init.d/Qthttpd.sh stop

# 检查 .well-known 目录是否有残留
ls /share/Web/.well-known/ 2>/dev/null
# 如有残留，删除后重试
rm -rf /share/Web/.well-known/

# 检查端口 80 是否可被外网访问
# 在外网设备执行：curl http://你的IP/.well-known/test.txt
```

### 8.2 证书部署后 GUI 仍显示"默认证书"

```sh
# 确认 stunnel.pem 格式正确（私钥在最前面）
openssl x509 -noout -in /etc/stunnel/stunnel.pem 2>&1
# 如果报错，说明文件格式有问题

# 检查私钥是否匹配证书
openssl x509 -noout -modulus -in /etc/stunnel/stunnel.pem | md5sum
openssl rsa -noout -modulus -in /etc/stunnel/stunnel.pem | md5sum
# 两行 hash 必须一致，不一致说明私钥和证书不匹配

# 强制重启 stunnel
/etc/init.d/stunnel.sh stop
sleep 2
/etc/init.d/stunnel.sh start
/etc/init.d/Qthttpd.sh stop
/etc/init.d/Qthttpd.sh start
```

### 8.3 HTTPS 端口被重置为 8081

已知问题：通过 GUI 申请证书后，HTTPS 端口有时自动被改为 8081。

```text
控制台 → 系统 → 常规设置 → 系统端口
→ HTTPS 端口：改回 443
→ 应用
```

### 8.4 虚拟主机冲突

```text
申请证书前：
控制台 → 应用程序 → Web 服务器 → 虚拟主机 → 全部禁用

申请完成后：
重新启用虚拟主机
```

### 8.5 Python3 找不到（qnap-letsencrypt）

```sh
# renew_certificate.sh 自动检查以下路径
/sbin/getcfg QPython3 Install_Path -f /etc/config/qpkg.conf
/sbin/getcfg Python3 Install_Path -f /etc/config/qpkg.conf
/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf

# 推荐解决方案：通过 Entware 安装 python3
opkg install python3
```

### 8.6 ca-bundle 缺失（QTS 无内置根证书）

QTS 不自带完整的 CA 根证书包，导致 HTTPS 请求失败（`SSL certificate problem`）。

```sh
# 下载 Mozilla CA bundle
curl --insecure -o /share/CACHEDEV1_DATA/cacert.pem https://curl.se/ca/cacert.pem

# 使用时指定（临时）
curl --cacert /share/CACHEDEV1_DATA/cacert.pem https://目标地址

# 通过 Entware 永久解决
opkg install ca-certificates
```

### 8.7 证书路径不持久（重启后消失）

**错误做法：** 将证书放在 `/root/`、`/etc/ssl/`、`/tmp/` 下

**正确做法：** 证书文件和脚本一律放在 `/share/CACHEDEV1_DATA/` 下

```sh
# /etc/stunnel/stunnel.pem 本身是持久的（链接到 /mnt/HDA_ROOT）
ls -la /etc/stunnel/  # 确认软链接目标

# 证书脚本放在 /share/ 下
/share/CACHEDEV1_DATA/.acme.sh/     # acme.sh 安装目录
/share/CACHEDEV1_DATA/certs/        # 原始证书存储
```

---

## 九、stunnel 服务管理

```sh
# 状态检查
/etc/init.d/stunnel.sh status 2>/dev/null
ps aux | grep stunnel | grep -v grep
ss -tlnp | grep ':443'

# 停止
/etc/init.d/stunnel.sh stop

# 启动
/etc/init.d/stunnel.sh start

# 重启（等价操作）
/etc/init.d/stunnel.sh stop && sleep 1 && /etc/init.d/stunnel.sh start

# stunnel 配置文件位置
ls /etc/stunnel/
cat /etc/stunnel/stunnel.conf 2>/dev/null
```

---

## 十、证书方案选择建议

| 场景 | 推荐方案 |
|---|---|
| 使用 myqnapcloud.com 域名 | QTS GUI（myQNAPcloud → SSL Certificate） |
| 自定义域名 + 无技术背景 | QTS GUI（控制台 → 安全 → SSL 证书）|
| 自定义域名 + 不暴露端口 80 | **acme.sh + DNS-01 验证**（最推荐） |
| 自定义域名 + 端口 80 公网可达 | qnap-letsencrypt 或 acme.sh HTTP-01 |
| 内网自签证书（不需要公信任） | openssl 生成后直接部署到 stunnel.pem |
| 通配符证书（*.domain.com） | certbot Docker DNS-01 或 acme.sh DNS-01 |

---

## 十一、安全要求

- 查询证书状态（openssl x509 -noout）：只读，无需确认
- 修改 `/etc/stunnel/stunnel.pem`：必须先备份，告知用户，确认后执行
- 重启 stunnel/Qthttpd：必须确认（会中断所有 HTTPS 连接）
- 禁止删除 `/etc/stunnel/*.pem` 文件
- 证书私钥（`.key`）文件权限必须设为 600，不得对外暴露
