#!/bin/sh
########################################
# watchdog.sh - QNAP Agent 升级看门狗
#
# 功能：
#   1. 每 5 分钟扫描 $QPKG_ROOT/update/ 目录
#   2. 发现压缩包（.tar.gz / .zip / .deb）时自动解压至 update/ 平铺目录
#   3. 发现 picoclaw 二进制时自动停止主服务、备份、替换、重启
#   4. 升级完成后清空 update/ 目录内所有文件
#   5. 每 1 分钟做健康检查，主服务异常退出时自动重拉
#
# 升级包投放：
#   - 将压缩包（.tar.gz / .zip / .deb）或二进制文件放入 update/ 目录即可
#
# 子命令：
#   sh watchdog.sh upgrade   立即触发一次扫描+升级，无需等待定时周期
########################################

QPKG_NAME="qnap-agent"
CONF=/etc/config/qpkg.conf
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF} 2>/dev/null)
if [ -z "${QPKG_ROOT}" ]; then
    QPKG_ROOT="/share/CACHEDEV1_DATA/.qpkg/${QPKG_NAME}"
fi

APP_ROOT="${QPKG_ROOT}/workspace"
UPDATE_DIR="${QPKG_ROOT}/update"
BACKUP_DIR="${QPKG_ROOT}/backup"
BINARY_PATH="${QPKG_ROOT}/picoclaw"
LAUNCHER_PATH="${QPKG_ROOT}/picoclaw-launcher"
PIDFILE="${QPKG_ROOT}/run/qnap-agent.pid"
SERVICE_SCRIPT="${QPKG_ROOT}/qnap-agent.sh"
LOG="${QPKG_ROOT}/logs/watchdog.log"

CHECK_INTERVAL=300   # 5 分钟：升级包扫描间隔
HEALTH_INTERVAL=60   # 1 分钟：健康检查间隔
MAX_UPGRADE_FAILS=2  # 连续验证失败次数上限，超过则自动清除损坏文件

LOG_MAX_BYTES=10485760   # 10 MB
LOG_KEEP_LINES=1000

mkdir -p "${UPDATE_DIR}" "${BACKUP_DIR}"

GW_PORT=$(jq -r '.gateway.port // empty' "${APP_ROOT}/config.json" 2>/dev/null)
[ -z "${GW_PORT}" ] && GW_PORT=18790

log() {
    # 日志超过 LOG_MAX_BYTES 时保留最后 LOG_KEEP_LINES 行
    if [ -f "${LOG}" ]; then
        fsize=$(wc -c < "${LOG}" 2>/dev/null || echo 0)
        if [ "${fsize}" -gt "${LOG_MAX_BYTES}" ]; then
            tmp="${LOG}.tmp"
            tail -${LOG_KEEP_LINES} "${LOG}" > "${tmp}" 2>/dev/null \
                && mv "${tmp}" "${LOG}"
        fi
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] [watchdog] $2" >> "${LOG}"
}

check_service_health() {
    [ -f "${PIDFILE}" ] || return 1
    pid=$(cat "${PIDFILE}" 2>/dev/null)
    [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null || return 1
    wget -q -O /dev/null --timeout=5 "http://127.0.0.1:${GW_PORT}/health" 2>/dev/null
    return $?
}

auto_restart_if_dead() {
    if ! check_service_health; then
        log "WARN" "主服务已停止，尝试自动重启..."
        "${SERVICE_SCRIPT}" start
        if check_service_health; then
            log "INFO" "主服务自动重启成功"
        else
            log "ERROR" "主服务自动重启失败，请检查日志"
        fi
    fi
}

extract_archives() {
    # 若 update/ 内已存在 picoclaw 二进制，无需再处理压缩包
    if [ -f "${UPDATE_DIR}/picoclaw" ]; then
        return 0
    fi

    found_archive=0

    for archive in "${UPDATE_DIR}"/*.tar.gz \
                   "${UPDATE_DIR}"/*.tgz    \
                   "${UPDATE_DIR}"/*.zip    \
                   "${UPDATE_DIR}"/*.deb; do
        [ -f "${archive}" ] || continue

        found_archive=1
        fname=$(basename "${archive}")
        log "INFO" "发现压缩包: ${fname}，开始解压..."

        # 创建临时解压目录
        tmpdir=$(mktemp -d "${UPDATE_DIR}/extract_XXXXXX" 2>/dev/null)
        if [ -z "${tmpdir}" ] || [ ! -d "${tmpdir}" ]; then
            log "ERROR" "无法创建临时目录，跳过 ${fname}"
            continue
        fi

        # 按格式解压
        extract_ok=0
        case "${archive}" in
            *.tar.gz|*.tgz)
                tar xzf "${archive}" -C "${tmpdir}" 2>/dev/null && extract_ok=1
                ;;
            *.zip)
                if command -v unzip > /dev/null 2>&1; then
                    unzip -q "${archive}" -d "${tmpdir}" 2>/dev/null && extract_ok=1
                else
                    log "WARN" "unzip 不可用，无法处理 ${fname}"
                fi
                ;;
            *.deb)
                # .deb 内部结构：ar 打包，包含 data.tar.* 载荷
                if command -v ar > /dev/null 2>&1; then
                    ( cd "${tmpdir}" && ar x "${archive}" 2>/dev/null )
                    for datatgz in "${tmpdir}"/data.tar.*; do
                        [ -f "${datatgz}" ] || continue
                        tar xf "${datatgz}" -C "${tmpdir}" 2>/dev/null && extract_ok=1
                        rm -f "${datatgz}"
                    done
                    rm -f "${tmpdir}/debian-binary" "${tmpdir}/control.tar"* 2>/dev/null
                else
                    log "WARN" "ar 命令不可用，无法处理 ${fname}"
                fi
                ;;
        esac

        if [ "${extract_ok}" -eq 1 ]; then
            filelist=$(mktemp "${UPDATE_DIR}/filelist_XXXXXX" 2>/dev/null)
            find "${tmpdir}" -type f > "${filelist}" 2>/dev/null
            while IFS= read -r fpath; do
                bname=$(basename "${fpath}")
                [ -n "${bname}" ] || continue
                mv "${fpath}" "${UPDATE_DIR}/${bname}" 2>/dev/null \
                    && log "INFO" "解压文件: ${bname}"
            done < "${filelist}"
            rm -f "${filelist}"
            log "INFO" "${fname} 解压完成"
        else
            log "ERROR" "${fname} 解压失败，请确认格式是否受支持"
        fi

        rm -rf "${tmpdir}"
        rm -f "${archive}"
    done

    [ "${found_archive}" -eq 0 ] && return 0
    return 0
}


clean_update_dir() {
    find "${UPDATE_DIR}" -maxdepth 1 -type f -exec rm -f {} \; 2>/dev/null || true
    find "${UPDATE_DIR}" -maxdepth 1 -type d -name 'extract_*' \
        -exec rm -rf {} \; 2>/dev/null || true
    log "INFO" "已清空 update/ 目录"
}

perform_upgrade() {
    new_bin="${UPDATE_DIR}/picoclaw"
    new_launcher="${UPDATE_DIR}/picoclaw-launcher"

    log "INFO" "=== 开始执行升级流程 ==="

    [ -s "${new_bin}" ] || { log "ERROR" "升级包为空，中止"; return 1; }

    chmod +x "${new_bin}" 2>/dev/null
    
    # 捕获真实执行输出，确认版本信息
    # 注意：picoclaw 使用 version 子命令而不是 --version 参数
    ver_output=$("${new_bin}" version 2>&1)
    if [ $? -ne 0 ]; then
        log "ERROR" "新版 picoclaw 验证失败. 真实报错: ${ver_output}"
        # 累计验证失败次数
        _fc=0
        [ -f "${UPDATE_DIR}/.fail_count" ] && _fc=$(cat "${UPDATE_DIR}/.fail_count" 2>/dev/null || echo 0)
        _fc=$((_fc + 1))
        echo "${_fc}" > "${UPDATE_DIR}/.fail_count"
        if [ "${_fc}" -ge "${MAX_UPGRADE_FAILS}" ]; then
            log "ERROR" "连续 ${_fc} 次验证失败，判定为损坏的升级包，自动清除 update/ 目录"
            clean_update_dir
        fi
        return 1
    fi

    # 获取新版版本号 (使用 sed 提取 picoclaw 后的版本号)
    new_ver=$(HOME="${APP_ROOT}" "${new_bin}" version 2>&1 | sed -n 's/.*picoclaw //p')
    if [ -z "${new_ver}" ]; then new_ver="Unknown"; fi

    # 获取旧版版本号 (同上)
    old_ver=$(HOME="${APP_ROOT}" "${BINARY_PATH}" version 2>&1 | sed -n 's/.*picoclaw //p')
    if [ -z "${old_ver}" ]; then old_ver="Unknown"; fi
    log "INFO" "当前版本: ${old_ver} → 新版本: ${new_ver}"

    log "INFO" "停止主服务..."
    # 设置 WATCHDOG_CALLING=1，通知 qnap-agent.sh stop 跳过 stop_watchdog，
    # 避免看门狗在升级过程中向自身发送 SIGTERM 导致升级流程中断。
    WATCHDOG_CALLING=1 "${SERVICE_SCRIPT}" stop
    sleep 3
    log "INFO" "备份当前版本到 ${BACKUP_DIR}/"
    mkdir -p "${BACKUP_DIR}"
    cp "${BINARY_PATH}"   "${BACKUP_DIR}/picoclaw.bak"          2>/dev/null || true
    cp "${LAUNCHER_PATH}" "${BACKUP_DIR}/picoclaw-launcher.bak" 2>/dev/null || true

    log "INFO" "替换 picoclaw 主程序..."
    mv "${new_bin}" "${BINARY_PATH}"
    chmod +x "${BINARY_PATH}"

    if [ -f "${new_launcher}" ] && [ -s "${new_launcher}" ]; then
        log "INFO" "替换 picoclaw-launcher..."
        mv "${new_launcher}" "${LAUNCHER_PATH}"
        chmod +x "${LAUNCHER_PATH}"
    fi

    clean_update_dir
    # 验证通过，清除失败计数
    rm -f "${UPDATE_DIR}/.fail_count"

    log "INFO" "重启主服务..."
    "${SERVICE_SCRIPT}" start

    if check_service_health; then
        log "INFO" "=== 升级成功：${old_ver} → ${new_ver} ==="
    else
        log "ERROR" "升级后服务启动失败，执行回滚..."
        cp "${BACKUP_DIR}/picoclaw.bak"          "${BINARY_PATH}"   2>/dev/null
        [ -f "${BACKUP_DIR}/picoclaw-launcher.bak" ] && \
            cp "${BACKUP_DIR}/picoclaw-launcher.bak" "${LAUNCHER_PATH}" 2>/dev/null
        chmod +x "${BINARY_PATH}" "${LAUNCHER_PATH}" 2>/dev/null
        "${SERVICE_SCRIPT}" start
        log "WARN" "已回滚至备份版本"
        return 1
    fi
}

scan_and_upgrade() {
    extract_archives
    if [ -f "${UPDATE_DIR}/picoclaw" ]; then
        log "INFO" "发现 picoclaw 二进制，准备执行升级..."
        perform_upgrade || log "ERROR" "升级流程执行失败"
    fi
}

if [ "$1" = "upgrade" ]; then
    log "INFO" "收到立即升级指令，跳过定时等待，直接执行扫描..."
    scan_and_upgrade
    exit $?
fi

log "INFO" "看门狗启动，监控目录: ${UPDATE_DIR}，检查间隔: ${CHECK_INTERVAL}s / 健康检查: ${HEALTH_INTERVAL}s"

trap 'log "INFO" "看门狗收到终止信号，退出"; exit 0' TERM INT

LAST_CHECK=0

while true; do
    CURRENT_TIME=$(date +%s)

    # 每分钟：健康检查
    auto_restart_if_dead

    # 每 5 分钟：扫描升级包
    if [ $((CURRENT_TIME - LAST_CHECK)) -ge ${CHECK_INTERVAL} ]; then
        LAST_CHECK=${CURRENT_TIME}
        scan_and_upgrade
    fi

    sleep ${HEALTH_INTERVAL}
done
