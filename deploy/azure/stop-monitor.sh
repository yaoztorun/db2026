#!/usr/bin/env bash
set -euo pipefail

AZURE_HOST="${AZURE_HOST:?Set AZURE_HOST (remote DNS/IP)}"
AZURE_USER="${AZURE_USER:?Set AZURE_USER (remote SSH user)}"
AZURE_SSH_PORT="${AZURE_SSH_PORT:-22}"
AZURE_REMOTE_DIR="${AZURE_REMOTE_DIR:-$HOME/dsgt}"
AZURE_SSH_KEY_PATH="${AZURE_SSH_KEY_PATH:-}"
MONITOR_LABEL="${MONITOR_LABEL:-}"

usage() {
  cat <<'EOF'
Usage: deploy/azure/stop-monitor.sh [options]

Stops a remote monitor started by start-monitor.sh and prints the CSV path.

Options:
  --label LABEL       Friendly label used when starting the monitor
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) MONITOR_LABEL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${MONITOR_LABEL}" ]]; then
  echo "Set MONITOR_LABEL or pass --label." >&2
  exit 1
fi

SSH_OPTS=(-p "${AZURE_SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
if [[ -n "${AZURE_SSH_KEY_PATH}" ]]; then
  SSH_OPTS+=(-i "${AZURE_SSH_KEY_PATH}")
fi

REMOTE="${AZURE_USER}@${AZURE_HOST}"
REMOTE_MONITOR_DIR="${AZURE_REMOTE_DIR}/monitor"
REMOTE_PID_FILE="${REMOTE_MONITOR_DIR}/${MONITOR_LABEL}.pid"
REMOTE_CURRENT_FILE="${REMOTE_MONITOR_DIR}/${MONITOR_LABEL}.current"

ssh "${SSH_OPTS[@]}" "${REMOTE}" "
  set -euo pipefail
  csv_path=
  if [[ -f '${REMOTE_CURRENT_FILE}' ]]; then
    csv_path=\$(cat '${REMOTE_CURRENT_FILE}' 2>/dev/null || true)
  fi
  if [[ -f '${REMOTE_PID_FILE}' ]]; then
    monitor_pid=\$(cat '${REMOTE_PID_FILE}' 2>/dev/null || true)
    if [[ -n \"\${monitor_pid}\" ]] && kill -0 \"\${monitor_pid}\" >/dev/null 2>&1; then
      kill \"\${monitor_pid}\" >/dev/null 2>&1 || true
    fi
    rm -f '${REMOTE_PID_FILE}'
  fi
  if [[ -n \"\${csv_path}\" ]]; then
    printf '%s\n' \"\${csv_path}\"
  fi
"

