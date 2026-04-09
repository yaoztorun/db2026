#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/azure_dsgt}"
SSH_PORT="${SSH_PORT:-22}"
CLIENT_A_HOST="${CLIENT_A_HOST:-tkuntman.francecentral.cloudapp.azure.com}"
CLIENT_A_USER="${CLIENT_A_USER:-tolga}"
CLIENT_A_LABEL="${CLIENT_A_LABEL:-france}"
CLIENT_B_HOST="${CLIENT_B_HOST:-dsgt-vm2.norwayeast.cloudapp.azure.com}"
CLIENT_B_USER="${CLIENT_B_USER:-tolga}"
CLIENT_B_LABEL="${CLIENT_B_LABEL:-norway}"
HTTP_HOST="${HTTP_HOST:-dsgt-vm3.polandcentral.cloudapp.azure.com}"
HTTP_LABEL="${HTTP_LABEL:-poland}"
RMI_HOST="${RMI_HOST:-dsgt-vm4.swedencentral.cloudapp.azure.com}"
RMI_LABEL="${RMI_LABEL:-sweden}"
REMOTE_TEST_DIR="${REMOTE_TEST_DIR:-/home/tolga/tests}"
REMOTE_RMI_DIR="${REMOTE_RMI_DIR:-/home/tolga/rmi}"
RUN_ID="${RUN_ID:-$(date -u +"%Y%m%dT%H%M%SZ")}"
LOCAL_RESULTS_DIR="${LOCAL_RESULTS_DIR:-${SCRIPT_DIR}/results/4vm-${RUN_ID}}"
REMOTE_RESULTS_DIR="${REMOTE_TEST_DIR}/results/4vm-${RUN_ID}"
RUN_REST_STRESS="${RUN_REST_STRESS:-1}"
RUN_ROUNDS="${RUN_ROUNDS:-1}"

usage() {
  cat <<'EOF'
Usage: tests/run-4vm-main-matrix.sh [options]

Runs the main Assignment 3 four-VM matrix:
- France client -> Poland REST/SOAP, Sweden RMI
- Norway client -> Poland REST/SOAP, Sweden RMI

It syncs the local tests/ folder and rmi/bin to the client VMs, runs the load
tests remotely, and fetches the resulting CSV files back into tests/results/.

Options:
  --run-id ID                Identifier for result folders (default: current UTC timestamp)
  --local-results-dir DIR    Local destination dir (default: tests/results/4vm-<run-id>)
  --rounds N                 Repeat each client matrix N times (default: 1)
  --skip-rest-stress         Skip REST stress on client VMs
  -h, --help                 Show this help

Environment overrides:
  SSH_KEY_PATH, SSH_PORT
  CLIENT_A_HOST, CLIENT_A_USER, CLIENT_A_LABEL
  CLIENT_B_HOST, CLIENT_B_USER, CLIENT_B_LABEL
  HTTP_HOST, HTTP_LABEL
  RMI_HOST, RMI_LABEL
  REMOTE_TEST_DIR, REMOTE_RMI_DIR
  RUN_ID, LOCAL_RESULTS_DIR, RUN_REST_STRESS, RUN_ROUNDS
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) RUN_ID="$2"; shift 2 ;;
    --local-results-dir) LOCAL_RESULTS_DIR="$2"; shift 2 ;;
    --rounds) RUN_ROUNDS="$2"; shift 2 ;;
    --skip-rest-stress) RUN_REST_STRESS=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if ! [[ "${RUN_ROUNDS}" =~ ^[0-9]+$ ]] || [[ "${RUN_ROUNDS}" -lt 1 ]]; then
  echo "RUN_ROUNDS must be a positive integer." >&2
  exit 1
fi

REMOTE_RESULTS_DIR="${REMOTE_TEST_DIR}/results/4vm-${RUN_ID}"
mkdir -p "${LOCAL_RESULTS_DIR}"

ssh_opts=(-i "${SSH_KEY_PATH}" -p "${SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

sync_client_assets() {
  local user="$1"
  local host="$2"

  ssh "${ssh_opts[@]}" "${user}@${host}" "mkdir -p '${REMOTE_TEST_DIR}' '${REMOTE_RMI_DIR}/bin' '${REMOTE_RESULTS_DIR}'"

  rsync -az --delete -e "ssh ${ssh_opts[*]}" \
    "${SCRIPT_DIR}/" \
    "${user}@${host}:${REMOTE_TEST_DIR}/"

  rsync -az --delete -e "ssh ${ssh_opts[*]}" \
    "${REPO_ROOT}/rmi/bin/" \
    "${user}@${host}:${REMOTE_RMI_DIR}/bin/"
}

run_client_matrix() {
  local user="$1"
  local host="$2"
  local client_label="$3"

  local remote_cmd
  printf -v remote_cmd '%q ' \
    bash -lc "
      set -euo pipefail
      cd '${REMOTE_TEST_DIR}'
      mkdir -p '${REMOTE_RESULTS_DIR}'
      for round in \$(seq 1 '${RUN_ROUNDS}'); do
        suffix='r'\${round}
        ./load-rest.sh --url 'http://${HTTP_HOST}:8081/rest/meals' --mode baseline --output '${REMOTE_RESULTS_DIR}/${client_label}-to-${HTTP_LABEL}-rest-baseline-'\${suffix}'.csv'
        ./load-rest.sh --url 'http://${HTTP_HOST}:8081/rest/meals' --mode increasing --output '${REMOTE_RESULTS_DIR}/${client_label}-to-${HTTP_LABEL}-rest-increasing-'\${suffix}'.csv'
        if [[ '${RUN_REST_STRESS}' == '1' ]]; then
          ./load-rest.sh --url 'http://${HTTP_HOST}:8081/rest/meals' --mode stress --output '${REMOTE_RESULTS_DIR}/${client_label}-to-${HTTP_LABEL}-rest-stress-'\${suffix}'.csv'
        fi
        ./load-soap.sh --endpoint-url 'http://${HTTP_HOST}:8082/ws' --body-file '${REMOTE_TEST_DIR}/soap-sample-request.xml' --mode baseline --output '${REMOTE_RESULTS_DIR}/${client_label}-to-${HTTP_LABEL}-soap-baseline-'\${suffix}'.csv'
        ./load-soap.sh --endpoint-url 'http://${HTTP_HOST}:8082/ws' --body-file '${REMOTE_TEST_DIR}/soap-sample-request.xml' --mode increasing --output '${REMOTE_RESULTS_DIR}/${client_label}-to-${HTTP_LABEL}-soap-increasing-'\${suffix}'.csv'
        BUILD_BEFORE_RUN=0 RMI_DIR='${REMOTE_RMI_DIR}' RMI_BIN_DIR='${REMOTE_RMI_DIR}/bin' ./load-rmi.sh --host '${RMI_HOST}' --port 1099 --bind-name BookingService --mode baseline --output '${REMOTE_RESULTS_DIR}/${client_label}-to-${RMI_LABEL}-rmi-baseline-'\${suffix}'.csv'
        BUILD_BEFORE_RUN=0 RMI_DIR='${REMOTE_RMI_DIR}' RMI_BIN_DIR='${REMOTE_RMI_DIR}/bin' ./load-rmi.sh --host '${RMI_HOST}' --port 1099 --bind-name BookingService --mode increasing --output '${REMOTE_RESULTS_DIR}/${client_label}-to-${RMI_LABEL}-rmi-increasing-'\${suffix}'.csv'
      done
    "

  ssh "${ssh_opts[@]}" "${user}@${host}" "${remote_cmd}"
}

fetch_client_results() {
  local user="$1"
  local host="$2"
  rsync -az -e "ssh ${ssh_opts[*]}" \
    "${user}@${host}:${REMOTE_RESULTS_DIR}/" \
    "${LOCAL_RESULTS_DIR}/"
}

echo "== Sync client assets =="
sync_client_assets "${CLIENT_A_USER}" "${CLIENT_A_HOST}"
sync_client_assets "${CLIENT_B_USER}" "${CLIENT_B_HOST}"

echo "== Run client matrix: ${CLIENT_A_LABEL} =="
run_client_matrix "${CLIENT_A_USER}" "${CLIENT_A_HOST}" "${CLIENT_A_LABEL}"

echo "== Run client matrix: ${CLIENT_B_LABEL} =="
run_client_matrix "${CLIENT_B_USER}" "${CLIENT_B_HOST}" "${CLIENT_B_LABEL}"

echo "== Fetch results =="
fetch_client_results "${CLIENT_A_USER}" "${CLIENT_A_HOST}"
fetch_client_results "${CLIENT_B_USER}" "${CLIENT_B_HOST}"

echo "4-VM matrix completed."
echo "Results: ${LOCAL_RESULTS_DIR}"
