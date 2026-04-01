#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

AZURE_HOST="${AZURE_HOST:?Set AZURE_HOST (remote DNS/IP)}"
AZURE_USER="${AZURE_USER:?Set AZURE_USER (remote SSH user)}"
AZURE_SSH_PORT="${AZURE_SSH_PORT:-22}"
AZURE_REMOTE_DIR="${AZURE_REMOTE_DIR:-$HOME/dsgt}"
AZURE_SSH_KEY_PATH="${AZURE_SSH_KEY_PATH:-}"
REST_PORT="${REST_PORT:-8081}"

SSH_OPTS=(-p "${AZURE_SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
if [[ -n "${AZURE_SSH_KEY_PATH}" ]]; then
  SSH_OPTS+=(-i "${AZURE_SSH_KEY_PATH}")
fi

REMOTE="${AZURE_USER}@${AZURE_HOST}"
if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required for deploy-rest.sh" >&2
  exit 1
fi

(
  cd "${REPO_ROOT}/rest"
  mvn -q -DskipTests package
)

ssh "${SSH_OPTS[@]}" "${REMOTE}" "mkdir -p '${AZURE_REMOTE_DIR}/deploy/local' '${AZURE_REMOTE_DIR}/rest'"

rsync -az --delete -e "ssh ${SSH_OPTS[*]}" \
  "${REPO_ROOT}/rest/" \
  "${REMOTE}:${AZURE_REMOTE_DIR}/rest/"

rsync -az -e "ssh ${SSH_OPTS[*]}" \
  "${REPO_ROOT}/deploy/local/run-rest.sh" \
  "${REMOTE}:${AZURE_REMOTE_DIR}/deploy/local/run-rest.sh"

ssh "${SSH_OPTS[@]}" "${REMOTE}" "chmod +x '${AZURE_REMOTE_DIR}/deploy/local/run-rest.sh' \
  && REST_PID=\$(ss -ltnp | awk '/:8081 /{if (match(\$0, /pid=[0-9]+/)) {print substr(\$0, RSTART+4, RLENGTH-4); exit}}') \
  && if [[ -n \"\${REST_PID}\" ]]; then kill \"\${REST_PID}\" >/dev/null 2>&1 || true; fi \
  && cd '${AZURE_REMOTE_DIR}' \
  && (nohup env REST_PORT='${REST_PORT}' BUILD_BEFORE_RUN='0' ./deploy/local/run-rest.sh > '${AZURE_REMOTE_DIR}/rest.log' 2>&1 < /dev/null &)"

ssh "${SSH_OPTS[@]}" "${REMOTE}" "for i in {1..60}; do \
  code=\$(curl -s -o /dev/null -w '%{http_code}' 'http://localhost:${REST_PORT}/rest/meals' || true); \
  if [[ \"\${code}\" == '200' ]]; then exit 0; fi; \
  sleep 2; \
done; \
echo 'REST did not become ready in time' >&2; \
tail -n 40 '${AZURE_REMOTE_DIR}/rest.log' >&2 || true; \
exit 1"

echo "REST deploy triggered on ${REMOTE}:${REST_PORT}"
