#!/usr/bin/env bash
set -euo pipefail

AZURE_HOST="${AZURE_HOST:?Set AZURE_HOST (remote DNS/IP)}"
AZURE_USER="${AZURE_USER:?Set AZURE_USER (remote SSH user)}"
AZURE_SSH_PORT="${AZURE_SSH_PORT:-22}"
AZURE_REMOTE_DIR="${AZURE_REMOTE_DIR:-$HOME/dsgt}"
AZURE_SSH_KEY_PATH="${AZURE_SSH_KEY_PATH:-}"
MONITOR_LABEL="${MONITOR_LABEL:-}"
DEST_DIR="${DEST_DIR:-report/raw}"

usage() {
  cat <<'EOF'
Usage: deploy/azure/fetch-monitor.sh [options]

Fetches the latest monitor CSV for a label from the remote VM into the local repo.

Options:
  --label LABEL       Friendly label used when starting the monitor
  --dest-dir PATH     Local destination directory (default: report/raw)
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) MONITOR_LABEL="$2"; shift 2 ;;
    --dest-dir) DEST_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${MONITOR_LABEL}" ]]; then
  echo "Set MONITOR_LABEL or pass --label." >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"

SSH_OPTS=(-p "${AZURE_SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
if [[ -n "${AZURE_SSH_KEY_PATH}" ]]; then
  SSH_OPTS+=(-i "${AZURE_SSH_KEY_PATH}")
fi

REMOTE="${AZURE_USER}@${AZURE_HOST}"
REMOTE_CURRENT_FILE="${AZURE_REMOTE_DIR}/monitor/${MONITOR_LABEL}.current"

remote_csv="$(ssh "${SSH_OPTS[@]}" "${REMOTE}" "cat '${REMOTE_CURRENT_FILE}'")"
if [[ -z "${remote_csv}" ]]; then
  echo "No remote CSV recorded for label '${MONITOR_LABEL}'." >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required for fetch-monitor.sh" >&2
  exit 1
fi

rsync -az -e "ssh ${SSH_OPTS[*]}" \
  "${REMOTE}:${remote_csv}" \
  "${DEST_DIR}/"

echo "Fetched monitor CSV to ${DEST_DIR}/$(basename "${remote_csv}")"

