#!/usr/bin/env bash
set -euo pipefail

REST_URL="${REST_URL:-http://localhost:8081/rest/meals}"
REQUESTS="${REQUESTS:-5}"
TIMEOUT_SEC="${TIMEOUT_SEC:-10}"
METHOD="${METHOD:-GET}"
DATA_FILE="${DATA_FILE:-}"
HEADER_VALUE="${HEADER_VALUE:-}"

usage() {
  cat <<'EOF'
Usage: tests/smoke-rest.sh [options]

Quick REST smoke test with a small number of requests.

Options:
  --url URL             Target REST endpoint (default: $REST_URL)
  --requests N          Number of requests (default: $REQUESTS)
  --timeout SEC         Curl timeout in seconds (default: $TIMEOUT_SEC)
  --method METHOD       HTTP method (default: $METHOD)
  --data-file PATH      Optional request payload file
  --header VALUE        Optional single HTTP header, e.g. "Content-Type: application/json"
  -h, --help            Show this help

Environment overrides:
  REST_URL, REQUESTS, TIMEOUT_SEC, METHOD, DATA_FILE, HEADER_VALUE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) REST_URL="$2"; shift 2 ;;
    --requests) REQUESTS="$2"; shift 2 ;;
    --timeout) TIMEOUT_SEC="$2"; shift 2 ;;
    --method) METHOD="$2"; shift 2 ;;
    --data-file) DATA_FILE="$2"; shift 2 ;;
    --header) HEADER_VALUE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if ! [[ "$REQUESTS" =~ ^[0-9]+$ ]] || [[ "$REQUESTS" -lt 1 ]]; then
  echo "REQUESTS must be a positive integer." >&2
  exit 1
fi

echo "REST smoke test"
echo "  URL: $REST_URL"
echo "  Method: $METHOD"
echo "  Requests: $REQUESTS"

success=0
errors=0

for ((i=1; i<=REQUESTS; i++)); do
  args=(-sS -m "$TIMEOUT_SEC" -o /dev/null -w "%{http_code}" -X "$METHOD")
  if [[ -n "$HEADER_VALUE" ]]; then
    args+=(-H "$HEADER_VALUE")
  fi
  if [[ -n "$DATA_FILE" ]]; then
    args+=(--data-binary "@$DATA_FILE")
  fi
  args+=("$REST_URL")

  if code="$(curl "${args[@]}" 2>/dev/null)"; then
    if [[ "$code" =~ ^[0-9]+$ ]] && [[ "$code" -lt 400 ]]; then
      success=$((success + 1))
      echo "[$i/$REQUESTS] OK (HTTP $code)"
    else
      errors=$((errors + 1))
      echo "[$i/$REQUESTS] FAIL (HTTP $code)"
    fi
  else
    errors=$((errors + 1))
    echo "[$i/$REQUESTS] FAIL (curl error)"
  fi
done

echo "Result: success=$success errors=$errors"
if [[ "$errors" -gt 0 ]]; then
  exit 1
fi
