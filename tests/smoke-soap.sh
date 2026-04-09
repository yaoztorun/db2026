#!/usr/bin/env bash
set -euo pipefail

SOAP_WSDL_URL="${SOAP_WSDL_URL:-http://localhost:8082/ws/meals.wsdl}"
SOAP_ENDPOINT_URL="${SOAP_ENDPOINT_URL:-http://localhost:8082/ws}"
SOAP_ACTION="${SOAP_ACTION:-}"
SOAP_BODY_FILE="${SOAP_BODY_FILE:-tests/soap-sample-request.xml}"
TIMEOUT_SEC="${TIMEOUT_SEC:-15}"

usage() {
  cat <<'EOF'
Usage: tests/smoke-soap.sh [options]

SOAP smoke test:
1) Fetch WSDL
2) Send sample SOAP request

Options:
  --wsdl-url URL        WSDL URL (default: $SOAP_WSDL_URL)
  --endpoint-url URL    SOAP endpoint URL (default: $SOAP_ENDPOINT_URL)
  --soap-action VALUE   Optional SOAPAction header value
  --body-file PATH      SOAP XML request body (default: $SOAP_BODY_FILE)
  --timeout SEC         Curl timeout in seconds (default: $TIMEOUT_SEC)
  -h, --help            Show this help

Environment overrides:
  SOAP_WSDL_URL, SOAP_ENDPOINT_URL, SOAP_ACTION, SOAP_BODY_FILE, TIMEOUT_SEC
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wsdl-url) SOAP_WSDL_URL="$2"; shift 2 ;;
    --endpoint-url) SOAP_ENDPOINT_URL="$2"; shift 2 ;;
    --soap-action) SOAP_ACTION="$2"; shift 2 ;;
    --body-file) SOAP_BODY_FILE="$2"; shift 2 ;;
    --timeout) TIMEOUT_SEC="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -f "$SOAP_BODY_FILE" ]]; then
  echo "SOAP body file not found: $SOAP_BODY_FILE" >&2
  exit 1
fi

echo "SOAP smoke test"
echo "  WSDL URL: $SOAP_WSDL_URL"
echo "  Endpoint: $SOAP_ENDPOINT_URL"
echo "  Body file: $SOAP_BODY_FILE"

tmp_wsdl="$(mktemp)"
tmp_resp="$(mktemp)"
trap 'rm -f "$tmp_wsdl" "$tmp_resp"' EXIT

wsdl_code="$(curl -sS -m "$TIMEOUT_SEC" -o "$tmp_wsdl" -w "%{http_code}" "$SOAP_WSDL_URL" || echo "000")"
if [[ "$wsdl_code" =~ ^[0-9]+$ ]] && [[ "$wsdl_code" -lt 400 ]]; then
  if grep -qi "definitions" "$tmp_wsdl"; then
    echo "WSDL fetch OK (HTTP $wsdl_code)"
  else
    echo "WSDL fetch returned HTTP $wsdl_code but no WSDL-like content detected." >&2
    exit 1
  fi
else
  echo "WSDL fetch failed (HTTP $wsdl_code)" >&2
  exit 1
fi

curl_args=(-sS -m "$TIMEOUT_SEC" -o "$tmp_resp" -w "%{http_code}" -X POST
  -H "Content-Type: text/xml; charset=utf-8"
  --data-binary "@$SOAP_BODY_FILE")

if [[ -n "$SOAP_ACTION" ]]; then
  curl_args+=(-H "SOAPAction: \"$SOAP_ACTION\"")
fi
curl_args+=("$SOAP_ENDPOINT_URL")

soap_code="$(curl "${curl_args[@]}" || echo "000")"
if [[ "$soap_code" =~ ^[0-9]+$ ]] && [[ "$soap_code" -lt 400 ]]; then
  if grep -qiE "<(soap:)?Envelope|<(soap:)?Fault|<[^>]+Response" "$tmp_resp"; then
    echo "SOAP request OK (HTTP $soap_code)"
  else
    echo "SOAP request returned HTTP $soap_code but response did not look like SOAP XML." >&2
    exit 1
  fi
else
  echo "SOAP request failed (HTTP $soap_code)." >&2
  echo "Tip: adjust --body-file and --soap-action for your service contract." >&2
  exit 1
fi
