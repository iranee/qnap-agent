#!/bin/sh
########################################
# safe-rm.sh - QNAP Agent 安全删除工具
# 版本: 3.3
#
# 更新记录:
#   v3.3 空目录清理：先删除 .@__thumb，再逐层 rmdir 所有空目录，不残留空父目录
#   v3.2 目录合并逻辑：回收站已有同名目录时，自动对比目录结构并重命名冲突文件
#   v3.1 目录安全删除：检测到回收站同名目录则报错退出（原逻辑）
#        ↓ 实际需求改为 v3.2 的合并逻辑
#   v3.0 目录操作支持：支持直接移动整个目录到回收站
#   v2.x 文件重命名：[n] 版本号机制避免覆盖
#
# 用法：
#   safe-rm.sh [-r] [-f] <文件> [文件2 ...]      删除（进回收站）
#   safe-rm.sh --list   [<共享名>|all]            列出回收站内容
#   safe-rm.sh --size   [<共享名>|all]            查看回收站占用空间
#   safe-rm.sh --restore <回收站精确路径>          恢复文件
#              [--overwrite|--rename]              冲突处理（agent确认后传入）
#   safe-rm.sh -h
#
# ────────────────────────────────────────
# 目录结构
# ────────────────────────────────────────
#
#   /share/.qpkg/qnap-agent/        ← AGENT_HOME（插件根目录）
#   ├── workspace/                  ← PICOCLAW_DIR
#   │   ├── picoclaw                ← 二进制
#   │   ├── picoclaw-launcher       ← 二进制
#   │   └── tools/
#   │       └── safe-rm.sh          ← 本脚本
#   └── tmp/
#       └── @Recycle/               ← 本地回收站（LOCAL_RECYCLE）
#
# ────────────────────────────────────────
# 共享文件夹判断依据
# ────────────────────────────────────────
# QNAP 每个共享文件夹在 /share/<名> 下有软链接。
# 检查 /share/<目录名> 软链接是否存在来判断是否为共享文件夹。
#
# 有软链接 → 共享文件夹 → 进 <共享根>/@Recycle/
# 无软链接 → 系统目录   → 进 /share/.qpkg/qnap-agent/tmp/@Recycle/
#
# ────────────────────────────────────────
# --restore 设计原则
# ────────────────────────────────────────
# · 只接受 @Recycle 内的精确路径（含 [x] 后缀）
# · 自动从目录结构还原原始路径
# · 目标已存在时：报错退出，不覆盖，除非明确传 --overwrite 或 --rename
# · 所有版本选择、冲突决策均由 agent 完成，脚本不交互
#
########################################

if [ -z "$PICOCLAW_DIR" ]; then
    PICOCLAW_DIR=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)
fi

AGENT_HOME=$(dirname "$PICOCLAW_DIR")        # qnap-agent/
LOCAL_RECYCLE="${AGENT_HOME}/tmp/@Recycle"   # qnap-agent/tmp/@Recycle

RECYCLED_COUNT=0
ERROR_COUNT=0

log_info()  { printf '[safe-rm] %s\n'     "$1"; }
log_error() { printf '[safe-rm] ERROR %s\n' "$1" >&2; }

usage() {
    cat << 'USAGE'
用法:
  删除（进回收站）:
    safe-rm.sh [-r] [-f] <文件或目录> [...]

  查看回收站:
    safe-rm.sh --list  [<共享名>|all]      列出文件与大小
    safe-rm.sh --size  [<共享名>|all]      仅显示占用空间汇总

  恢复文件（单文件，需指定回收站精确路径）:
    safe-rm.sh --restore <@Recycle内精确路径>
    safe-rm.sh --restore <路径> --overwrite  目标已存在时覆盖
    safe-rm.sh --restore <路径> --rename      目标已存在时重命名保留两者

  选项:
    -r, -R       递归（仅限非共享路径）
    -f           强制模式（跳过不存在文件报错）
    -h           帮助
USAGE
    exit 0
}

# ══════════════════════════════════════════════
# 工具函数
# ══════════════════════════════════════════════

abs_path_of() {
    local f="$1"
    local res=""
    if [ -d "$f" ]; then
        res=$(cd "$f" 2>/dev/null && pwd)
    else
        local d
        d=$(dirname "$f")
        local b
        b=$(basename "$f")
        local d_abs
        d_abs=$(cd "$d" 2>/dev/null && pwd)
        if [ -n "$d_abs" ]; then
            res="${d_abs}/${b}"
        fi
    fi
    if [ -z "$res" ]; then
        echo "ERROR_INVALID_PATH"
    else
        echo "$res"
    fi
}

human_size() {
    local bytes="$1"
    if [ "$bytes" -ge 1073741824 ] 2>/dev/null; then
        LC_NUMERIC=C awk "BEGIN{printf \"%.1fGB\", $bytes/1073741824}"
    elif [ "$bytes" -ge 1048576 ] 2>/dev/null; then
        LC_NUMERIC=C awk "BEGIN{printf \"%.1fMB\", $bytes/1048576}"
    elif [ "$bytes" -ge 1024 ] 2>/dev/null; then
        LC_NUMERIC=C awk "BEGIN{printf \"%.1fKB\", $bytes/1024}"
    else
        echo "${bytes}B"
    fi
}

dir_bytes() {
    find "$1" -type f -print0 2>/dev/null | \
        xargs -0 -r stat -c '%s' 2>/dev/null | \
        awk '{s+=$1} END{print s+0}'
}

file_mtime() {
    stat -c '%y' "$1" 2>/dev/null | cut -c1-16
}

strip_version() {
    echo "$1" | sed 's/\[[0-9]*\]$//'
}

# ══════════════════════════════════════════════
# 共享文件夹识别
# ══════════════════════════════════════════════

find_share_root() {
    local abs="$1"
    local candidate name
    case "$abs" in
        /share/CACHEDEV*_DATA/*/*)
            # 路径可能是物理路径（/share/CACHEDEV2_DATA/共享文档/...）
            # 或已经过 readlink-f 解析的路径（/share/CACHEDEV2_DATA/共享文档/...）
            # 需要判断第二层目录名是否为软链接，从而确定共享文件夹
            candidate=$(echo "$abs" | sed 's|\(/share/CACHEDEV[^/]*_DATA/[^/]*\)/.*|\1|')
            name=$(basename "$candidate")
            if [ -L "/share/$name" ]; then
                echo "$candidate"
            else
                echo ""
            fi
            ;;
        /share/*/*)
            # 支持通过软链接名直接访问的路径，如 /share/共享文档/...
            # 软链接可能指向相对路径（如 CACHEDEV2_DATA/共享文档）或绝对路径
            # readlink -f 会解析软链接到完整路径，需从中提取共享根目录
            local first_part real_path share_name
            first_part=$(echo "$abs" | sed 's|\(/share/[^/]*\)/.*|\1|')
            if [ -L "$first_part" ]; then
                real_path=$(readlink -f "$first_part" 2>/dev/null)
                # 从 real_path 提取共享根目录（/share/<name>）
                # real_path 可能是 /share/CACHEDEV2_DATA/共享文档 或相对路径 CACHEDEV2_DATA/共享文档
                share_name=$(basename "$first_part")
                # 构造标准格式的共享根路径
                if echo "$real_path" | grep -q '^/share/'; then
                    # 绝对路径：提取 /share/<name> 部分
                    echo "$real_path" | sed "s|\(/share/$share_name\).*|\1|"
                else
                    # 相对路径：拼接 /share/<name>
                    echo "/share/$share_name"
                fi
            else
                echo ""
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

list_all_shares() {
    for link in /share/*; do
        [ -L "$link" ] || continue
        local real
        real=$(readlink -f "$link" 2>/dev/null)
        [ -d "$real" ] && echo "$real"
    done
}

resolve_share_name() {
    local name="$1"
    if [ -L "/share/$name" ]; then
        readlink -f "/share/$name" 2>/dev/null
    else
        echo ""
    fi
}

# ══════════════════════════════════════════════
# 子命令实现
# ══════════════════════════════════════════════

cmd_list() {
    local target="$1"
    local share_list=""

    if [ -z "$target" ] || [ "$target" = "all" ]; then
        share_list=$(list_all_shares)
    else
        local resolved
        resolved=$(resolve_share_name "$target")
        if [ -z "$resolved" ]; then
            log_error "找不到共享文件夹：$target"
            exit 1
        fi
        share_list="$resolved"
    fi

    echo "$share_list" | while IFS= read -r share_path; do
        [ -z "$share_path" ] && continue
        local share_name
        share_name=$(basename "$share_path")
        local recycle_dir="${share_path}/@Recycle"

        [ -d "$recycle_dir" ] || continue

        local files
        files=$(find "$recycle_dir" -type f 2>/dev/null | sort)
        [ -z "$files" ] && continue

        printf '\n[共享文件夹: %s]\n' "$share_name"
        printf '%-60s %10s  %16s  %s\n' "回收站路径（相对）" "大小" "修改时间" "原始文件名"
        printf '%s\n' "----------------------------------------------------------------------------------------------------------------------------"

        echo "$files" | while IFS= read -r fpath; do
            [ -z "$fpath" ] && continue
            local rel_path="${fpath#$recycle_dir/}"
            local fname
            fname=$(basename "$fpath")
            local original_name
            original_name=$(strip_version "$fname")
            local fsize
            fsize=$(stat -c '%s' "$fpath" 2>/dev/null || echo 0)
            local mtime
            mtime=$(file_mtime "$fpath")
            local display_size
            display_size=$(human_size "$fsize")

            printf '%-60s %10s  %16s  %s\n' \
                "$rel_path" \
                "$display_size" \
                "$mtime" \
                "$original_name"
        done

        local total_bytes
        total_bytes=$(dir_bytes "$recycle_dir")
        local total_files
        total_files=$(find "$recycle_dir" -type f 2>/dev/null | wc -l)
        printf '\n  小计：%d 个文件，%s\n' "$total_files" "$(human_size "$total_bytes")"
    done

    if [ -z "$target" ] || [ "$target" = "all" ]; then
        if [ -d "$LOCAL_RECYCLE" ]; then
            local lfiles
            lfiles=$(find "$LOCAL_RECYCLE" -type f 2>/dev/null | wc -l)
            if [ "$lfiles" -gt 0 ]; then
                printf '\n[本地回收站: %s]\n' "$LOCAL_RECYCLE"
                find "$LOCAL_RECYCLE" -type f 2>/dev/null | sort | while IFS= read -r fpath; do
                    local rel="${fpath#$LOCAL_RECYCLE}"
                    local fsize
                    fsize=$(stat -c '%s' "$fpath" 2>/dev/null || echo 0)
                    local mtime
                    mtime=$(file_mtime "$fpath")
                    printf '  %-55s %10s  %16s\n' "$rel" "$(human_size "$fsize")" "$mtime"
                done
                local lbytes
                lbytes=$(dir_bytes "$LOCAL_RECYCLE")
                printf '\n  小计：%d 个文件，%s\n' "$lfiles" "$(human_size "$lbytes")"
            fi
        fi
    fi
}

cmd_size() {
    local target="$1"
    local share_list=""

    if [ -z "$target" ] || [ "$target" = "all" ]; then
        share_list=$(list_all_shares)
    else
        local resolved
        resolved=$(resolve_share_name "$target")
        if [ -z "$resolved" ]; then
            log_error "找不到共享文件夹：$target"
            exit 1
        fi
        share_list="$resolved"
    fi

    echo "$share_list" | while IFS= read -r share_path; do
        [ -z "$share_path" ] && continue
        local recycle_dir="${share_path}/@Recycle"
        [ -d "$recycle_dir" ] || continue
        local share_name
        share_name=$(basename "$share_path")
        local bytes
        bytes=$(dir_bytes "$recycle_dir")
        local files
        files=$(find "$recycle_dir" -type f 2>/dev/null | wc -l)
        printf '  %-20s %d 个文件  %s\n' "$share_name" "$files" "$(human_size "$bytes")"
    done

    if [ -z "$target" ] || [ "$target" = "all" ]; then
        if [ -d "$LOCAL_RECYCLE" ]; then
            local lbytes
            lbytes=$(dir_bytes "$LOCAL_RECYCLE")
            local lfiles
            lfiles=$(find "$LOCAL_RECYCLE" -type f 2>/dev/null | wc -l)
            [ "$lfiles" -gt 0 ] && \
                printf '  %-20s %d 个文件  %s\n' "[本地回收站]" "$lfiles" "$(human_size "$lbytes")"
        fi
    fi
}

cmd_restore() {
    local recycle_path="$1"
    local conflict_mode="$2"

    if [ ! -f "$recycle_path" ]; then
        log_error "路径不存在或不是文件：$recycle_path"
        exit 1
    fi

    case "$recycle_path" in
        *"/@Recycle/"*)  ;;
        "${LOCAL_RECYCLE}"*) ;;
        *)
            log_error "路径不在回收站目录中：$recycle_path"
            exit 1
            ;;
    esac

    local dest_path=""
    local original_filename=""
    local recycle_filename
    recycle_filename=$(basename "$recycle_path")
    original_filename=$(strip_version "$recycle_filename")

    case "$recycle_path" in
        *"/@Recycle/"*)
            local share_root
            share_root=$(echo "$recycle_path" | sed 's|\(.*\)/@Recycle/.*|\1|')
            local rel_under_recycle
            rel_under_recycle=$(echo "$recycle_path" | sed 's|.*/@Recycle/||')
            local rel_dir
            rel_dir=$(dirname "$rel_under_recycle")

            # 删除时保存的是完整软链接路径 (如 share/Public/dir/file.txt)，
            # 恢复时需要剥离 share/<共享名>/ 前缀，避免路径嵌套。
            # 例如: share/Public/docs/file.txt → docs/file.txt
            local raw_dir="$rel_dir"
            case "$raw_dir" in
                share/*/*)
                    # 剥离 share/<share_name>/ 前缀
                    raw_dir=$(echo "$raw_dir" | sed 's|^share/[^/]*/||')
                    ;;
                share/*)
                    # 如果是 share/<name> 本身（根目录下的文件）
                    raw_dir="."
                    ;;
            esac

            if [ "$raw_dir" = "." ]; then
                dest_path="${share_root}/${original_filename}"
            else
                dest_path="${share_root}/${raw_dir}/${original_filename}"
            fi
            ;;
        "$LOCAL_RECYCLE"*)
            local stripped="${recycle_path#$LOCAL_RECYCLE}"
            dest_path="$stripped"
            original_filename=$(basename "$stripped")
            ;;
    esac

    local dest_dir
    dest_dir=$(dirname "$dest_path")

    log_info "回收站路径 : $recycle_path"
    log_info "还原目标   : $dest_path"

    if [ -e "$dest_path" ]; then
        case "$conflict_mode" in
            overwrite)
                log_info "目标已存在，执行覆盖（--overwrite）"
                ;;
            rename)
                local n=1
                local new_dest
                while true; do
                    local base ext name_only
                    name_only=$(basename "$original_filename")
                    ext="${name_only##*.}"
                    base="${name_only%.*}"
                    if [ "$ext" = "$name_only" ]; then
                        new_dest="${dest_dir}/${name_only}_restored${n}"
                    else
                        new_dest="${dest_dir}/${base}_restored${n}.${ext}"
                    fi
                    [ ! -e "$new_dest" ] && break
                    n=$((n + 1))
                done
                dest_path="$new_dest"
                log_info "目标已存在，将恢复为：$dest_path（--rename）"
                ;;
            *)
                log_error "目标路径已存在文件：$dest_path"
                log_error "请选择冲突处理方式后重新调用："
                log_error "  --overwrite  覆盖现有文件"
                log_error "  --rename     保留现有文件，恢复的文件自动重命名"
                exit 2
                ;;
        esac
    fi

    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir" 2>/dev/null || {
            log_error "无法创建目标目录：$dest_dir"
            exit 1
        }
        log_info "目标目录不存在，已创建：$dest_dir"
    fi

    if mv "$recycle_path" "$dest_path" 2>/dev/null; then
        log_info "恢复成功：$dest_path"
        local recycle_sub_dir
        recycle_sub_dir=$(dirname "$recycle_path")
        rmdir "$recycle_sub_dir" 2>/dev/null || true
    else
        log_error "恢复失败（权限不足？）：$recycle_path → $dest_path"
        exit 1
    fi
}

# ══════════════════════════════════════════════
# 删除逻辑核心
# ══════════════════════════════════════════════

get_recycle_name() {
    local dir="$1" name="$2" n=1
    [ ! -e "${dir}/${name}" ] && { echo "$name"; return; }
    while true; do
        local c="${name}[${n}]"
        [ ! -e "${dir}/${c}" ] && { echo "$c"; return; }
        n=$((n + 1))
    done
}

# ══════════════════════════════════════════════
# 合并目录到回收站（同名目录已存在时调用）
# 对比两个目录树，同名文件在回收站中重命名后移入
# ══════════════════════════════════════════════

merge_dirs_to_recycle() {
    local src_dir="$1"          # 原始目录路径
    local recycle_dir="$2"      # 回收站中同名目录路径
    local share_root="$3"       # 共享文件夹根路径
    local filename
    filename=$(basename "$src_dir")

    # 递归遍历原始目录中的每个文件/目录
    find "$src_dir" -print0 2>/dev/null | while IFS= read -r -d '' item; do
        local rel_path="${item#$src_dir}"   # 相对路径（含开头的 /）
        local abs_dest="${recycle_dir}${rel_path}"
        local abs_dest_dir
        abs_dest_dir=$(dirname "$abs_dest")

        if [ -d "$item" ]; then
            # 子目录：直接在回收站同名目录中创建对应子目录结构
            mkdir -p "$abs_dest" 2>/dev/null
        else
            # 文件：确保父目录存在
            mkdir -p "$abs_dest_dir" 2>/dev/null

            if [ -f "$abs_dest" ]; then
                # 回收站已有同名文件 → 重命名后移入（[1], [2]...）
                local base dest_name
                base=$(basename "$item")
                dest_name=$(get_recycle_name "$abs_dest_dir" "$base")
                log_info "  重命名 → ${dest_name}（已存在同名）"
                if mv "$item" "${abs_dest_dir}/${dest_name}" 2>/dev/null; then
                    RECYCLED_COUNT=$((RECYCLED_COUNT+1))
                else
                    log_error "移动失败: $item"
                    ERROR_COUNT=$((ERROR_COUNT+1))
                fi
            else
                # 回收站无同名文件 → 直接移动
                if mv "$item" "$abs_dest" 2>/dev/null; then
                    RECYCLED_COUNT=$((RECYCLED_COUNT+1))
                else
                    log_error "移动失败: $item"
                    ERROR_COUNT=$((ERROR_COUNT+1))
                fi
            fi
        fi
    done

    # ── 清理源目录中的空子目录（从内到外逐层删除）────────────────
    # 第1步：删除所有 .@__thumb（QNAP缩略图缓存目录）
    find "$src_dir" -name ".@__thumb" -type d 2>/dev/null | while IFS= read -r td; do
        rmdir "$td" 2>/dev/null && log_info "  清理缩略图缓存: $td"
    done

    # 第2步：从内到外逐层删除所有空目录
    find "$src_dir" -depth -type d 2>/dev/null | while IFS= read -r empty_dir; do
        rmdir "$empty_dir" 2>/dev/null && log_info "  清理空目录: $empty_dir"
    done

    # 第3步：尝试删除源目录自身
    if rmdir "$src_dir" 2>/dev/null; then
        log_info "→ @Recycle: $filename（目录合并）"
        RECYCLED_COUNT=$((RECYCLED_COUNT+1))
    else
        log_info "  目录仍有残留内容，已保留: $src_dir"
    fi
}

move_share_file() {
    local target="$1"
    local abs share_root filename recycle_dir recycle_name

    if [ ! -e "$target" ]; then
        [ "$FORCE" -eq 1 ] && return 0
        log_error "文件不存在: $target"; ERROR_COUNT=$((ERROR_COUNT+1)); return 1
    fi

    if [ -d "$target" ]; then
        # 目录：同名目录已存在时，遍历对比同名文件并重命名后移入
        abs=$(abs_path_of "$target")
        if [ "$abs" = "ERROR_INVALID_PATH" ] || [ -z "$abs" ]; then
            log_error "无法解析目录的绝对路径: $target"
            ERROR_COUNT=$((ERROR_COUNT+1)); return 1
        fi

        share_root=$(find_share_root "$abs")
        if [ -z "$share_root" ]; then
            log_error "无法定位所属共享文件夹（路径: $abs）"
            ERROR_COUNT=$((ERROR_COUNT+1)); return 1
        fi
        filename=$(basename "$abs")
        recycle_target="${share_root}/@Recycle/${filename}"

        if [ -e "$recycle_target" ]; then
            # 同名目录已存在 → 对比结构，同名文件重命名后再移入
            log_info "回收站已有同名目录，将对比并合并: $filename"
            merge_dirs_to_recycle "$abs" "$recycle_target" "$share_root"
            return
        fi

        if mv "$abs" "${share_root}/@Recycle/${filename}" 2>/dev/null; then
            log_info "→ @Recycle: $abs (目录)"
            RECYCLED_COUNT=$((RECYCLED_COUNT+1))
        else
            log_error "移动目录失败（权限不足？）: $abs"
            ERROR_COUNT=$((ERROR_COUNT+1)); return 1
        fi
        return
    fi

    abs=$(abs_path_of "$target")
    if [ "$abs" = "ERROR_INVALID_PATH" ]; then
        log_error "无法解析目标的绝对路径: $target"
        ERROR_COUNT=$((ERROR_COUNT+1)); return 1
    fi

    share_root=$(find_share_root "$abs")
    if [ -z "$share_root" ] || [ "$abs" = "$share_root" ]; then
        log_error "无效路径或为共享根目录: $abs"
        ERROR_COUNT=$((ERROR_COUNT+1)); return 1
    fi

    case "$abs" in
        "${share_root}/@Recycle"*)
            log_error "拒绝操作回收站目录: $abs"; ERROR_COUNT=$((ERROR_COUNT+1)); return 1 ;;
    esac

    filename=$(basename "$abs")
    
    local parent_dir
    parent_dir=$(dirname "$abs")
    
    if [ "$parent_dir" = "$share_root" ]; then
        recycle_dir="${share_root}/@Recycle"
    else
        local rel_dir="${parent_dir#$share_root/}"
        recycle_dir="${share_root}/@Recycle/${rel_dir}"
    fi

    mkdir -p "$recycle_dir" 2>/dev/null || {
        log_error "无法创建回收站目录: $recycle_dir"
        ERROR_COUNT=$((ERROR_COUNT+1)); return 1
    }

    recycle_name=$(get_recycle_name "$recycle_dir" "$filename")

    if mv "$abs" "${recycle_dir}/${recycle_name}" 2>/dev/null; then
        log_info "→ @Recycle: $abs"
        [ "$recycle_name" != "$filename" ] && log_info "  (重命名 → ${recycle_name} 避免覆盖)"
        RECYCLED_COUNT=$((RECYCLED_COUNT+1))
    else
        log_error "移动失败（权限不足？）: $abs"
        ERROR_COUNT=$((ERROR_COUNT+1)); return 1
    fi
}

move_local_file() {
    local target="$1"
    local abs dest_dir dest_path

    if [ ! -e "$target" ]; then
        [ "$FORCE" -eq 1 ] && return 0
        log_error "路径不存在: $target"; ERROR_COUNT=$((ERROR_COUNT+1)); return 1
    fi

    if [ -d "$target" ] && [ "$RECURSIVE" -eq 0 ]; then
        log_error "$target 是目录，请使用 -r 参数"
        ERROR_COUNT=$((ERROR_COUNT+1)); return 1
    fi

    abs=$(abs_path_of "$target")
    if [ "$abs" = "ERROR_INVALID_PATH" ] || [ -z "$abs" ]; then
        log_error "无法解析绝对路径，中断本地安全删除以防误伤"
        ERROR_COUNT=$((ERROR_COUNT+1)); return 1
    fi

    case "$abs" in
        "$LOCAL_RECYCLE"*)
            log_error "拒绝操作本地回收站: $abs"
            ERROR_COUNT=$((ERROR_COUNT+1)); return 1 ;;
    esac

    dest_path="${LOCAL_RECYCLE}${abs}"
    dest_dir=$(dirname "$dest_path")

    mkdir -p "$dest_dir" 2>/dev/null || {
        log_error "无法创建本地回收站目录: $dest_dir"
        ERROR_COUNT=$((ERROR_COUNT+1)); return 1
    }

    if mv -f "$abs" "$dest_path" 2>/dev/null; then
        log_info "→ 本地回收站: $abs"
        RECYCLED_COUNT=$((RECYCLED_COUNT+1))
    else
        log_error "移动失败（权限不足？）: $abs"
        ERROR_COUNT=$((ERROR_COUNT+1)); return 1
    fi
}

route_delete() {
    local target="$1"
    local abs share_root

    case "$target" in
        /share/*)
            abs=$(abs_path_of "$target")
            if [ "$abs" != "ERROR_INVALID_PATH" ]; then
                share_root=$(find_share_root "$abs")
                [ -n "$share_root" ] && { move_share_file "$target"; return; }
            fi
            ;;
    esac
    move_local_file "$target"
}

# ══════════════════════════════════════════════
# 参数解析入口
# ══════════════════════════════════════════════

RECURSIVE=0
FORCE=0

case "$1" in
    --list)
        shift 1
        cmd_list "${1:-all}"
        exit 0
        ;;
    --size)
        shift 1
        cmd_size "${1:-all}"
        exit 0
        ;;
    --restore)
        shift 1
        RESTORE_PATH=""
        CONFLICT_MODE=""
        while [ $# -gt 0 ]; do
            case "$1" in
                --overwrite) 
                    CONFLICT_MODE="overwrite"
                    shift 1 
                    ;;
                --rename)    
                    CONFLICT_MODE="rename"
                    shift 1 
                    ;;
                *)
                    if [ -z "$RESTORE_PATH" ]; then
                        RESTORE_PATH="$1"
                    else
                        log_error "--restore 只支持单个文件路径"
                        exit 1
                    fi
                    shift 1
                    ;;
            esac
        done
        if [ -z "$RESTORE_PATH" ]; then
            log_error "--restore 需要指定回收站内的文件路径"
            exit 1
        fi
        cmd_restore "$RESTORE_PATH" "$CONFLICT_MODE"
        exit $?
        ;;
    -h|--help)
        usage
        ;;
esac

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage ;;
        -r|-R)     RECURSIVE=1; shift 1 ;;
        -f)        FORCE=1; shift 1 ;;
        -rf|-rF|-Rf|-RF|-fr|-fR|-Fr|-FR) RECURSIVE=1; FORCE=1; shift 1 ;;
        --)        shift 1; break ;;
        -*)        shift 1 ;;
        *)         break ;;
    esac
done

[ $# -eq 0 ] && {
    log_error "未指定目标路径"
    exit 1
}

for target in "$@"; do
    route_delete "$target"
done

[ "$RECYCLED_COUNT" -gt 0 ] && log_info "完成：${RECYCLED_COUNT} 个文件/目录已移至回收站"
[ "$ERROR_COUNT"    -gt 0 ] && { log_error "${ERROR_COUNT} 个操作失败"; exit 1; }
exit 0
