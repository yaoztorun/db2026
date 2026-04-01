#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SERVICE_DIR="${REPO_ROOT}/rest"

REST_PORT="${REST_PORT:-8081}"
MAVEN_BIN="${MAVEN_BIN:-mvn}"
JAVA_BIN="${JAVA_BIN:-java}"
BUILD_BEFORE_RUN="${BUILD_BEFORE_RUN:-1}"

cd "${SERVICE_DIR}"
if [[ "${BUILD_BEFORE_RUN}" == "1" ]]; then
  "${MAVEN_BIN}" -DskipTests package
fi

JAR_PATH="$(
  ls -1t target/*.jar 2>/dev/null \
    | grep -vE '\.original$' \
    | head -n 1
)"

if [[ -z "${JAR_PATH}" ]]; then
  echo "No runnable REST jar found in ${SERVICE_DIR}/target" >&2
  exit 1
fi

exec "${JAVA_BIN}" -jar "${JAR_PATH}" --server.port="${REST_PORT}"
