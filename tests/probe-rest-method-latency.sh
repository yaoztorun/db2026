#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-}"
ITERATIONS="${2:-20}"

if [[ -z "$HOST" ]]; then
  echo "Usage: tests/probe-rest-method-latency.sh <host> [iterations]" >&2
  exit 1
fi

BASE_URL="http://${HOST}:8081"
ORDER_PAYLOAD="/home/parallels/Desktop/dsgt/rest/src/main/resources/requests/new-order.json"

request() {
  local method="$1"
  local url="$2"
  local body_file="${3:-}"
  local result time_s code

  if [[ -n "$body_file" ]]; then
    result="$(curl -sS -m 15 -o /dev/null -w "%{time_total},%{http_code}" -X "$method" -H "Content-Type: application/json" --data-binary "@$body_file" "$url" 2>/dev/null || echo "15,000")"
  else
    result="$(curl -sS -m 15 -o /dev/null -w "%{time_total},%{http_code}" -X "$method" "$url" 2>/dev/null || echo "15,000")"
  fi

  time_s="${result%%,*}"
  code="${result##*,}"
  awk -v t="$time_s" -v c="$code" 'BEGIN { printf "%.3f,%s\n", t * 1000, c }'
}

run_method() {
  local label="$1"
  local method="$2"
  local url="$3"
  local body_file="${4:-}"
  local i
  for ((i=1; i<=ITERATIONS; i++)); do
    printf "%s,%d," "$label" "$i"
    request "$method" "$url" "$body_file"
  done
}

echo "method,iteration,latency_ms,http_code"
run_method "getMeals" GET "${BASE_URL}/rest/meals"
run_method "getMealById" GET "${BASE_URL}/rest/meals/5268203c-de76-4921-a3e3-439db69c462a"
run_method "getCheapestMeal" GET "${BASE_URL}/rest/cheapest"
run_method "getLargestMeal" GET "${BASE_URL}/rest/largest"
run_method "addOrder" POST "${BASE_URL}/rest/order" "$ORDER_PAYLOAD"
