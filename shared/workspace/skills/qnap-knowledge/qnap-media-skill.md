---
name: qnap-media
description: QNAP NAS 上的影音文件分析、ffmpeg/ffprobe 使用、媒体库整理与 Plex/Emby/Jellyfin 媒体服务排查规范。
---

# 影音媒体管理

> 适用范围：QNAP NAS 上的影音文件管理、分析、整理
> 适用场景：媒体库维护、格式识别、媒体服务器管理、文件损坏排查

---

## 一、QNAP 内置 ffmpeg / ffprobe

### 1.1 路径探测

QTS 系统中 ffmpeg/ffprobe 路径不固定，需要先探测：

```sh
# 常见路径列表，逐一检查
for path in \
    "/usr/local/cayin/bin/ffprobe" \
    "/usr/local/bin/ffprobe" \
    "/usr/bin/ffprobe" \
    "${QPKG_ROOT}/tools/ffprobe"; do
    if [ -x "${path}" ]; then
        echo "ffprobe 找到: ${path}"
        FFPROBE="${path}"
        break
    fi
done

for path in \
    "/usr/local/cayin/bin/ffmpeg" \
    "/usr/local/bin/ffmpeg" \
    "/usr/bin/ffmpeg" \
    "${QPKG_ROOT}/tools/ffmpeg"; do
    if [ -x "${path}" ]; then
        echo "ffmpeg 找到: ${path}"
        FFMPEG="${path}"
        break
    fi
done
```

### 1.2 没有内置 ffmpeg 时的处理

```sh
TOOLS_DIR="${QPKG_ROOT}/tools"
mkdir -p "${TOOLS_DIR}"

# amd64 架构（大多数 x86 NAS）
curl -L "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz" \
  -o /tmp/ffmpeg.tar.xz

tar xf /tmp/ffmpeg.tar.xz -C /tmp/
cp /tmp/ffmpeg-*-amd64-static/ffmpeg  "${TOOLS_DIR}/ffmpeg"
cp /tmp/ffmpeg-*-amd64-static/ffprobe "${TOOLS_DIR}/ffprobe"
chmod +x "${TOOLS_DIR}/ffmpeg" "${TOOLS_DIR}/ffprobe"
rm -f /tmp/ffmpeg.tar.xz

# 验证
"${TOOLS_DIR}/ffprobe" -version 2>&1 | head -1
```

**ARM 架构（如 TS-x31 系列）：**
```sh
# 使用 arm64 静态包
curl -L "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz" \
  -o /tmp/ffmpeg.tar.xz
```

---

## 二、媒体文件信息获取

```sh
# 完整信息（JSON 格式）
${FFPROBE} -v quiet -print_format json \
  -show_format -show_streams "video.mkv"

# 基本格式信息（时长/大小/码率）
${FFPROBE} -v error \
  -show_entries format=duration,size,bit_rate \
  -of default=noprint_wrappers=1 "video.mkv"

# 视频流信息
${FFPROBE} -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height,r_frame_rate,avg_frame_rate \
  -of default=noprint_wrappers=1 "video.mkv"

# 音频流信息
${FFPROBE} -v error -select_streams a \
  -show_entries stream=codec_name,channels,sample_rate,bit_rate \
  -of default=noprint_wrappers=1 "video.mkv"

# 字幕流信息
${FFPROBE} -v error -select_streams s \
  -show_entries stream=index,codec_name,tags=language \
  -of default=noprint_wrappers=1 "video.mkv"

# 一行摘要（适合批量显示）
${FFPROBE} -v error \
  -show_entries format=duration,size \
  -show_entries stream=codec_name,width,height \
  -of compact "video.mkv"
```

---

## 三、常见媒体格式速查

| 格式 | 扩展名 | 编码容器 | 常见编码 |
|---|---|---|---|
| MKV | `.mkv` | Matroska | H.264/H.265/AV1，多音轨，多字幕 |
| MP4 | `.mp4` | MPEG-4 | H.264/H.265，兼容性最广 |
| AVI | `.avi` | AVI | DivX/XviD，老格式，不支持多字幕 |
| MOV | `.mov` | QuickTime | Apple 原生格式 |
| WMV | `.wmv` | Windows Media | Windows 原生 |
| TS/MTS | `.ts/.mts` | MPEG-TS | 录播和广播流格式 |
| HEVC/H.265 | `.mkv/.mp4` | - | 高压缩比，需要硬件解码支持 |
| AV1 | `.mkv/.mp4` | - | 新一代编码，压缩率更高 |
| FLAC | `.flac` | - | 无损音频 |
| AAC | `.aac/.m4a` | - | 主流有损音频 |

---

## 四、媒体库统计与整理

```sh
MEDIA_DIR="/share/media"

# 按格式统计文件数量
find "${MEDIA_DIR}" -type f \( \
    -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
    -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.ts" \
    -o -iname "*.flac" -o -iname "*.mp3" -o -iname "*.aac" \
  \) 2>/dev/null | \
  awk -F. '{print tolower($NF)}' | sort | uniq -c | sort -rn

# 总占用空间
du -sh "${MEDIA_DIR}"

# 各子目录大小
du -sh "${MEDIA_DIR}"/*/  2>/dev/null | sort -rh | head -20

# 查找疑似低质量文件（小于 500MB 的视频）
find "${MEDIA_DIR}" -type f \( -iname "*.mkv" -o -iname "*.mp4" \) \
  -size -500M 2>/dev/null | head -20

# 查找超大文件（大于 30GB）
find "${MEDIA_DIR}" -type f -size +30G 2>/dev/null
```

---

## 五、媒体服务器管理

### 5.1 Plex Media Server

```sh
# 检查 Plex 安装方式（QPKG 或 Docker）
QPKG_NAME="PlexMediaServer"
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f /etc/config/qpkg.conf)

if [ -n "${QPKG_ROOT}" ]; then
    echo "Plex QPKG 安装路径: ${QPKG_ROOT}"
    ls "${QPKG_ROOT}"
    ls "${QPKG_ROOT}"/*.sh 2>/dev/null
else
    echo "Plex 未以 QPKG 安装，检查 Docker..."
    docker ps | grep -i plex
fi

# Docker 方式运行的 Plex
docker ps | grep -i plex
docker logs plex 2>/dev/null | tail -30

# Plex 端口（默认 32400）
ss -tlnp | grep :32400
```

**Plex 在 QNAP 上的注意事项：**
```
- Plex 硬件转码（Hardware Transcoding）需要 Plex Pass 订阅
- QNAP x86 NAS 通常支持 Intel Quick Sync 硬件转码
- ARM NAS 一般不支持 Plex 硬件转码
- Plex 媒体库数据库文件较大，建议放在 SSD 或快速卷上
- 解决 Plex 找不到媒体文件：检查 Docker 卷挂载路径是否正确
```

### 5.2 Emby

```sh
docker ps | grep -iE 'emby'
docker logs emby 2>/dev/null | tail -30
ss -tlnp | grep :8096

# Emby 挂载路径检查
docker inspect emby 2>/dev/null | grep -A 30 '"Mounts"'
```

### 5.3 Jellyfin

```sh
docker ps | grep -iE 'jellyfin'
docker logs jellyfin 2>/dev/null | tail -30
ss -tlnp | grep :8096

# Jellyfin 配置路径（在容器内）
docker exec jellyfin ls /config 2>/dev/null
```

**Plex vs Emby vs Jellyfin 选择参考：**
| | Plex | Emby | Jellyfin |
|---|---|---|---|
| 费用 | 免费+付费（Plex Pass） | 免费+付费（Premiere） | 完全免费开源 |
| 硬件转码 | 需 Plex Pass | 需 Premiere | 免费支持 |
| 界面 | 最精美 | 次之 | 功能完善 |
| 性能 | 较高（需要网络中继） | 中等 | 最低（轻量） |

### 5.4 DLNA 服务

```sh
/etc/init.d/dlna status 2>/dev/null || \
    ps aux | grep -i dlna | grep -v grep

ss -ulnp | grep :1900  # DLNA 发现端口
ss -tlnp | grep :8200  # 常见 DLNA HTTP 端口
```

---

## 六、字幕文件管理

```sh
MOVIES_DIR="/share/movies"

# 查找缺少字幕的视频
find "${MOVIES_DIR}" -name "*.mkv" 2>/dev/null | while read video; do
    base="${video%.*}"
    if ! ls "${base}".srt "${base}".ass "${base}".sub "${base}".ssa \
         2>/dev/null | grep -q .; then
        echo "缺少字幕: $(basename "${video}")"
    fi
done | head -30

# 查找字幕文件
find "${MOVIES_DIR}" -name "*.srt" -o -name "*.ass" -o -name "*.sub" 2>/dev/null | head -20

# MKV 内封字幕检查
find "${MOVIES_DIR}" -name "*.mkv" 2>/dev/null | while read f; do
    subtitle_count=$(${FFPROBE} -v error -select_streams s \
        -show_entries stream=index -of csv=p=0 "${f}" 2>/dev/null | wc -l)
    [ "${subtitle_count}" -gt 0 ] && echo "有内封字幕: $(basename "${f}")"
done | head -20
```

---

## 七、ffmpeg 常用操作

```sh
# 无损重封装（mkv → mp4，不转码，速度快）
${FFMPEG} -i input.mkv -c copy output.mp4

# 提取音频
${FFMPEG} -i input.mkv -vn -acodec copy output.aac

# 提取字幕
${FFMPEG} -i input.mkv -map 0:s:0 output.srt

# 生成截图（第 60 秒）
${FFMPEG} -i input.mkv -ss 00:01:00 -vframes 1 thumbnail.jpg

# H.264 转码（通用兼容性）
${FFMPEG} -i input.mkv -c:v libx264 -crf 23 -preset medium -c:a aac output.mp4

# H.265 转码（更小文件）
${FFMPEG} -i input.mkv -c:v libx265 -crf 28 -c:a copy output.mp4

# 批量转码（谨慎使用，占用大量 CPU）
find /share/videos/ -name "*.avi" 2>/dev/null | while read f; do
    output="${f%.avi}.mp4"
    echo "转码: $(basename "${f}") → $(basename "${output}")"
    ${FFMPEG} -i "${f}" -c:v libx264 -crf 23 -c:a aac "${output}"
done
```

**转码前提示用户：**
- 转码会占用较高 CPU（可能影响 NAS 其他功能）
- 耗时较长（4K 视频可能数小时）
- 输出文件会占用额外存储空间
- 建议在低使用时段执行（深夜）

---

## 八、文件损坏检测

```sh
# 快速检测（只检查文件头/尾是否可读）
check_video_quick() {
    local file="$1"
    ${FFPROBE} -v error "${file}" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "OK: $(basename "${file}")"
    else
        echo "ERROR: $(basename "${file}")"
    fi
}

MOVIES_DIR="/share/movies"
find "${MOVIES_DIR}" -name "*.mkv" 2>/dev/null | while read f; do
    check_video_quick "${f}"
done

# 完整解码检测（更慢但更准确）
${FFMPEG} -v error -i input.mkv -f null - 2>&1 | head -20
```

---

## 九、安全要求

- 查询媒体信息：只读，无需确认
- 批量移动、重命名、转码前先确认
- 输出目录和覆盖行为要先说清楚
- 转码任务启动前告知用户 CPU/时间/空间影响
- 不要把工具装到系统目录（/usr/bin 等）
