---
name: qnap-storage
description: QNAP QTS 的存储结构、共享文件夹、磁盘空间分析、文件操作、权限管理、快照查询与磁盘健康检查规范。
---

# QNAP 存储与文件管理

> 适用范围：QTS 5.x 共享文件夹、存储池、磁盘管理
> 适用场景：文件操作、空间分析、权限管理、媒体整理、快照查询

---

## 一、QNAP 存储架构

```text
物理磁盘（/dev/sda, /dev/sdb, ...）
  └─ RAID 阵列（/dev/md0, /dev/md1, ...）
       └─ 存储池（LVM Volume Group）
            └─ 逻辑卷（LVM Logical Volume）
                 └─ 共享文件夹（挂载到 /share/<name>/）
                      └─ .snapshot/   快照访问点
                      └─ @Recycle/    回收站
                      └─ @tmp/        临时目录
```

常见挂载规律：

```text
/share/CACHEDEV1_DATA/   存储池 1 根目录
/share/CACHEDEV2_DATA/   存储池 2 根目录
/share/<共享名>/          共享访问入口（软链接）
```

**注意：** 删除 /share/CACHEDEV*_DATA/.qpkg 下的内容会损坏已安装的 QPKG 应用。

---

## 二、存储状态查询

```sh
# 总体磁盘空间
df -h
df -h | grep share

# 存储池详情
df -h /share/CACHEDEV1_DATA/
df -h /share/CACHEDEV2_DATA/

# LVM 信息（存储池/卷详情）
/usr/sbin/lvm lvs 2>/dev/null
/usr/sbin/lvm vgs 2>/dev/null
/usr/sbin/lvm pvs 2>/dev/null

# RAID 状态
cat /proc/mdstat

# 挂载情况
mount | grep share
```

---

## 三、磁盘空间分析

```sh
# 查找大目录（共享根目录）
du -sh /share/*/ 2>/dev/null | sort -rh | head -20

# 查找大文件
find /share/<共享名>/ -type f -size +1G 2>/dev/null | \
  xargs -I{} du -sh {} 2>/dev/null | sort -rh | head -20

# 查找超大文件（>10GB）
find /share/ -type f -size +10G 2>/dev/null

# 统计文件类型分布
find /share/<共享名>/ -type f 2>/dev/null | \
  awk -F. '{print tolower($NF)}' | sort | uniq -c | sort -rn | head -20

# 查找空目录
find /share/<共享名>/ -type d -empty 2>/dev/null

# 查找最近修改的文件（7天内）
find /share/<共享名>/ -type f -mtime -7 2>/dev/null | head -30

# 回收站占用
for share_dir in /share/*/; do
    recycle="${share_dir}@Recycle"
    if [ -d "${recycle}" ]; then
        size=$(du -sh "${recycle}" 2>/dev/null | cut -f1)
        echo "${recycle}: ${size}"
    fi
done
```

---

## 四、文件操作

### 4.1 安全复制和移动

```sh
# 带进度的复制
cp -v source_file target_file
cp -av /share/source_dir/ /share/target_dir/

# rsync（推荐用于大量文件）
rsync -avh --progress /share/source/ /share/target/

# 带校验的 rsync（确保数据完整性）
rsync -avhc --progress /share/source/ /share/target/

# 移动文件
mv /share/source/file.mkv /share/target/

# 批量移动（同存储池，瞬间完成）
find /share/incoming/ -name "*.mkv" -exec mv {} /share/movies/ \;
```

**注意：** 批量文件操作前必须确认，先展示前几条预览。

### 4.2 文件搜索

```sh
# 按名称搜索（精确大小写）
find /share/<共享名>/ -name "*.mp4" 2>/dev/null

# 按名称搜索（不区分大小写）
find /share/<共享名>/ -iname "*.MP4" 2>/dev/null

# 按时间搜索（7天内修改）
find /share/<共享名>/ -type f -mtime -7 2>/dev/null

# 按大小搜索
find /share/<共享名>/ -type f -size +4G 2>/dev/null
find /share/<共享名>/ -type f -size -100k 2>/dev/null

# 内容搜索
grep -r "关键词" /share/<共享名>/ --include="*.txt" 2>/dev/null
grep -rl "关键词" /share/<共享名>/ 2>/dev/null  # 只显示文件名
```

### 4.3 批量重命名（先预览，再执行）

```sh
# 预览（不修改）
find /share/photos/ -name "*.jpeg" 2>/dev/null | head -10

# 执行重命名
find /share/photos/ -name "*.jpeg" | while read f; do
    mv "${f}" "${f%.jpeg}.jpg"
done

# 添加前缀
for f in /share/incoming/*.mp4; do
    [ -f "${f}" ] || continue
    mv "${f}" "/share/incoming/2026_$(basename "${f}")"
done
```

---

## 五、权限管理

```sh
# 查看权限（只读查询）
ls -la /share/<共享名>/
stat /share/<共享名>/文件名
getfacl /share/<共享名>/文件名 2>/dev/null

# 修改权限（执行前必须确认）
chmod 755 /share/<共享名>/dirname
chmod 644 /share/<共享名>/file.txt
chmod -R 755 /share/<共享名>/dirname/   # 递归，影响大

# 修改所有者（执行前必须确认）
chown admin:administrators /share/<共享名>/newfile
chown -R admin:administrators /share/<共享名>/  # 递归，影响大
```

**QNAP 权限说明：**
- QTS 使用 POSIX ACL + Windows ACL 混合权限系统
- 建议通过 QTS Web 界面管理共享文件夹权限（权限 → 共享文件夹）
- SSH 中的 `chmod` 只修改 POSIX 权限，不影响 Windows ACL

---

## 六、磁盘健康检查

```sh
# 查看磁盘列表
lsblk
hdparm -I /dev/sda | grep -E 'Model|Serial|Firmware|capacity'

# SMART 健康检查
smartctl -H /dev/sda 2>/dev/null    # 快速健康摘要
smartctl -a /dev/sda 2>/dev/null    # 完整 SMART 信息

# 批量检查所有磁盘
for disk in /dev/sd[a-z]; do
    [ -b "${disk}" ] || continue
    model=$(hdparm -I "${disk}" 2>/dev/null | grep 'Model' | awk -F: '{print $2}' | xargs)
    health=$(smartctl -H "${disk}" 2>/dev/null | grep 'overall-health' | awk '{print $NF}')
    hours=$(smartctl -A "${disk}" 2>/dev/null | awk '/^  9/{print $10}')
    echo "${disk}: ${model} | 健康: ${health} | 通电时间: ${hours}h"
done
```

**注意：** smartctl 在 QTS 上可能路径不标准。如果不存在，可以从 `${QPKG_ROOT}/tools/` 调用。

---

## 七、快照查询

```sh
# 查看所有快照目录
ls /share/.snapshot/ 2>/dev/null
ls /.snapshots/ 2>/dev/null

# 查看特定共享的快照
ls /share/<共享名>/.snapshot/ 2>/dev/null | grep GMT

# LVM 快照
/usr/sbin/lvm lvs 2>/dev/null | grep snap

# 快照占用空间
du -sh /share/.snapshot/ 2>/dev/null
```

**从快照恢复文件：**
```sh
# 通过 GUI 恢复（推荐）
# 存储与快照管理 → 快照 → 快照库 → 选择共享 → 选择时间点 → 恢复

# 通过 SSH 直接访问快照中的文件（只读）
ls /share/<共享名>/.snapshot/
cp /share/<共享名>/.snapshot/<快照名>/path/to/file /share/<共享名>/path/to/restored_file
```

---

## 八、回收站管理

```sh
# 查看回收站内容
ls -la /share/<共享名>/@Recycle/
du -sh /share/<共享名>/@Recycle/

# 查看所有共享的回收站大小
for share_dir in /share/*/; do
    recycle="${share_dir}@Recycle"
    if [ -d "${recycle}" ]; then
        size=$(du -sh "${recycle}" 2>/dev/null | cut -f1)
        echo "${recycle}: ${size}"
    fi
done
```

**清空回收站前必须确认：**
```sh
# 列出内容（预览）
ls -la /share/<共享名>/@Recycle/ | head -20
du -sh /share/<共享名>/@Recycle/

# 确认后才执行（需用户确认）
# rm -rf /share/<共享名>/@Recycle/*  <- 执行前确认
```

---

## 九、NFS 磁盘配额查询

```sh
repquota /share/CACHEDEV1_DATA/ 2>/dev/null
quota -u admin 2>/dev/null
quota -u <用户名> 2>/dev/null
```

---

## 十、 重新挂在存储池（半禁止服务，不建议的操作）
```
#/etc/init.d/init_lvm.sh
```
执行这个命令会导致所有存储池被卸载并重新挂载，期间会导致正在运行的服务、执行的任务出现问题
非必要不运行这个命令，只有在用户需要恢复数据的时候存储池有异常显示，必须用此命令来重新装载存储池的情况
以及用户判断出真正的问题来源于存储池的时候，在告知用户风险，并多次询问、多次确认的情况下才能运行

## 十、安全要求

- `/share/` 下的数据按用户核心数据处理
- 删除、批量移动、权限修改、解压覆盖前**必须确认**
- 优先只读检查，再决定是否修改
- 不要执行磁盘格式化、LVM 写入、RAID 改动
- 递归操作（-R/--recursive）执行前必须告知影响范围
- 清空回收站前必须列出大小，等待用户确认
