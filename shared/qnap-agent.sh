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
LOGFILE="${QPKG_ROOT}/logs/qnap-agent.log"

LOG_MAX_BYTES=10485760   # 10 MB
LOG_KEEP_LINES=1000

mkdir -p "${QPKG_ROOT}/run" "${QPKG_ROOT}/logs" "${PICOCLAW_HOME}"


log() {
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

validate_config() {
    case "${PICOCLAW_CONFIG}" in
        /root/.picoclaw/*)
            log "ERROR" "配置文件路径异常 (${PICOCLAW_CONFIG})，疑似安装未完成，使用了系统默认路径，停止启动"
            return 1
            ;;
    esac

    local deny_count
    deny_count=$(awk '
        /"custom_deny_patterns"/ { in_section=1 }
        in_section && /\[/        { in_array=1 }
        in_array  && /"/          { count++ }
        in_array  && /\]/         { print count+0; exit }
    ' "${PICOCLAW_CONFIG}" 2>/dev/null)

    if [ -z "${deny_count}" ]; then
        deny_count=0
    fi

    if [ "${deny_count}" -lt 3 ]; then
        log "ERROR" "安全配置不足: custom_deny_patterns 仅有 ${deny_count} 条规则 (要求至少 3 条)，疑似配置文件不正确，停止启动"
        return 1
    fi

    log "INFO" "配置校验通过: 路径正常，custom_deny_patterns 共 ${deny_count} 条规则"
    return 0
}

start() {
    local caller
    caller=$(get_caller_info)
    log "INFO" "触发来源: ${caller}"
    if is_running; then
        log "INFO" "服务已在运行中 (PID: $(cat ${PIDFILE}))"
        return 0
    fi

	if [ ! -f "${LAST_INIT_FILE}" ] || [ ! -f "${SYSTEM_FILE}" ]; then
		log "INFO" "未检测到系统采集记录，正在后台执行首次初始化..."
		if [ -f "${INIT_SCRIPT}" ]; then
			sh "${INIT_SCRIPT}" >> "${QPKG_ROOT}/logs/qnap-agent-init.log" 2>&1 &
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

    if ! validate_config; then
        return 1
    fi

    log "INFO" "正在启动 QNAP Agent..."
    log "INFO" "启动器: ${LAUNCHER_BIN}"
    log "INFO" "配置文件: ${PICOCLAW_CONFIG}"
    log "INFO" "工作目录: ${PICOCLAW_HOME}"

    export TZ=":/etc/localtime"
    HOME="${PICOCLAW_HOME}" \
    PICOCLAW_HOME="${PICOCLAW_HOME}" \
    "${LAUNCHER_BIN}" \
        -public \
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
    local caller
    caller=$(get_caller_info)
    log "INFO" "触发来源: ${caller}"
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
    local caller
    caller=$(get_caller_info)
    log "INFO" "触发来源: ${caller}，正在派生独立进程执行重启..."

    export QPKG_ROOT PIDFILE WATCHDOG_PIDFILE LOGFILE PICOCLAW_HOME \
           LAUNCHER_BIN PICOCLAW_CONFIG WATCHDOG_SCRIPT \
           INIT_SCRIPT SYSTEM_FILE LAST_INIT_FILE
    export CALLER_INFO="${caller}"

    local tmpout
    tmpout="/tmp/qnap-restart-$$.log"
    : > "${tmpout}"

    setsid sh -c '
        SOURCED=1 . "'"${QPKG_ROOT}/qnap-agent.sh"'"
        stop
        sleep 2
        start
    ' >> "${tmpout}" 2>&1 &

    local bg_pid=$!
    log "INFO" "重启任务已在后台新进程组运行 (PID: ${bg_pid})"

    tail -f "${tmpout}" &
    local tail_pid=$!
    wait "${bg_pid}" 2>/dev/null
    sleep 1        # 让 tail 把最后几行刷完
    kill "${tail_pid}" 2>/dev/null
    wait "${tail_pid}" 2>/dev/null

    rm -f "${tmpout}"
}

get_caller_info() {
    if [ -n "${CALLER_INFO}" ]; then
        echo "${CALLER_INFO}"
        return 0
    fi

    local pid=$$
    local caller="unknown"
    local depth=0

    while [ "${pid}" -gt 1 ] && [ "${depth}" -lt 20 ]; do
        local comm ppid cmdline
        comm=$(cat /proc/${pid}/comm 2>/dev/null | tr -d '\n')
        ppid=$(awk '/^PPid:/{print $2}' /proc/${pid}/status 2>/dev/null)
        cmdline=$(cat /proc/${pid}/cmdline 2>/dev/null | tr '\0' ' ' | sed 's/ *$//')

        case "${comm}" in
            sshd)
                case "${cmdline}" in
                    *@pts/*|*@notty*)
                        local who
                        who="${cmdline#*sshd: }"
                        caller="ssh(${who})"
                        break
                        ;;
                esac
                ;;
            picoclaw*|launcher*)
                caller="agent(${comm})"
                break
                ;;
            init|s6-svscan|supervise)
                caller="init.d(${comm})"
                break
                ;;
        esac

        pid="${ppid}"
        depth=$((depth + 1))
    done

    echo "${caller}"
}

status() {
    if is_running; then
        local pid
        pid=$(cat "${PIDFILE}" 2>/dev/null)
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 服务运行中 (PID: ${pid})"
        echo "--- 最近日志 ---"
        tail -15 "${LOGFILE}" 2>/dev/null
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 服务未运行"
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

    "${WATCHDOG_SCRIPT}" >> "${QPKG_ROOT}/logs/watchdog.log" 2>&1 &
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
        local count=0
        while kill -0 "${wpid}" 2>/dev/null && [ ${count} -lt 10 ]; do
            sleep 1; count=$((count + 1))
        done
        kill -0 "${wpid}" 2>/dev/null && kill -9 "${wpid}" 2>/dev/null
    fi

    rm -f "${WATCHDOG_PIDFILE}"
    log "INFO" "看门狗已停止"
}

repair_config() {
    local tpl="${QPKG_ROOT}/config/config.json.tpl"
    local cfg="${PICOCLAW_HOME}/config.json"
    local bak="${PICOCLAW_HOME}/config.json.bak"

    echo ""
    echo "  此操作将覆盖现有 config.json，操作前会自动备份。"
    echo "  模板来源: ${tpl}"
    echo "  目标文件: ${cfg}"
    echo ""
    printf "  确认执行修复？输入 y 后按回车继续，其他任意键取消: "
    read answer
    case "${answer}" in
        y|Y) ;;
        *)
            echo "  已取消，未做任何修改。"
            return 0
            ;;
    esac
    echo ""

    log "INFO" "=== 开始修复配置文件 ==="

    if [ ! -f "${tpl}" ]; then
        log "ERROR" "模板文件不存在: ${tpl}，无法修复"
        return 1
    fi

    if [ -f "${cfg}" ]; then
        cp -p "${cfg}" "${bak}"
        if [ $? -eq 0 ]; then
            log "INFO" "已备份原配置文件: ${bak}"
        else
            log "ERROR" "备份失败，中止修复"
            return 1
        fi
    else
        log "INFO" "未发现现有 config.json，跳过备份"
    fi

    cp "${tpl}" "${cfg}"
    sed "s#__QPKG_ROOT__#${QPKG_ROOT}#g" "${cfg}" > "${cfg}.tmp" && mv "${cfg}.tmp" "${cfg}"
    if [ $? -eq 0 ]; then
        log "INFO" "配置文件已从模板重新生成: ${cfg}"
        log "INFO" "安装路径已替换为: ${QPKG_ROOT}"
    else
        log "ERROR" "模板替换失败，尝试从备份还原..."
        [ -f "${bak}" ] && cp -p "${bak}" "${cfg}"
        return 1
    fi

    log "INFO" "=== 配置文件修复完成，请重启服务: $0 restart ==="
}

[ "${SOURCED}" = "1" ] && return 0

case "$1" in
    start)         start          ;;
    stop)          stop           ;;
    restart)       restart        ;;
    status)        status         ;;
    repair-config) repair_config  ;;
    *)
        echo "用法: $0 {start|stop|restart|status|repair-config}"
        exit 1
        ;;
esac
