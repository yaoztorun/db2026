#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="${SCRIPT_DIR}/.runtime/pids"
STOP_TIMEOUT_SECONDS="${STOP_TIMEOUT_SECONDS:-20}"

stop_service() {
  local name="$1"
  local pid_file="${PID_DIR}/${name}.pid"

  if [[ ! -f "${pid_file}" ]]; then
    echo "No PID file for ${name}, skipping"
    return 0
  fi

  local pid
  pid="$(cat "${pid_file}")"

  if [[ -z "${pid}" ]]; then
    rm -f "${pid_file}"
    echo "Empty PID file for ${name}, cleaned up"
    return 0
  fi

  if ! kill -0 "${pid}" 2>/dev/null; then
    rm -f "${pid_file}"
    echo "${name} not running, cleaned stale PID ${pid}"
    return 0
  fi

  kill "${pid}" 2>/dev/null || true

  local waited=0
  while kill -0 "${pid}" 2>/dev/null; do
    if (( waited >= STOP_TIMEOUT_SECONDS )); then
      kill -9 "${pid}" 2>/dev/null || true
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done

  rm -f "${pid_file}"
  echo "Stopped ${name} (PID ${pid})"
}

stop_service "rest"
stop_service "soap"
