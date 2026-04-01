#!/usr/bin/env bash
set -euo pipefail

AZURE_BASE_URL="${AZURE_BASE_URL:-http://localhost}"
REST_PORT="${REST_PORT:-8081}"
SOAP_PORT="${SOAP_PORT:-8082}"

REST_HEALTH_URL="${REST_HEALTH_URL:-${AZURE_BASE_URL}:${REST_PORT}/rest/meals}"
SOAP_WSDL_URL="${SOAP_WSDL_URL:-${AZURE_BASE_URL}:${SOAP_PORT}/ws/meals.wsdl}"
CURL_BIN="${CURL_BIN:-curl}"

check_http() {
  local name="$1"
  local url="$2"
  local status

  status="$("${CURL_BIN}" -sS -o /dev/null -w '%{http_code}' --max-time 10 "${url}" || true)"
  if [[ "${status}" != "200" ]]; then
    echo "${name} check failed: ${url} returned ${status}" >&2
    return 1
  fi

  echo "${name} check passed: ${url}"
}

check_http "REST" "${REST_HEALTH_URL}"
check_http "SOAP_WSDL" "${SOAP_WSDL_URL}"
