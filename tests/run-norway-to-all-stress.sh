#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/azure_dsgt}"
SSH_PORT="${SSH_PORT:-22}"

CLIENT_HOST="${CLIENT_HOST:-dsgt-vm2.norwayeast.cloudapp.azure.com}"
CLIENT_USER="${CLIENT_USER:-tolga}"
CLIENT_LABEL="${CLIENT_LABEL:-norway}"

FRANCE_HOST="${FRANCE_HOST:-tkuntman.francecentral.cloudapp.azure.com}"
FRANCE_USER="${FRANCE_USER:-tolga}"
FRANCE_LABEL="${FRANCE_LABEL:-france}"

POLAND_HOST="${POLAND_HOST:-dsgt-vm3.polandcentral.cloudapp.azure.com}"
POLAND_USER="${POLAND_USER:-tolga}"
POLAND_LABEL="${POLAND_LABEL:-poland}"

SWEDEN_HOST="${SWEDEN_HOST:-dsgt-vm4.swedencentral.cloudapp.azure.com}"
SWEDEN_USER="${SWEDEN_USER:-tolga}"
SWEDEN_LABEL="${SWEDEN_LABEL:-sweden}"

REMOTE_TEST_DIR="${REMOTE_TEST_DIR:-/home/tolga/tests}"
REMOTE_RMI_DIR="${REMOTE_RMI_DIR:-/home/tolga/rmi}"
RUN_ID="${RUN_ID:-$(date -u +"%Y%m%dT%H%M%SZ")}"
LOCAL_RESULTS_DIR="${LOCAL_RESULTS_DIR:-${SCRIPT_DIR}/results/${CLIENT_LABEL}-to-all-stress-${RUN_ID}}"
REMOTE_RESULTS_DIR="${REMOTE_TEST_DIR}/results/${CLIENT_LABEL}-to-all-stress-${RUN_ID}"

usage() {
  cat <<'EOF'
Usage: tests/run-norway-to-all-stress.sh [options]

Runs Norway->France/Poland/Sweden stress tests and captures CPU/memory
monitoring on each target VM during the server-side load.

Coverage:
  Norway -> France   REST, SOAP, RMI
  Norway -> Poland   REST, SOAP
  Norway -> Sweden   RMI

Artifacts:
  - load CSVs are fetched into tests/results/<run-id>/
  - monitor CSVs are fetched into the same local directory

Options:
  --run-id ID                Identifier for result folders
  --local-results-dir DIR    Local result directory
  -h, --help                 Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) RUN_ID="$2"; shift 2 ;;
    --local-results-dir) LOCAL_RESULTS_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

REMOTE_RESULTS_DIR="${REMOTE_TEST_DIR}/results/${CLIENT_LABEL}-to-all-stress-${RUN_ID}"
mkdir -p "${LOCAL_RESULTS_DIR}"

ssh_opts=(-i "${SSH_KEY_PATH}" -p "${SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

sync_client_assets() {
  ssh "${ssh_opts[@]}" "${CLIENT_USER}@${CLIENT_HOST}" \
    "mkdir -p '${REMOTE_TEST_DIR}' '${REMOTE_RMI_DIR}/bin' '${REMOTE_RESULTS_DIR}'"

  rsync -az --delete -e "ssh ${ssh_opts[*]}" \
    "${SCRIPT_DIR}/" \
    "${CLIENT_USER}@${CLIENT_HOST}:${REMOTE_TEST_DIR}/"

  rsync -az --delete -e "ssh ${ssh_opts[*]}" \
    "${REPO_ROOT}/rmi/bin/" \
    "${CLIENT_USER}@${CLIENT_HOST}:${REMOTE_RMI_DIR}/bin/"
}

start_monitor() {
  local host="$1"
  local user="$2"
  local port="$3"
  local label="$4"
  AZURE_HOST="${host}" \
  AZURE_USER="${user}" \
  AZURE_SSH_KEY_PATH="${SSH_KEY_PATH}" \
  AZURE_SSH_PORT="${SSH_PORT}" \
  AZURE_REMOTE_DIR="/home/${user}/dsgt" \
  MONITOR_PORT="${port}" \
  MONITOR_LABEL="${label}" \
  "${REPO_ROOT}/deploy/azure/start-monitor.sh" >/dev/null
}

stop_and_fetch_monitor() {
  local host="$1"
  local user="$2"
  local label="$3"
  AZURE_HOST="${host}" \
  AZURE_USER="${user}" \
  AZURE_SSH_KEY_PATH="${SSH_KEY_PATH}" \
  AZURE_SSH_PORT="${SSH_PORT}" \
  AZURE_REMOTE_DIR="/home/${user}/dsgt" \
  MONITOR_LABEL="${label}" \
  "${REPO_ROOT}/deploy/azure/stop-monitor.sh" >/dev/null || true

  AZURE_HOST="${host}" \
  AZURE_USER="${user}" \
  AZURE_SSH_KEY_PATH="${SSH_KEY_PATH}" \
  AZURE_SSH_PORT="${SSH_PORT}" \
  AZURE_REMOTE_DIR="/home/${user}/dsgt" \
  MONITOR_LABEL="${label}" \
  DEST_DIR="${LOCAL_RESULTS_DIR}" \
  "${REPO_ROOT}/deploy/azure/fetch-monitor.sh" >/dev/null
}

run_remote_on_client() {
  local remote_cmd
  remote_cmd="$(cat)"
  ssh "${ssh_opts[@]}" "${CLIENT_USER}@${CLIENT_HOST}" "bash -lc $(printf '%q' "${remote_cmd}")"
}

run_rest_stress() {
  local target_label="$1"
  local target_host="$2"
  local target_user="$3"
  local monitor_label="${CLIENT_LABEL}-to-${target_label}-rest-${RUN_ID}"
  local output_name="${CLIENT_LABEL}-to-${target_label}-rest-stress.csv"

  start_monitor "${target_host}" "${target_user}" 8081 "${monitor_label}"
  run_remote_on_client <<EOF
set -euo pipefail
cd '${REMOTE_TEST_DIR}'
mkdir -p '${REMOTE_RESULTS_DIR}'
./load-rest.sh \
  --url 'http://${target_host}:8081/rest/meals' \
  --mode stress \
  --output '${REMOTE_RESULTS_DIR}/${output_name}'
EOF
  stop_and_fetch_monitor "${target_host}" "${target_user}" "${monitor_label}"
}

run_soap_stress() {
  local target_label="$1"
  local target_host="$2"
  local target_user="$3"
  local monitor_label="${CLIENT_LABEL}-to-${target_label}-soap-${RUN_ID}"
  local output_name="${CLIENT_LABEL}-to-${target_label}-soap-stress.csv"

  start_monitor "${target_host}" "${target_user}" 8082 "${monitor_label}"
  run_remote_on_client <<EOF
set -euo pipefail
cd '${REMOTE_TEST_DIR}'
mkdir -p '${REMOTE_RESULTS_DIR}'
./load-soap.sh \
  --endpoint-url 'http://${target_host}:8082/ws' \
  --body-file '${REMOTE_TEST_DIR}/soap-sample-request.xml' \
  --mode stress \
  --output '${REMOTE_RESULTS_DIR}/${output_name}'
EOF
  stop_and_fetch_monitor "${target_host}" "${target_user}" "${monitor_label}"
}

run_rmi_stress() {
  local target_label="$1"
  local target_host="$2"
  local target_user="$3"
  local monitor_label="${CLIENT_LABEL}-to-${target_label}-rmi-${RUN_ID}"
  local output_name="${CLIENT_LABEL}-to-${target_label}-rmi-stress.csv"

  start_monitor "${target_host}" "${target_user}" 1100 "${monitor_label}"
  run_remote_on_client <<EOF
set -euo pipefail
cd '${REMOTE_TEST_DIR}'
mkdir -p '${REMOTE_RESULTS_DIR}'
BUILD_BEFORE_RUN=0 RMI_DIR='${REMOTE_RMI_DIR}' RMI_BIN_DIR='${REMOTE_RMI_DIR}/bin' \
./load-rmi.sh \
  --host '${target_host}' \
  --port 1099 \
  --bind-name BookingService \
  --mode stress \
  --output '${REMOTE_RESULTS_DIR}/${output_name}'
EOF
  stop_and_fetch_monitor "${target_host}" "${target_user}" "${monitor_label}"
}

fetch_client_results() {
  rsync -az -e "ssh ${ssh_opts[*]}" \
    "${CLIENT_USER}@${CLIENT_HOST}:${REMOTE_RESULTS_DIR}/" \
    "${LOCAL_RESULTS_DIR}/"
}

echo "== Sync Norway client assets =="
sync_client_assets

echo "== Norway -> France stress =="
run_rest_stress "${FRANCE_LABEL}" "${FRANCE_HOST}" "${FRANCE_USER}"
run_soap_stress "${FRANCE_LABEL}" "${FRANCE_HOST}" "${FRANCE_USER}"
run_rmi_stress "${FRANCE_LABEL}" "${FRANCE_HOST}" "${FRANCE_USER}"

echo "== Norway -> Poland stress =="
run_rest_stress "${POLAND_LABEL}" "${POLAND_HOST}" "${POLAND_USER}"
run_soap_stress "${POLAND_LABEL}" "${POLAND_HOST}" "${POLAND_USER}"

echo "== Norway -> Sweden stress =="
run_rmi_stress "${SWEDEN_LABEL}" "${SWEDEN_HOST}" "${SWEDEN_USER}"

echo "== Fetch Norway client results =="
fetch_client_results

echo "Norway-to-all stress completed."
echo "Results: ${LOCAL_RESULTS_DIR}"
