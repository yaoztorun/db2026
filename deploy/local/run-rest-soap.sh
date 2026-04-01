#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="${SCRIPT_DIR}/.runtime"
LOG_DIR="${RUNTIME_DIR}/logs"
PID_DIR="${RUNTIME_DIR}/pids"

mkdir -p "${LOG_DIR}" "${PID_DIR}"

start_service() {
  local name="$1"
  local runner="$2"
  local pid_file="${PID_DIR}/${name}.pid"
  local log_file="${LOG_DIR}/${name}.log"

  if [[ -f "${pid_file}" ]]; then
    local existing_pid
    existing_pid="$(cat "${pid_file}" 2>/dev/null || true)"
    if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
      echo "${name} is already running (PID ${existing_pid})"
      return 0
    fi
    rm -f "${pid_file}"
  fi

  nohup "${runner}" >>"${log_file}" 2>&1 &
  local new_pid="$!"
  echo "${new_pid}" >"${pid_file}"
  echo "Started ${name} (PID ${new_pid}) -> ${log_file}"
}

start_service "rest" "${SCRIPT_DIR}/run-rest.sh"
start_service "soap" "${SCRIPT_DIR}/run-soap.sh"
