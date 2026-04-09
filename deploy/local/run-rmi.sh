#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SERVICE_DIR="${REPO_ROOT}/rmi"

ANT_BIN="${ANT_BIN:-ant}"
JAVA_BIN="${JAVA_BIN:-java}"
BUILD_BEFORE_RUN="${BUILD_BEFORE_RUN:-1}"
RMI_REGISTRY_PORT="${RMI_REGISTRY_PORT:-1099}"
RMI_SERVICE_PORT="${RMI_SERVICE_PORT:-1100}"
RMI_BIND_NAME="${RMI_BIND_NAME:-BookingService}"
RMI_SERVER_HOSTNAME="${RMI_SERVER_HOSTNAME:-127.0.0.1}"

cd "${SERVICE_DIR}"
if [[ "${BUILD_BEFORE_RUN}" == "1" ]]; then
  "${ANT_BIN}" compile >/dev/null
fi

exec env \
  RMI_REGISTRY_PORT="${RMI_REGISTRY_PORT}" \
  RMI_SERVICE_PORT="${RMI_SERVICE_PORT}" \
  RMI_BIND_NAME="${RMI_BIND_NAME}" \
  RMI_SERVER_HOSTNAME="${RMI_SERVER_HOSTNAME}" \
  "${JAVA_BIN}" \
  -cp "${SERVICE_DIR}/bin" \
  -Djava.rmi.server.hostname="${RMI_SERVER_HOSTNAME}" \
  staff.BookingServer
