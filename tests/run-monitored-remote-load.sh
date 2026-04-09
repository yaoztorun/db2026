#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SERVICE="${SERVICE:-}"
MODE="${MODE:-}"
TARGET_HOST="${TARGET_HOST:-}"
TARGET_LABEL="${TARGET_LABEL:-}"
RESULTS_DIR="${RESULTS_DIR:-${REPO_ROOT}/tests/results}"

AZURE_HOST="${AZURE_HOST:?Set AZURE_HOST (remote VM DNS/IP)}"
AZURE_USER="${AZURE_USER:?Set AZURE_USER (remote SSH user)}"
AZURE_SSH_KEY_PATH="${AZURE_SSH_KEY_PATH:-}"
AZURE_SSH_PORT="${AZURE_SSH_PORT:-22}"
AZURE_REMOTE_DIR="${AZURE_REMOTE_DIR:-$HOME/dsgt}"

usage() {
  cat <<'EOF'
Usage: tests/run-monitored-remote-load.sh --service rest|soap|rmi --mode baseline|increasing|stress --target-host HOST [options]

Runs a monitored load test against a remote service. The monitor runs on the
Azure VM hosting the service and records CPU/memory over time while the local
machine generates load.

Required:
  --service SERVICE        rest | soap | rmi
  --mode MODE             baseline | increasing | stress
  --target-host HOST      Public host/DNS of the service under test

Optional:
  --target-label LABEL    Friendly label for output filenames
  --results-dir DIR       Local output directory (default: tests/results)
  -h, --help              Show this help

Environment:
  AZURE_HOST              VM host to monitor
  AZURE_USER              VM SSH user
  AZURE_SSH_KEY_PATH      Optional private key path
  AZURE_SSH_PORT          SSH port (default: 22)
  AZURE_REMOTE_DIR        Remote repo root (default: $HOME/dsgt)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service) SERVICE="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --target-host) TARGET_HOST="$2"; shift 2 ;;
    --target-label) TARGET_LABEL="$2"; shift 2 ;;
    --results-dir) RESULTS_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${SERVICE}" || -z "${MODE}" || -z "${TARGET_HOST}" ]]; then
  usage >&2
  exit 1
fi

case "${SERVICE}" in
  rest)
    PORT=8081
    MONITOR_LABEL_BASE="rest"
    LOAD_CMD=(
      "${REPO_ROOT}/tests/load-rest.sh"
      --url "http://${TARGET_HOST}:8081/rest/meals"
      --mode "${MODE}"
    )
    ;;
  soap)
    PORT=8082
    MONITOR_LABEL_BASE="soap"
    LOAD_CMD=(
      "${REPO_ROOT}/tests/load-soap.sh"
      --endpoint-url "http://${TARGET_HOST}:8082/ws"
      --mode "${MODE}"
    )
    ;;
  rmi)
    PORT=1100
    MONITOR_LABEL_BASE="rmi"
    LOAD_CMD=(
      "${REPO_ROOT}/tests/load-rmi.sh"
      --host "${TARGET_HOST}"
      --port 1099
      --bind-name "BookingService"
      --mode "${MODE}"
    )
    ;;
  *)
    echo "Unsupported service: ${SERVICE}" >&2
    exit 1
    ;;
esac

mkdir -p "${RESULTS_DIR}"

STAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
SAFE_TARGET="${TARGET_LABEL:-${TARGET_HOST}}"
SAFE_TARGET="${SAFE_TARGET//[^A-Za-z0-9._-]/-}"
MONITOR_LABEL="${MONITOR_LABEL_BASE}-${SAFE_TARGET}-${MODE}-${STAMP}"
LOAD_OUTPUT="${RESULTS_DIR}/${MONITOR_LABEL}-load.csv"

START_ARGS=(
  env
  "AZURE_HOST=${AZURE_HOST}"
  "AZURE_USER=${AZURE_USER}"
  "AZURE_SSH_PORT=${AZURE_SSH_PORT}"
  "AZURE_REMOTE_DIR=${AZURE_REMOTE_DIR}"
  "MONITOR_PORT=${PORT}"
  "MONITOR_LABEL=${MONITOR_LABEL}"
)
if [[ -n "${AZURE_SSH_KEY_PATH}" ]]; then
  START_ARGS+=("AZURE_SSH_KEY_PATH=${AZURE_SSH_KEY_PATH}")
fi

echo "Starting remote monitor"
echo "  VM: ${AZURE_USER}@${AZURE_HOST}"
echo "  Service: ${SERVICE}"
echo "  Target: ${TARGET_HOST}"
echo "  Mode: ${MODE}"
echo "  Monitor label: ${MONITOR_LABEL}"

"${START_ARGS[@]}" "${REPO_ROOT}/deploy/azure/start-monitor.sh"

cleanup() {
  "${START_ARGS[@]}" "${REPO_ROOT}/deploy/azure/stop-monitor.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${LOAD_CMD[@]}" --output "${LOAD_OUTPUT}"

"${START_ARGS[@]}" "${REPO_ROOT}/deploy/azure/stop-monitor.sh"
"${START_ARGS[@]}" "DEST_DIR=${RESULTS_DIR}" "${REPO_ROOT}/deploy/azure/fetch-monitor.sh"

trap - EXIT

echo "Load CSV: ${LOAD_OUTPUT}"
echo "Monitor CSV: ${RESULTS_DIR}/${MONITOR_LABEL}.csv"
