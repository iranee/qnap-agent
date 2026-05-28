#!/bin/sh
########################################
# qnap-agent.sh - QNAP Agent 主服务控制脚本
# 用法: qnap-agent.sh {start|stop|restart|status}
#
# 架构说明:
#   picoclaw-launcher  (主进程)  ← 本脚本管理此进程
#     └─ picoclaw gateway       ← launcher 自动管理，无需手动干预
#
# 由 QTS init.d 服务框架调用（/etc/init.d/qnap-agent）
# 安装时自动注册: ln -sf 本脚本 /etc/init.d/qnap-agent
########################################

QPKG_NAME="qnap-agent"
CONF=/etc/config/qpkg.conf
QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF} 2>/dev/null)
if [ -z "${QPKG_ROOT}" ]; then
    QPKG_ROOT="/share/CACHEDEV1_DATA/.qpkg/${QPKG_NAME}"
fi

PICOCLAW_HOME="${QPKG_ROOT}/workspace"
LAUNCHER_BIN="${QPKG_ROOT}/picoclaw-launcher"
PICOCLAW_CONFIG="${PICOCLAW_HOME}/config.json"
WATCHDOG_SCRIPT="${QPKG_ROOT}/watchdog.sh"

INIT_SCRIPT="${QPKG_ROOT}/init-system.sh"
SYSTEM_FILE="${QPKG_ROOT}/workspace/memory/SYSTEM.md"
LAST_INIT_FILE="${QPKG_ROOT}/workspace/state/last_init.txt"

PIDFILE="${QPKG_ROOT}/run/qnap-agent.pid"
WATCHDOG_PIDFILE="${QPKG_ROOT}/run/watchdog.pid"
LOGFILE="${QPKG_ROOT}/log/qnap-agent.log"

LOG_MAX_BYTES=10485760   # 10 MB
LOG_KEEP_LINES=1000

mkdir -p "${QPKG_ROOT}/run" "${QPKG_ROOT}/log" "${PICOCLAW_HOME}"


log() {
    # 日志超过 LOG_MAX_BYTES 时保留最后 LOG_KEEP_LINES 行
    if [ -f "${LOGFILE}" ]; then
        local fsize
        fsize=$(wc -c < "${LOGFILE}" 2>/dev/null || echo 0)
        if [ "${fsize}" -gt "${LOG_MAX_BYTES}" ]; then
            local tmp="${LOGFILE}.tmp"
            tail -${LOG_KEEP_LINES} "${LOGFILE}" > "${tmp}" 2>/dev/null \
                && mv "${tmp}" "${LOGFILE}"
        fi
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" | tee -a "${LOGFILE}"
}

is_running() {
    local pid
    if [ -f "${PIDFILE}" ]; then
        pid=$(cat "${PIDFILE}" 2>/dev/null)
        if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}


start() {
    if is_running; then
        log "INFO" "服务已在运行中 (PID: $(cat ${PIDFILE}))"
        return 0
    fi

	if [ ! -f "${LAST_INIT_FILE}" ] || [ ! -f "${SYSTEM_FILE}" ]; then
		log "INFO" "未检测到系统采集记录，正在后台执行首次初始化..."
		if [ -f "${INIT_SCRIPT}" ]; then
			sh "${INIT_SCRIPT}" >> "${QPKG_ROOT}/log/qnap-agent-init.log" 2>&1 &
			log "INFO" "init-system.sh 已在后台运行 (PID: $!)"
		else
			log "WARN" "未找到 init-system.sh: ${INIT_SCRIPT}，跳过初始化"
		fi
	else
		log "INFO" "系统信息已存在（上次采集: $(cat ${LAST_INIT_FILE} 2>/dev/null)），跳过初始化"
	fi

    if [ ! -f "${LAUNCHER_BIN}" ]; then
        log "ERROR" "未找到 picoclaw-launcher: ${LAUNCHER_BIN}"
        return 1
    fi
    if [ ! -f "${PICOCLAW_CONFIG}" ]; then
        log "ERROR" "未找到配置文件: ${PICOCLAW_CONFIG}"
        return 1
    fi

    log "INFO" "正在启动 QNAP Agent..."
    log "INFO" "启动器: ${LAUNCHER_BIN}"
    log "INFO" "配置文件: ${PICOCLAW_CONFIG}"
    log "INFO" "工作目录: ${PICOCLAW_HOME}"

    export TZ=":/etc/localtime"
    # 启动 launcher（launcher 会自动拉起 picoclaw gateway）
    # launcher 监听 0.0.0.0:18800，接收来自 QNAP 管理界面的请求
    HOME="${PICOCLAW_HOME}" \
    PICOCLAW_HOME="${PICOCLAW_HOME}" \
    "${LAUNCHER_BIN}" \
        -host 0.0.0.0 \
        -port 18800 \
        -console \
        -no-browser \
        "${PICOCLAW_CONFIG}" \
        >> "${LOGFILE}" 2>&1 &

    local pid=$!
    echo "${pid}" > "${PIDFILE}"
    sleep 3

    if kill -0 "${pid}" 2>/dev/null; then
        log "INFO" "服务启动成功 (PID: ${pid})"
        start_watchdog
    else
        log "ERROR" "服务启动失败，请检查日志: ${LOGFILE}"
        rm -f "${PIDFILE}"
        return 1
    fi
}

stop() {
    # 若由看门狗升级流程发起调用（WATCHDOG_CALLING=1），跳过 stop_watchdog，
    # 避免看门狗在升级过程中向自身发送 SIGTERM 导致流程中断。
    if [ "${WATCHDOG_CALLING}" != "1" ]; then
        stop_watchdog
    fi

    if ! is_running; then
        log "INFO" "服务未在运行"
        return 0
    fi

    local pid
    pid=$(cat "${PIDFILE}" 2>/dev/null)
    log "INFO" "正在停止服务 (PID: ${pid})..."
    kill "${pid}" 2>/dev/null

    local count=0
    while kill -0 "${pid}" 2>/dev/null && [ ${count} -lt 15 ]; do
        sleep 1; count=$((count + 1))
    done

    if kill -0 "${pid}" 2>/dev/null; then
        log "WARN" "强制终止进程..."
        kill -9 "${pid}" 2>/dev/null
    fi

    rm -f "${PIDFILE}"
    log "INFO" "服务已停止"
}

restart() {
    stop
    sleep 2
    start
}

status() {
    if is_running; then
        local pid
        pid=$(cat "${PIDFILE}" 2>/dev/null)
        log "INFO" "服务运行中 (PID: ${pid})"
        echo "--- 最近日志 ---"
        tail -10 "${LOGFILE}" 2>/dev/null
        return 0
    else
        log "INFO" "服务未运行"
        return 1
    fi
}

start_watchdog() {
    if [ -f "${WATCHDOG_PIDFILE}" ]; then
        local wpid
        wpid=$(cat "${WATCHDOG_PIDFILE}" 2>/dev/null)
        if [ -n "${wpid}" ] && kill -0 "${wpid}" 2>/dev/null; then
            log "INFO" "看门狗已在运行中 (PID: ${wpid})，跳过启动"
            return 0
        fi
    fi

    # 注意：不传额外参数，$1 由看门狗自身的 upgrade 子命令使用
    "${WATCHDOG_SCRIPT}" >> "${QPKG_ROOT}/log/watchdog.log" 2>&1 &
    echo $! > "${WATCHDOG_PIDFILE}"
    log "INFO" "看门狗已启动 (PID: $(cat ${WATCHDOG_PIDFILE}))"
}

stop_watchdog() {
    if [ ! -f "${WATCHDOG_PIDFILE}" ]; then
        return 0
    fi

    local wpid
    wpid=$(cat "${WATCHDOG_PIDFILE}" 2>/dev/null)

    if [ -n "${wpid}" ] && kill -0 "${wpid}" 2>/dev/null; then
        kill "${wpid}" 2>/dev/null
        # 等待看门狗进程完全退出，避免残留进程与后续操作竞争
        local count=0
        while kill -0 "${wpid}" 2>/dev/null && [ ${count} -lt 10 ]; do
            sleep 1; count=$((count + 1))
        done
        # 超时后强制终止
        kill -0 "${wpid}" 2>/dev/null && kill -9 "${wpid}" 2>/dev/null
    fi

    rm -f "${WATCHDOG_PIDFILE}"
    log "INFO" "看门狗已停止"
}

case "$1" in
    start)   start   ;;
    stop)    stop    ;;
    restart) restart ;;
    status)  status  ;;
    *)
        echo "用法: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
