#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RMI_HOST="${RMI_HOST:-127.0.0.1}"
RMI_REGISTRY_PORT="${RMI_REGISTRY_PORT:-1099}"
RMI_BIND_NAME="${RMI_BIND_NAME:-BookingService}"
BUILD_BEFORE_RUN="${BUILD_BEFORE_RUN:-1}"

usage() {
  cat <<'EOF'
Usage: tests/smoke-rmi.sh [options]

Runs the scripted RMI booking client against the configured registry.

Options:
  --host HOST        RMI registry host (default: 127.0.0.1)
  --port PORT        RMI registry port (default: 1099)
  --bind-name NAME   RMI binding name (default: BookingService)
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) RMI_HOST="$2"; shift 2 ;;
    --port) RMI_REGISTRY_PORT="$2"; shift 2 ;;
    --bind-name) RMI_BIND_NAME="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

echo "RMI smoke test"
echo "  Host: ${RMI_HOST}"
echo "  Port: ${RMI_REGISTRY_PORT}"
echo "  Binding: ${RMI_BIND_NAME}"

output="$(
  if [[ "${BUILD_BEFORE_RUN}" == "1" ]]; then
    cd "${REPO_ROOT}/rmi"
    ant -q compile >/dev/null
    env \
      RMI_HOST="${RMI_HOST}" \
      RMI_REGISTRY_PORT="${RMI_REGISTRY_PORT}" \
      RMI_BIND_NAME="${RMI_BIND_NAME}" \
      java -cp bin staff.BookingClient
  else
    cd "${REPO_ROOT}"
    env \
      RMI_HOST="${RMI_HOST}" \
      RMI_REGISTRY_PORT="${RMI_REGISTRY_PORT}" \
      RMI_BIND_NAME="${RMI_BIND_NAME}" \
      java -cp rmi/bin staff.BookingClient
  fi
)"

printf '%s\n' "${output}"

correct_count="$(printf '%s\n' "${output}" | grep -c '\[CORRECT\]' || true)"
if [[ "${correct_count}" -ne 4 ]]; then
  echo "RMI smoke test failed: expected 4 [CORRECT] markers, got ${correct_count}" >&2
  exit 1
fi

echo "RMI smoke test passed."
