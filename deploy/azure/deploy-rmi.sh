#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

AZURE_HOST="${AZURE_HOST:?Set AZURE_HOST (remote DNS/IP)}"
AZURE_USER="${AZURE_USER:?Set AZURE_USER (remote SSH user)}"
AZURE_SSH_PORT="${AZURE_SSH_PORT:-22}"
AZURE_REMOTE_DIR="${AZURE_REMOTE_DIR:-$HOME/dsgt}"
AZURE_SSH_KEY_PATH="${AZURE_SSH_KEY_PATH:-}"
RMI_REGISTRY_PORT="${RMI_REGISTRY_PORT:-1099}"
RMI_SERVICE_PORT="${RMI_SERVICE_PORT:-1100}"
RMI_BIND_NAME="${RMI_BIND_NAME:-BookingService}"
RMI_SERVER_HOSTNAME="${RMI_SERVER_HOSTNAME:-${AZURE_HOST}}"

SSH_OPTS=(-p "${AZURE_SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
if [[ -n "${AZURE_SSH_KEY_PATH}" ]]; then
  SSH_OPTS+=(-i "${AZURE_SSH_KEY_PATH}")
fi

REMOTE="${AZURE_USER}@${AZURE_HOST}"
if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required for deploy-rmi.sh" >&2
  exit 1
fi

(
  cd "${REPO_ROOT}/rmi"
  ant compile >/dev/null
)

ssh "${SSH_OPTS[@]}" "${REMOTE}" "mkdir -p '${AZURE_REMOTE_DIR}/deploy/local' '${AZURE_REMOTE_DIR}/rmi'"

rsync -az --delete -e "ssh ${SSH_OPTS[*]}" \
  "${REPO_ROOT}/rmi/" \
  "${REMOTE}:${AZURE_REMOTE_DIR}/rmi/"

rsync -az -e "ssh ${SSH_OPTS[*]}" \
  "${REPO_ROOT}/deploy/local/run-rmi.sh" \
  "${REMOTE}:${AZURE_REMOTE_DIR}/deploy/local/run-rmi.sh"

ssh "${SSH_OPTS[@]}" "${REMOTE}" "chmod +x '${AZURE_REMOTE_DIR}/deploy/local/run-rmi.sh' \
  && RMI_PIDS=\$(ss -ltnp | awk 'index(\$4, \":${RMI_REGISTRY_PORT}\") || index(\$4, \":${RMI_SERVICE_PORT}\") { while (match(\$0, /pid=[0-9]+/)) { print substr(\$0, RSTART+4, RLENGTH-4); \$0 = substr(\$0, RSTART+RLENGTH) } }' | sort -u) \
  && if [[ -n \"\${RMI_PIDS}\" ]]; then while IFS= read -r pid; do kill \"\${pid}\" >/dev/null 2>&1 || true; done <<< \"\${RMI_PIDS}\"; fi \
  && cd '${AZURE_REMOTE_DIR}' \
  && (nohup env BUILD_BEFORE_RUN='0' RMI_REGISTRY_PORT='${RMI_REGISTRY_PORT}' RMI_SERVICE_PORT='${RMI_SERVICE_PORT}' RMI_BIND_NAME='${RMI_BIND_NAME}' RMI_SERVER_HOSTNAME='${RMI_SERVER_HOSTNAME}' ./deploy/local/run-rmi.sh > '${AZURE_REMOTE_DIR}/rmi.log' 2>&1 < /dev/null &)"

ssh "${SSH_OPTS[@]}" "${REMOTE}" "for i in {1..30}; do \
  if ss -ltn | grep -q ':${RMI_REGISTRY_PORT} ' && ss -ltn | grep -q ':${RMI_SERVICE_PORT} '; then exit 0; fi; \
  sleep 2; \
done; \
echo 'RMI did not become ready in time' >&2; \
tail -n 40 '${AZURE_REMOTE_DIR}/rmi.log' >&2 || true; \
exit 1"

echo "RMI deploy triggered on ${REMOTE}:${RMI_REGISTRY_PORT}/${RMI_SERVICE_PORT}"
