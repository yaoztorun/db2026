#!/usr/bin/env bash
set -euo pipefail

RUN_SOAP_SMOKE="${RUN_SOAP_SMOKE:-1}"
RUN_SOAP_LOAD="${RUN_SOAP_LOAD:-1}"
RUN_RMI_SMOKE="${RUN_RMI_SMOKE:-0}"
RUN_RMI_LOAD="${RUN_RMI_LOAD:-0}"
RUN_STRESS="${RUN_STRESS:-0}"
REST_URL="${REST_URL:-http://localhost:8081/rest/meals}"
SOAP_WSDL_URL="${SOAP_WSDL_URL:-http://localhost:8082/ws/meals.wsdl}"
SOAP_ENDPOINT_URL="${SOAP_ENDPOINT_URL:-http://localhost:8082/ws}"
SOAP_ACTION="${SOAP_ACTION:-}"
RMI_HOST="${RMI_HOST:-127.0.0.1}"
RMI_REGISTRY_PORT="${RMI_REGISTRY_PORT:-1099}"
RMI_BIND_NAME="${RMI_BIND_NAME:-BookingService}"
RESULTS_DIR="${RESULTS_DIR:-tests/results}"

usage() {
  cat <<'EOF'
Usage: tests/run-all.sh [options]

Runs the assignment test flow:
1) REST smoke
2) SOAP smoke (optional)
3) SOAP load (optional)
4) RMI smoke (optional)
5) RMI load (optional)
6) REST load: baseline + increasing (+ optional stress)

Options:
  --rest-url URL          REST endpoint URL
  --soap-wsdl-url URL     SOAP WSDL URL
  --soap-endpoint-url URL SOAP endpoint URL
  --soap-action VALUE     Optional SOAPAction for SOAP load/smoke
  --with-rmi              Include RMI smoke test
  --with-rmi-load         Include RMI smoke + load test
  --rmi-host HOST         RMI registry host
  --rmi-port PORT         RMI registry port
  --rmi-bind-name NAME    RMI binding name
  --skip-soap-load        Skip SOAP load test
  --skip-soap             Skip SOAP smoke test
  --with-stress           Include stress load run
  --results-dir PATH      Directory for CSV outputs (default: tests/results)
  -h, --help              Show this help

Environment overrides:
  RUN_SOAP_SMOKE, RUN_SOAP_LOAD, RUN_RMI_SMOKE, RUN_RMI_LOAD, RUN_STRESS
  REST_URL, SOAP_WSDL_URL, SOAP_ENDPOINT_URL, SOAP_ACTION
  RMI_HOST, RMI_REGISTRY_PORT, RMI_BIND_NAME, RESULTS_DIR
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rest-url) REST_URL="$2"; shift 2 ;;
    --soap-wsdl-url) SOAP_WSDL_URL="$2"; shift 2 ;;
    --soap-endpoint-url) SOAP_ENDPOINT_URL="$2"; shift 2 ;;
    --soap-action) SOAP_ACTION="$2"; shift 2 ;;
    --with-rmi) RUN_RMI_SMOKE=1; shift ;;
    --with-rmi-load) RUN_RMI_SMOKE=1; RUN_RMI_LOAD=1; shift ;;
    --rmi-host) RMI_HOST="$2"; shift 2 ;;
    --rmi-port) RMI_REGISTRY_PORT="$2"; shift 2 ;;
    --rmi-bind-name) RMI_BIND_NAME="$2"; shift 2 ;;
    --skip-soap-load) RUN_SOAP_LOAD=0; shift ;;
    --skip-soap) RUN_SOAP_SMOKE=0; shift ;;
    --with-stress) RUN_STRESS=1; shift ;;
    --results-dir) RESULTS_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

mkdir -p "$RESULTS_DIR"
stamp="$(date -u +"%Y%m%dT%H%M%SZ")"

echo "== REST smoke =="
./tests/smoke-rest.sh --url "$REST_URL" --requests 5

if [[ "$RUN_SOAP_SMOKE" == "1" ]]; then
  echo "== SOAP smoke =="
  ./tests/smoke-soap.sh --wsdl-url "$SOAP_WSDL_URL" --endpoint-url "$SOAP_ENDPOINT_URL" ${SOAP_ACTION:+--soap-action "$SOAP_ACTION"}
else
  echo "== SOAP smoke skipped =="
fi

if [[ "$RUN_SOAP_LOAD" == "1" ]]; then
  echo "== SOAP load: baseline =="
  ./tests/load-soap.sh --endpoint-url "$SOAP_ENDPOINT_URL" --mode baseline --output "$RESULTS_DIR/load-soap-baseline-$stamp.csv" ${SOAP_ACTION:+--soap-action "$SOAP_ACTION"}

  echo "== SOAP load: increasing =="
  ./tests/load-soap.sh --endpoint-url "$SOAP_ENDPOINT_URL" --mode increasing --output "$RESULTS_DIR/load-soap-increasing-$stamp.csv" ${SOAP_ACTION:+--soap-action "$SOAP_ACTION"}
else
  echo "== SOAP load skipped =="
fi

if [[ "$RUN_RMI_SMOKE" == "1" ]]; then
  echo "== RMI smoke =="
  ./tests/smoke-rmi.sh --host "$RMI_HOST" --port "$RMI_REGISTRY_PORT" --bind-name "$RMI_BIND_NAME"
else
  echo "== RMI smoke skipped =="
fi

if [[ "$RUN_RMI_LOAD" == "1" ]]; then
  echo "== RMI load: baseline =="
  ./tests/load-rmi.sh --host "$RMI_HOST" --port "$RMI_REGISTRY_PORT" --bind-name "$RMI_BIND_NAME" --mode baseline --output "$RESULTS_DIR/load-rmi-baseline-$stamp.csv"

  echo "== RMI load: increasing =="
  ./tests/load-rmi.sh --host "$RMI_HOST" --port "$RMI_REGISTRY_PORT" --bind-name "$RMI_BIND_NAME" --mode increasing --output "$RESULTS_DIR/load-rmi-increasing-$stamp.csv"

  if [[ "$RUN_STRESS" == "1" ]]; then
    echo "== RMI load: stress =="
    ./tests/load-rmi.sh --host "$RMI_HOST" --port "$RMI_REGISTRY_PORT" --bind-name "$RMI_BIND_NAME" --mode stress --output "$RESULTS_DIR/load-rmi-stress-$stamp.csv"
  fi
else
  echo "== RMI load skipped =="
fi

echo "== REST load: baseline =="
./tests/load-rest.sh --url "$REST_URL" --mode baseline --output "$RESULTS_DIR/load-rest-baseline-$stamp.csv"

echo "== REST load: increasing =="
./tests/load-rest.sh --url "$REST_URL" --mode increasing --output "$RESULTS_DIR/load-rest-increasing-$stamp.csv"

if [[ "$RUN_STRESS" == "1" ]]; then
  echo "== REST load: stress =="
  ./tests/load-rest.sh --url "$REST_URL" --mode stress --output "$RESULTS_DIR/load-rest-stress-$stamp.csv"
fi

echo "All configured tests completed."
