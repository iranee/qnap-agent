#!/bin/sh
#
# openlist.sh — qnap-agent OpenList 文件管理工具（Shell + curl 版）
#
# 用法: sh openlist.sh <command> [options]
# 依赖: curl（系统内置）、jq（workspace/tools/jq）
#
# Commands:
#   login, list, get, mkdir, rename, move, copy, remove,
#   search, link, upload, batch-rename, regex-rename,
#   share-list, share-create, share-get, share-update, share-delete,
#   index-build, index-update, index-clear, index-progress,
#   settings-list, settings-get, settings-save, settings-delete,
#   storage-list, storage-get, storage-create, storage-update, storage-delete,
#   storage-enable, storage-disable, storage-load-all,
#   dirs, recursive-move, remove-empty-directory, add-offline-download,
#   driver-list, driver-names

# ── 路径设置 ──────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="$(dirname "$(dirname "$SKILL_DIR")")"
CONFIG_FILE="${SKILL_DIR}/config.json"
TOOLS_DIR="${WORKSPACE_DIR}/tools"

# jq：优先 tools/jq，其次系统 jq
if [ -x "${TOOLS_DIR}/jq" ]; then
    JQ="${TOOLS_DIR}/jq"
elif command -v jq >/dev/null 2>&1; then
    JQ="jq"
else
    printf '{"code":400,"message":"jq 未找到，请下载到 workspace/tools/jq","data":null}\n'
    exit 1
fi

# ── 全局状态 ──────────────────────────────────────────────────────────────────

BASE_URL=""
TOKEN=""
OUTPUT_JSON=0
OUTPUT_QUIET=0

# ── 配置读写 ──────────────────────────────────────────────────────────────────

load_config() {
    [ -f "$CONFIG_FILE" ] || return
    BASE_URL=$(${JQ} -r '.base_url // ""' "$CONFIG_FILE" 2>/dev/null || true)
    TOKEN=$(${JQ} -r '.token // ""' "$CONFIG_FILE" 2>/dev/null || true)
}

save_config() {
    ${JQ} -n \
        --arg base_url "$1" \
        --arg username "$2" \
        --arg token "$3" \
        '{"base_url":$base_url,"username":$username,"token":$token}' \
        > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE" 2>/dev/null || true
}

_resolve() {
    load_config
    [ -n "$OPT_URL" ]   && BASE_URL="$OPT_URL"
    [ -n "$OPT_TOKEN" ] && TOKEN="$OPT_TOKEN"
    BASE_URL="${BASE_URL%/}"
    [ -z "$BASE_URL" ] && _exit_error "未指定 OpenList 地址，请先执行 login 或传入 --url"
}

# ── HTTP 工具 ─────────────────────────────────────────────────────────────────

_post() {
    local path="$1" data="$2" timeout="${3:-30}"
    local tmp; tmp=$(mktemp /tmp/ol_XXXXXX)
    curl -s -X POST \
        -H "Authorization: ${TOKEN}" \
        -H "Content-Type: application/json" \
        --max-time "$timeout" \
        -d "$data" \
        -o "$tmp" \
        "${BASE_URL}${path}" 2>/dev/null \
    && cat "$tmp" \
    || printf '{"code":998,"message":"连接失败或超时","data":null}'
    rm -f "$tmp"
}

_get() {
    local path="$1" query="${2:-}" timeout="${3:-30}"
    local url="${BASE_URL}${path}"
    [ -n "$query" ] && url="${url}?${query}"
    curl -s \
        -H "Authorization: ${TOKEN}" \
        --max-time "$timeout" \
        "$url" 2>/dev/null \
    || printf '{"code":998,"message":"连接失败或超时","data":null}'
}

_put_upload() {
    local file_path="$1" local_file="$2" overwrite="${3:-true}" as_task="${4:-false}"
    local encoded; encoded=$(printf '%s' "$file_path" | ${JQ} -sRr @uri)
    local extra=""
    [ "$as_task" = "true" ] && extra="-H \"As-Task: true\""
    curl -s -X PUT \
        -H "Authorization: ${TOKEN}" \
        -H "File-Path: ${encoded}" \
        -H "Overwrite: ${overwrite}" \
        --max-time 300 \
        -F "file=@${local_file};filename=$(basename "$local_file")" \
        "${BASE_URL}/api/fs/form" 2>/dev/null \
    || printf '{"code":998,"message":"上传失败","data":null}'
}

# ── 输出 ──────────────────────────────────────────────────────────────────────

_output() {
    local r="$1"
    if [ "$OUTPUT_JSON" = "1" ]; then
        printf '%s' "$r" | ${JQ} -c .
    elif [ "$OUTPUT_QUIET" = "1" ]; then
        local code; code=$(printf '%s' "$r" | ${JQ} -r '.code')
        if [ "$code" = "200" ]; then
            printf '%s' "$r" | ${JQ} -r '
                .data |
                if type == "string" then .
                elif .token?       then .token
                elif .share_link?  then .share_link
                elif .raw_url? or .proxy_url? then (.proxy_url // .raw_url)
                elif .content?     then .content[].name
                else tostring end
            ' 2>/dev/null || printf '%s' "$r" | ${JQ} -r '.data // empty'
        else
            printf '%s' "$r" | ${JQ} -r '.message'
        fi
    else
        printf '%s' "$r" | ${JQ} .
    fi
}

_exit_error() {
    printf '{"code":400,"message":"%s","data":null}\n' "$1"
    exit 1
}

# ── 命令实现 ──────────────────────────────────────────────────────────────────

cmd_login() {
    [ -z "$OPT_URL" ]      && _exit_error "--url 必填"
    [ -z "$OPT_USERNAME" ] && _exit_error "--username 必填"
    [ -z "$OPT_PASSWORD" ] && _exit_error "--password 必填"
    local url="${OPT_URL%/}"
    local result
    result=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --max-time 15 \
        -d "{\"username\":\"${OPT_USERNAME}\",\"password\":\"${OPT_PASSWORD}\"}" \
        "${url}/api/auth/login" 2>/dev/null) || _exit_error "登录请求失败"
    local code; code=$(printf '%s' "$result" | ${JQ} -r '.code')
    if [ "$code" = "200" ]; then
        local tok; tok=$(printf '%s' "$result" | ${JQ} -r '.data.token')
        save_config "$url" "$OPT_USERNAME" "$tok"
        result=$(${JQ} -n --arg t "$tok" \
            '{"code":200,"message":"登录成功，凭据已保存","data":{"token":$t}}')
    fi
    _output "$result"
}

cmd_list() {
    _resolve
    _output "$(_post "/api/fs/list" "$(${JQ} -n \
        --arg path "${OPT_PATH:-/}" \
        --argjson page "${OPT_PAGE:-1}" \
        --argjson per_page "${OPT_PER_PAGE:-50}" \
        --argjson refresh "${OPT_REFRESH:-false}" \
        '{"path":$path,"page":$page,"per_page":$per_page,"refresh":$refresh}')")"
}

cmd_get() {
    _resolve
    [ -z "$OPT_PATH" ] && _exit_error "--path 必填"
    _output "$(_post "/api/fs/get" "$(${JQ} -n --arg p "$OPT_PATH" '{"path":$p}')")"
}

cmd_mkdir() {
    _resolve
    [ -z "$OPT_PATH" ] && _exit_error "--path 必填"
    _output "$(_post "/api/fs/mkdir" "$(${JQ} -n --arg p "$OPT_PATH" '{"path":$p}')")"
}

cmd_rename() {
    _resolve
    [ -z "$OPT_PATH" ]     && _exit_error "--path 必填"
    [ -z "$OPT_NEW_NAME" ] && _exit_error "--new-name 必填"
    _output "$(_post "/api/fs/rename" "$(${JQ} -n \
        --arg path "$OPT_PATH" --arg name "$OPT_NEW_NAME" \
        '{"path":$path,"name":$name}')")"
}

_move_copy() {
    local endpoint="$1"
    [ -z "$OPT_PATH" ] && _exit_error "--path 必填"
    [ -z "$OPT_DST" ]  && _exit_error "--dst 必填"
    local src_dir; src_dir=$(dirname "$OPT_PATH")
    local src_name; src_name=$(basename "$OPT_PATH")
    [ -z "$src_dir" ] && src_dir="/"
    _output "$(_post "$endpoint" "$(${JQ} -n \
        --arg src_dir "$src_dir" \
        --arg dst_dir "${OPT_DST%/}" \
        --arg name "${OPT_NEW_NAME:-$src_name}" \
        '{"src_dir":$src_dir,"dst_dir":$dst_dir,"names":[$name]}')")"
}
cmd_move()           { _resolve; _move_copy "/api/fs/move"; }
cmd_copy()           { _resolve; _move_copy "/api/fs/copy"; }
cmd_recursive_move() { _resolve; _move_copy "/api/fs/recursive_move"; }

cmd_remove() {
    _resolve
    [ -z "$OPT_NAMES" ] && _exit_error "--names 必填"
    local dir; dir="${OPT_PATH:-/}"
    local nj; nj=$(printf '%s' "$OPT_NAMES" | \
        ${JQ} -Rc 'split(",") | map(ltrimstr(" ") | rtrimstr(" "))')
    _output "$(_post "/api/fs/remove" "$(${JQ} -n \
        --argjson names "$nj" --arg dir "$dir" \
        '{"names":$names,"dir":$dir}')")"
}

cmd_link() {
    _resolve
    [ -z "$OPT_PATH" ] && _exit_error "--path 必填"
    local method; method=$(printf '%s' "${OPT_METHOD:-GET}" | tr '[:lower:]' '[:upper:]')
    _output "$(_post "/api/fs/link" "$(${JQ} -n \
        --arg path "$OPT_PATH" --arg method "$method" \
        '{"path":$path,"method":$method}')")"
}

cmd_upload() {
    _resolve
    [ -z "$OPT_PATH" ] && _exit_error "--path 必填"
    [ -z "$OPT_FILE" ] && _exit_error "--file 必填"
    [ ! -f "$OPT_FILE" ] && _exit_error "本地文件不存在: $OPT_FILE"
    local fp="$OPT_PATH"
    case "$fp" in */) fp="${fp}$(basename "$OPT_FILE")" ;; esac
    _output "$(_put_upload "$fp" "$OPT_FILE" "${OPT_REPLACE:-false}" "${OPT_ASYNC_UPLOAD:-false}")"
}

cmd_search() {
    _resolve
    [ -z "$OPT_KEYWORD" ] && _exit_error "--keyword 必填"
    local path="${OPT_PATH:-/}" kw="$OPT_KEYWORD"
    local page="${OPT_PAGE:-1}" per_page="${OPT_PER_PAGE:-50}"
    local max_depth="${OPT_MAX_DEPTH:-6}" use_api="${OPT_USE_API:-1}"
    local rf; rf=$(mktemp /tmp/ol_results_XXXXXX)

    if [ "$use_api" = "1" ]; then
        local api_r code
        api_r=$(_post "/api/fs/search" "$(${JQ} -n \
            --arg parent "$path" --arg keywords "$kw" \
            --argjson page "$page" --argjson per_page "$per_page" \
            '{"parent":$parent,"keywords":$keywords,"page":$page,"per_page":$per_page}')")
        code=$(printf '%s' "$api_r" | ${JQ} -r '.code // 0')
        [ "$code" = "200" ] && \
            printf '%s' "$api_r" | ${JQ} -c '.data.content[]?' > "$rf" 2>/dev/null || true
    fi

    [ ! -s "$rf" ] && _traverse_search "$path" "$kw" "$max_depth" "$rf"

    local result
    result=$(${JQ} -sc \
        --argjson page "$page" --argjson per_page "$per_page" \
        '{"code":200,"message":"success","data":{"content":.,"total":length,"page":$page,"per_page":$per_page}}' \
        "$rf" 2>/dev/null \
    || printf '{"code":200,"message":"success","data":{"content":[],"total":0}}')
    rm -f "$rf"
    _output "$result"
}

_traverse_search() {
    local root="$1" keyword="$2" max_depth="$3" outfile="$4"
    local kw_lower; kw_lower=$(printf '%s' "$keyword" | tr '[:upper:]' '[:lower:]')
    local qf; qf=$(mktemp /tmp/ol_queue_XXXXXX)
    printf '0:%s\n' "$root" > "$qf"
    local count=0

    while [ -s "$qf" ] && [ "$count" -lt 200 ]; do
        local entry; entry=$(head -1 "$qf")
        tail -n +2 "$qf" > "${qf}.tmp" && mv "${qf}.tmp" "$qf"
        local depth="${entry%%:*}"
        local cur="${entry#*:}"

        local resp code
        resp=$(_post "/api/fs/list" "$(${JQ} -n \
            --arg path "$cur" '{"path":$path,"page":1,"per_page":200}')" 2>/dev/null) || continue
        code=$(printf '%s' "$resp" | ${JQ} -r '.code // 0')
        [ "$code" != "200" ] && continue

        # 输出匹配文件（紧凑 JSON，写入结果文件）
        printf '%s' "$resp" | ${JQ} -c \
            --arg kw "$kw_lower" --arg parent "$cur" '
            .data.content[]? |
            . + {"parent": $parent} |
            select((.name | ascii_downcase) | contains($kw))
        ' >> "$outfile" 2>/dev/null || true

        # 子目录加入队列
        if [ "$depth" -lt "$max_depth" ]; then
            local nd=$(( depth + 1 ))
            printf '%s' "$resp" | ${JQ} -r \
                --argjson nd "$nd" --arg parent "$cur" '
                .data.content[]? | select(.is_dir == true) |
                (($nd | tostring) + ":" + ($parent | rtrimstr("/")) + "/" + .name)
            ' >> "$qf" 2>/dev/null || true
        fi

        count=$(( count + 1 ))
    done
    rm -f "$qf"
}

cmd_dirs() {
    _resolve
    _output "$(_post "/api/fs/dirs" "$(${JQ} -n \
        --arg path "${OPT_PATH:-/}" \
        --argjson page "${OPT_PAGE:-1}" \
        --argjson per_page "${OPT_PER_PAGE:-50}" \
        --argjson refresh "${OPT_REFRESH:-false}" \
        '{"path":$path,"page":$page,"per_page":$per_page,"refresh":$refresh}')")"
}

cmd_remove_empty_directory() {
    _resolve
    [ -z "$OPT_PATH" ] && _exit_error "--path 必填"
    _output "$(_post "/api/fs/remove_empty_directory" \
        "$(${JQ} -n --arg src_dir "$OPT_PATH" '{"src_dir":$src_dir}')")"
}

cmd_batch_rename() {
    _resolve
    [ -z "$OPT_SRC_DIR" ]      && _exit_error "--src-dir 必填"
    [ -z "$OPT_RENAME_PAIRS" ] && _exit_error "--rename-pairs 必填"
    local pj; pj=$(printf '%s' "$OPT_RENAME_PAIRS" | ${JQ} -Rc '
        split(",") | map(ltrimstr(" ") | split(":") |
        select(length >= 2) | {"src_name":.[0],"new_name":.[1]})')
    _output "$(_post "/api/fs/batch_rename" "$(${JQ} -n \
        --arg src_dir "$OPT_SRC_DIR" --argjson ro "$pj" \
        '{"src_dir":$src_dir,"rename_objects":$ro}')")"
}

cmd_regex_rename() {
    _resolve
    [ -z "$OPT_SRC_DIR" ]   && _exit_error "--src-dir 必填"
    [ -z "$OPT_SRC_REGEX" ] && _exit_error "--src-regex 必填"
    [ -z "$OPT_DST_REGEX" ] && _exit_error "--dst-regex 必填"
    _output "$(_post "/api/fs/regex_rename" "$(${JQ} -n \
        --arg src_dir "$OPT_SRC_DIR" \
        --arg src_name_regex "$OPT_SRC_REGEX" \
        --arg new_name_regex "$OPT_DST_REGEX" \
        '{"src_dir":$src_dir,"src_name_regex":$src_name_regex,"new_name_regex":$new_name_regex}')")"
}

cmd_add_offline_download() {
    _resolve
    [ -z "$OPT_PATH" ] && _exit_error "--path 必填"
    [ -z "$OPT_URLS" ] && _exit_error "--urls 必填"
    local uj; uj=$(printf '%s' "$OPT_URLS" | ${JQ} -Rc 'split(",") | map(ltrimstr(" "))')
    local tool=""; [ -n "$OPT_TOOLS" ] && tool=$(printf '%s' "$OPT_TOOLS" | cut -d',' -f1)
    _output "$(_post "/api/fs/add_offline_download" "$(${JQ} -n \
        --arg path "$OPT_PATH" --argjson urls "$uj" --arg tool "$tool" \
        --arg dp "${OPT_DELETE_POLICY:-delete_on_upload_succeed}" \
        --argjson tc "${OPT_THREAD_COUNT:-2}" \
        '{"path":$path,"urls":$urls,"tool":$tool,"delete_policy":$dp,"thread_count":$tc}')")"
}

# ── 分享管理 ──────────────────────────────────────────────────────────────────

_inject_share_link() {
    ${JQ} --arg base "$BASE_URL" '
        def add_link: if .id then . + {"share_link": ($base + "/@s/" + .id)} else . end;
        if .code == 200 then
            if .data | type == "object" then
                if .data.content then .data.content = [.data.content[] | add_link]
                else .data = (.data | add_link) end
            else . end
        else . end'
}

cmd_share_list() {
    _resolve
    _output "$(_post "/api/share/list" "$(${JQ} -n \
        --argjson page "${OPT_PAGE:-1}" --argjson per_page "${OPT_PER_PAGE:-30}" \
        '{"page":$page,"per_page":$per_page}')"\
    | _inject_share_link)"
}
cmd_share_get() {
    _resolve; [ -z "$OPT_ID" ] && _exit_error "--id 必填"
    _output "$(_get "/api/share/get" "id=${OPT_ID}" | _inject_share_link)"
}
cmd_share_create() {
    _resolve; [ -z "$OPT_FILES" ] && _exit_error "--files 必填"
    local fj; fj=$(printf '%s' "$OPT_FILES" | ${JQ} -Rc 'split(",") | map(ltrimstr(" "))')
    local d; d=$(${JQ} -n --argjson files "$fj" '{"files":$files}')
    [ -n "$OPT_PASSWORD" ] && d=$(printf '%s' "$d" | ${JQ} --arg pwd "$OPT_PASSWORD" '. + {"pwd":$pwd}')
    _output "$(_post "/api/share/create" "$d" | _inject_share_link)"
}
cmd_share_update() {
    _resolve; [ -z "$OPT_ID" ] && _exit_error "--id 必填"
    local d; d=$(${JQ} -n --arg id "$OPT_ID" '{"id":$id}')
    [ -n "$OPT_PASSWORD" ]  && d=$(printf '%s' "$d" | ${JQ} --arg v "$OPT_PASSWORD" '. + {"pwd":$v}')
    [ -n "$OPT_EXPIRE_AT" ] && d=$(printf '%s' "$d" | ${JQ} --arg v "$OPT_EXPIRE_AT" '. + {"expires":$v}')
    _output "$(_post "/api/share/update" "$d")"
}
cmd_share_delete() {
    _resolve; [ -z "$OPT_ID" ] && _exit_error "--id 必填"
    _output "$(_post "/api/share/delete" "$(${JQ} -n --arg id "$OPT_ID" '{"id":$id}')")"
}

# ── 索引管理 ──────────────────────────────────────────────────────────────────

cmd_index_build()    { _resolve; _output "$(_post "/api/admin/index/build" \
    "$([ "${OPT_ASYNC:-0}" = "1" ] && echo '{"async":true}' || echo '{}')" 120)"; }
cmd_index_update()   {
    _resolve
    local pj="[]"
    [ -n "$OPT_PATHS" ] && pj=$(printf '%s' "$OPT_PATHS" | ${JQ} -Rc 'split(",") | map(ltrimstr(" "))')
    _output "$(_post "/api/admin/index/update" "$(${JQ} -n --argjson paths "$pj" '{"paths":$paths}')" 60)"
}
cmd_index_clear()    { _resolve; _output "$(_post "/api/admin/index/clear" '{}')"; }
cmd_index_progress() { _resolve; _output "$(_get "/api/admin/index/progress")"; }

# ── 设置管理 ──────────────────────────────────────────────────────────────────

cmd_settings_list() {
    _resolve
    local q=""; [ -n "$OPT_GROUP" ] && q="group=${OPT_GROUP}"
    _output "$(_get "/api/admin/setting/list" "$q")"
}
cmd_settings_get() {
    _resolve; [ -z "$OPT_KEY" ] && _exit_error "--key 必填"
    _output "$(_get "/api/admin/setting/get" "key=${OPT_KEY}")"
}
cmd_settings_save() {
    _resolve; [ -z "$OPT_KEY" ] && _exit_error "--key 必填"; [ -z "$OPT_VALUE" ] && _exit_error "--value 必填"
    # API 期望数组格式: [{"key":"...","value":"..."}]
    _output "$(_post "/api/admin/setting/save" "$(${JQ} -n \
        --arg k "$OPT_KEY" --arg v "$OPT_VALUE" \
        '[{"key":$k,"value":$v}]')")"
}
cmd_settings_delete() {
    _resolve; [ -z "$OPT_KEY" ] && _exit_error "--key 必填"
    _output "$(_post "/api/admin/setting/delete" "$(${JQ} -n --arg k "$OPT_KEY" '{"key":$k}')")"
}

# ── 存储管理 ──────────────────────────────────────────────────────────────────

cmd_storage_list()     { _resolve; _output "$(_get "/api/admin/storage/list")"; }
cmd_storage_get()      { _resolve; [ -z "$OPT_ID" ] && _exit_error "--id 必填"; _output "$(_get "/api/admin/storage/get" "id=${OPT_ID}")"; }
cmd_storage_enable()   { _resolve; [ -z "$OPT_ID" ] && _exit_error "--id 必填"; _output "$(_post "/api/admin/storage/enable"  "{\"id\":${OPT_ID}}")"; }
cmd_storage_disable()  { _resolve; [ -z "$OPT_ID" ] && _exit_error "--id 必填"; _output "$(_post "/api/admin/storage/disable" "{\"id\":${OPT_ID}}")"; }
cmd_storage_delete()   { _resolve; [ -z "$OPT_ID" ] && _exit_error "--id 必填"; _output "$(_post "/api/admin/storage/delete"  "{\"id\":${OPT_ID}}")"; }
cmd_storage_load_all() { _resolve; _output "$(_post "/api/admin/storage/load_all" '{}')"; }
cmd_driver_list()      { _resolve; _output "$(_get "/api/admin/driver/list")"; }
cmd_driver_names()     { _resolve; _output "$(_get "/api/admin/driver/names")"; }

cmd_storage_create() {
    _resolve
    local d="${OPT_CONFIG:-{}}"
    [ -n "$OPT_DRIVER" ]     && d=$(printf '%s' "$d" | ${JQ} --arg v "$OPT_DRIVER"     '. + {"driver":$v}')
    [ -n "$OPT_MOUNT_PATH" ] && d=$(printf '%s' "$d" | ${JQ} --arg v "$OPT_MOUNT_PATH" '. + {"mount_path":$v}')
    _output "$(_post "/api/admin/storage/create" "$d")"
}
cmd_storage_update() {
    _resolve; [ -z "$OPT_CONFIG" ] && _exit_error "--config 必填"
    local d="$OPT_CONFIG"
    [ -n "$OPT_ID" ] && d=$(printf '%s' "$d" | ${JQ} --argjson id "$OPT_ID" '. + {"id":$id}')
    _output "$(_post "/api/admin/storage/update" "$d")"
}

# ── 参数解析 ──────────────────────────────────────────────────────────────────

OPT_URL="" OPT_TOKEN="" OPT_PATH="" OPT_DST="" OPT_NEW_NAME="" OPT_NAMES=""
OPT_PAGE="" OPT_PER_PAGE="" OPT_REFRESH="false" OPT_KEYWORD="" OPT_METHOD=""
OPT_FILE="" OPT_REPLACE="false" OPT_ASYNC_UPLOAD="false" OPT_USE_API="1"
OPT_MAX_DEPTH="6" OPT_USERNAME="" OPT_PASSWORD="" OPT_RENAME_PAIRS=""
OPT_SRC_DIR="" OPT_SRC_REGEX="" OPT_DST_REGEX="" OPT_FILES=""
OPT_EXPIRE_HOURS="" OPT_EXPIRE_AT="" OPT_ID="" OPT_GROUP="" OPT_KEY=""
OPT_VALUE="" OPT_CONFIG="" OPT_DRIVER="" OPT_MOUNT_PATH="" OPT_PATHS=""
OPT_ASYNC="0" OPT_URLS="" OPT_TOOLS="" OPT_DELETE_POLICY="" OPT_THREAD_COUNT=""

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --url)           OPT_URL="$2";           shift 2 ;;
            --url=*)         OPT_URL="${1#*=}";       shift ;;
            --token)         OPT_TOKEN="$2";          shift 2 ;;
            --path)          OPT_PATH="$2";           shift 2 ;;
            --path=*)        OPT_PATH="${1#*=}";      shift ;;
            --dst)           OPT_DST="$2";            shift 2 ;;
            --new-name)      OPT_NEW_NAME="$2";       shift 2 ;;
            --names)         OPT_NAMES="$2";          shift 2 ;;
            --page)          OPT_PAGE="$2";           shift 2 ;;
            --per-page)      OPT_PER_PAGE="$2";       shift 2 ;;
            --refresh)       OPT_REFRESH="true";      shift ;;
            --keyword)       OPT_KEYWORD="$2";        shift 2 ;;
            --method)        OPT_METHOD="$2";         shift 2 ;;
            --file)          OPT_FILE="$2";           shift 2 ;;
            --replace)       OPT_REPLACE="true";      shift ;;
            --async-upload)  OPT_ASYNC_UPLOAD="true"; shift ;;
            --no-api)        OPT_USE_API="0";         shift ;;
            --max-depth)     OPT_MAX_DEPTH="$2";      shift 2 ;;
            --username)      OPT_USERNAME="$2";       shift 2 ;;
            --password)      OPT_PASSWORD="$2";       shift 2 ;;
            --rename-pairs)  OPT_RENAME_PAIRS="$2";   shift 2 ;;
            --src-dir)       OPT_SRC_DIR="$2";        shift 2 ;;
            --src-regex)     OPT_SRC_REGEX="$2";      shift 2 ;;
            --dst-regex)     OPT_DST_REGEX="$2";      shift 2 ;;
            --files)         OPT_FILES="$2";          shift 2 ;;
            --expire-hours)  OPT_EXPIRE_HOURS="$2";   shift 2 ;;
            --expire-at)     OPT_EXPIRE_AT="$2";      shift 2 ;;
            --id)            OPT_ID="$2";             shift 2 ;;
            --group)         OPT_GROUP="$2";          shift 2 ;;
            --key)           OPT_KEY="$2";            shift 2 ;;
            --value)         OPT_VALUE="$2";          shift 2 ;;
            --config)        OPT_CONFIG="$2";         shift 2 ;;
            --driver)        OPT_DRIVER="$2";         shift 2 ;;
            --mount-path)    OPT_MOUNT_PATH="$2";     shift 2 ;;
            --paths)         OPT_PATHS="$2";          shift 2 ;;
            --async)         OPT_ASYNC="1";           shift ;;
            --urls)          OPT_URLS="$2";           shift 2 ;;
            --tools)         OPT_TOOLS="$2";          shift 2 ;;
            --delete-policy) OPT_DELETE_POLICY="$2";  shift 2 ;;
            --thread-count)  OPT_THREAD_COUNT="$2";   shift 2 ;;
            --json)          OUTPUT_JSON=1;           shift ;;
            --quiet)         OUTPUT_QUIET=1;          shift ;;
            *)               shift ;;
        esac
    done
}

# ── 入口 ──────────────────────────────────────────────────────────────────────

main() {
    [ $# -eq 0 ] && { printf '用法: sh openlist.sh <command> [options]\n'; exit 1; }
    local cmd="$1"; shift
    parse_args "$@"

    case "$cmd" in
        login)                   cmd_login ;;
        list)                    cmd_list ;;
        get)                     cmd_get ;;
        mkdir)                   cmd_mkdir ;;
        rename)                  cmd_rename ;;
        move)                    cmd_move ;;
        copy)                    cmd_copy ;;
        remove)                  cmd_remove ;;
        search)                  cmd_search ;;
        link)                    cmd_link ;;
        upload)                  cmd_upload ;;
        batch-rename)            cmd_batch_rename ;;
        regex-rename)            cmd_regex_rename ;;
        share-list)              cmd_share_list ;;
        share-get)               cmd_share_get ;;
        share-create)            cmd_share_create ;;
        share-update)            cmd_share_update ;;
        share-delete)            cmd_share_delete ;;
        index-build)             cmd_index_build ;;
        index-update)            cmd_index_update ;;
        index-clear)             cmd_index_clear ;;
        index-progress)          cmd_index_progress ;;
        settings-list)           cmd_settings_list ;;
        settings-get)            cmd_settings_get ;;
        settings-save)           cmd_settings_save ;;
        settings-delete)         cmd_settings_delete ;;
        storage-list)            cmd_storage_list ;;
        storage-get)             cmd_storage_get ;;
        storage-create)          cmd_storage_create ;;
        storage-update)          cmd_storage_update ;;
        storage-delete)          cmd_storage_delete ;;
        storage-enable)          cmd_storage_enable ;;
        storage-disable)         cmd_storage_disable ;;
        storage-load-all)        cmd_storage_load_all ;;
        dirs)                    cmd_dirs ;;
        recursive-move)          cmd_recursive_move ;;
        remove-empty-directory)  cmd_remove_empty_directory ;;
        add-offline-download)    cmd_add_offline_download ;;
        driver-list)             cmd_driver_list ;;
        driver-names)            cmd_driver_names ;;
        *) _exit_error "未知命令: $cmd" ;;
    esac
}

main "$@"