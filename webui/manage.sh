#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENV_PYTHON="${PROJECT_ROOT}/.venv/bin/python"
RUNTIME_DIR="${SCRIPT_DIR}/runtime"
PID_FILE="${RUNTIME_DIR}/kronos-webui.pid"
LOG_FILE="${RUNTIME_DIR}/kronos-webui.log"
PORT=7070

mkdir -p "${RUNTIME_DIR}"

get_pid() {
    if [ -f "${PID_FILE}" ]; then
        cat "${PID_FILE}"
    fi
}

is_running() {
    local pid
    pid="$(get_pid)"
    if [ -n "${pid:-}" ] && kill -0 "${pid}" 2>/dev/null; then
        return 0
    fi
    return 1
}

port_pid() {
    fuser "${PORT}/tcp" 2>/dev/null | awk '{print $1}'
}

start_server() {
    if [ ! -x "${VENV_PYTHON}" ]; then
        echo "Missing virtualenv Python: ${VENV_PYTHON}"
        exit 1
    fi

    if is_running; then
        echo "Kronos Web UI already running with PID $(get_pid)"
        echo "URL: http://127.0.0.1:${PORT}"
        exit 0
    fi

    local existing_pid
    existing_pid="$(port_pid || true)"
    if [ -n "${existing_pid}" ]; then
        echo "Port ${PORT} is already in use by PID ${existing_pid}"
        echo "Run ./stop.sh first if you want to replace it."
        exit 1
    fi

    cd "${PROJECT_ROOT}"
    nohup "${VENV_PYTHON}" -c "from webui.app import app; app.run(debug=False, host='0.0.0.0', port=${PORT})" >"${LOG_FILE}" 2>&1 &
    local pid=$!
    echo "${pid}" > "${PID_FILE}"
    sleep 2

    if kill -0 "${pid}" 2>/dev/null; then
        echo "Kronos Web UI started"
        echo "PID: ${pid}"
        echo "URL: http://127.0.0.1:${PORT}"
        echo "Log: ${LOG_FILE}"
    else
        echo "Kronos Web UI failed to start"
        rm -f "${PID_FILE}"
        tail -n 40 "${LOG_FILE}" 2>/dev/null || true
        exit 1
    fi
}

stop_server() {
    local pid
    pid="$(get_pid)"

    if [ -n "${pid:-}" ] && kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}"
        sleep 1
        if kill -0 "${pid}" 2>/dev/null; then
            kill -9 "${pid}"
        fi
        rm -f "${PID_FILE}"
        echo "Stopped Kronos Web UI (PID ${pid})"
        return 0
    fi

    local existing_pid
    existing_pid="$(port_pid || true)"
    if [ -n "${existing_pid}" ]; then
        kill "${existing_pid}" 2>/dev/null || true
        sleep 1
        if kill -0 "${existing_pid}" 2>/dev/null; then
            kill -9 "${existing_pid}" 2>/dev/null || true
        fi
        rm -f "${PID_FILE}"
        echo "Stopped process on port ${PORT} (PID ${existing_pid})"
        return 0
    fi

    rm -f "${PID_FILE}"
    echo "Kronos Web UI is not running"
}

status_server() {
    if is_running; then
        echo "Kronos Web UI is running"
        echo "PID: $(get_pid)"
        echo "URL: http://127.0.0.1:${PORT}"
        echo "Log: ${LOG_FILE}"
        return 0
    fi

    local existing_pid
    existing_pid="$(port_pid || true)"
    if [ -n "${existing_pid}" ]; then
        echo "Port ${PORT} is in use by PID ${existing_pid}, but it is not tracked by ${PID_FILE}"
        return 0
    fi

    echo "Kronos Web UI is stopped"
}

restart_server() {
    stop_server
    start_server
}

logs_server() {
    if [ -f "${LOG_FILE}" ]; then
        tail -n 50 "${LOG_FILE}"
    else
        echo "No log file yet: ${LOG_FILE}"
    fi
}

case "${1:-}" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    status)
        status_server
        ;;
    logs)
        logs_server
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
