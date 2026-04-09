#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-}"
ITERATIONS="${2:-20}"

if [[ -z "$HOST" ]]; then
  echo "Usage: tests/probe-soap-method-latency.sh <host> [iterations]" >&2
  exit 1
fi

ENDPOINT="http://${HOST}:8082/ws"
ROOT="/home/parallels/Desktop/dsgt/tests"

request() {
  local body_file="$1"
  local result time_s code
  result="$(curl -sS -m 20 -o /dev/null -w "%{time_total},%{http_code}" -X POST -H "Content-Type: text/xml; charset=utf-8" --data-binary "@$body_file" "$ENDPOINT" 2>/dev/null || echo "20,000")"
  time_s="${result%%,*}"
  code="${result##*,}"
  awk -v t="$time_s" -v c="$code" 'BEGIN { printf "%.3f,%s\n", t * 1000, c }'
}

run_method() {
  local label="$1"
  local body_file="$2"
  local i
  for ((i=1; i<=ITERATIONS; i++)); do
    printf "%s,%d," "$label" "$i"
    request "$body_file"
  done
}

echo "method,iteration,latency_ms,http_code"
run_method "getMeal" "${ROOT}/soap-get-meal-request.xml"
run_method "getCheapestMeal" "${ROOT}/soap-get-cheapest-request.xml"
run_method "getLargestMeal" "${ROOT}/soap-sample-request.xml"
run_method "addOrder" "${ROOT}/soap-add-order-request.xml"
