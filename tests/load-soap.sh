#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOAP_ENDPOINT_URL="${SOAP_ENDPOINT_URL:-http://localhost:8082/ws}"
SOAP_BODY_FILE="${SOAP_BODY_FILE:-${SCRIPT_DIR}/soap-sample-request.xml}"
SOAP_ACTION="${SOAP_ACTION:-}"
MODE="${MODE:-baseline}"
TIMEOUT_SEC="${TIMEOUT_SEC:-20}"
BASELINE_REQUESTS="${BASELINE_REQUESTS:-20}"
INCREASING_REQUESTS="${INCREASING_REQUESTS:-50}"
STRESS_REQUESTS="${STRESS_REQUESTS:-80}"
BASELINE_CLIENTS="${BASELINE_CLIENTS:-1}"
INCREASING_CLIENTS="${INCREASING_CLIENTS:-1,5,10,20}"
STRESS_CLIENTS="${STRESS_CLIENTS:-20,40}"
CLIENTS_OVERRIDE=""
OUTPUT_FILE="${OUTPUT_FILE:-}"

usage() {
  cat <<'EOF'
Usage: tests/load-soap.sh [options]

SOAP load test runner with three modes:
  baseline   - single, light run
  increasing - stepped concurrent client runs
  stress     - heavier concurrent runs

Options:
  --endpoint-url URL     SOAP endpoint URL (default: $SOAP_ENDPOINT_URL)
  --body-file PATH       SOAP request payload file (default: $SOAP_BODY_FILE)
  --soap-action VALUE    Optional SOAPAction header value
  --mode MODE            baseline|increasing|stress (default: $MODE)
  --clients LIST         Override clients. Single value or comma list.
  --requests N           Requests per client for selected mode
  --timeout SEC          Curl timeout in seconds (default: $TIMEOUT_SEC)
  --output PATH          CSV output path (default: tests/results/load-soap-<timestamp>.csv)
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint-url) SOAP_ENDPOINT_URL="$2"; shift 2 ;;
    --body-file) SOAP_BODY_FILE="$2"; shift 2 ;;
    --soap-action) SOAP_ACTION="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --clients) CLIENTS_OVERRIDE="$2"; shift 2 ;;
    --requests)
      case "$MODE" in
        baseline) BASELINE_REQUESTS="$2" ;;
        increasing) INCREASING_REQUESTS="$2" ;;
        stress) STRESS_REQUESTS="$2" ;;
        *) echo "Unknown mode: $MODE" >&2; exit 1 ;;
      esac
      shift 2
      ;;
    --timeout) TIMEOUT_SEC="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -f "$SOAP_BODY_FILE" ]]; then
  echo "SOAP body file not found: $SOAP_BODY_FILE" >&2
  exit 1
fi

for n in "$TIMEOUT_SEC" "$BASELINE_REQUESTS" "$INCREASING_REQUESTS" "$STRESS_REQUESTS" "$BASELINE_CLIENTS"; do
  if ! [[ "$n" =~ ^[0-9]+$ ]] || [[ "$n" -lt 1 ]]; then
    echo "Numeric configuration values must be positive integers." >&2
    exit 1
  fi
done

timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
results_dir="${SCRIPT_DIR}/results"
mkdir -p "$results_dir"
if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$results_dir/load-soap-$timestamp.csv"
fi

if [[ ! -f "$OUTPUT_FILE" ]]; then
  cat > "$OUTPUT_FILE" <<'EOF'
run_timestamp,mode,scenario,clients,requests_per_client,total_requests,success,errors,duration_ms,throughput_rps,avg_latency_ms,min_latency_ms,p50_latency_ms,p95_latency_ms,max_latency_ms,endpoint
EOF
fi

soap_request() {
  local out_file="$1"
  local requests="$2"
  local i code time_s latency_ms ok

  for ((i=1; i<=requests; i++)); do
    args=(-sS -m "$TIMEOUT_SEC" -o /dev/null -w "%{time_total},%{http_code}" -X POST
      -H "Content-Type: text/xml; charset=utf-8"
      --data-binary "@$SOAP_BODY_FILE")
    if [[ -n "$SOAP_ACTION" ]]; then
      args+=(-H "SOAPAction: \"$SOAP_ACTION\"")
    fi
    args+=("$SOAP_ENDPOINT_URL")

    if result="$(curl "${args[@]}" 2>/dev/null)"; then
      time_s="${result%%,*}"
      code="${result##*,}"
    else
      time_s="$TIMEOUT_SEC"
      code="000"
    fi

    latency_ms="$(awk -v t="$time_s" 'BEGIN {printf "%.3f", t * 1000}')"
    if [[ "$code" =~ ^[0-9]+$ ]] && [[ "$code" -ge 200 ]] && [[ "$code" -lt 400 ]]; then
      ok=1
    else
      ok=0
    fi
    printf "%s,%s,%s\n" "$latency_ms" "$code" "$ok" >> "$out_file"
  done
}

percentile_from_sorted() {
  local sorted_file="$1"
  local p="$2"
  awk -v pct="$p" '
    {v[NR]=$1}
    END{
      if (NR == 0) {print "0.000"; exit}
      pos = (pct / 100.0) * NR
      idx = int(pos)
      if (pos > idx) idx++
      if (idx < 1) idx=1
      if (idx > NR) idx=NR
      printf "%.3f", v[idx]
    }' "$sorted_file"
}

run_scenario() {
  local mode="$1"
  local clients="$2"
  local requests_per_client="$3"
  local scenario_name="$4"

  echo "Running SOAP scenario '$scenario_name': clients=$clients requests_per_client=$requests_per_client"

  local tmp_dir start_ms end_ms duration_ms
  tmp_dir="$(mktemp -d)"
  start_ms="$(date +%s%3N)"

  local client
  for ((client=1; client<=clients; client++)); do
    soap_request "$tmp_dir/client-$client.csv" "$requests_per_client" &
  done
  wait

  end_ms="$(date +%s%3N)"
  duration_ms=$((end_ms - start_ms))
  if [[ "$duration_ms" -lt 1 ]]; then
    duration_ms=1
  fi

  local merged lat_only sorted_lat
  merged="$tmp_dir/all.csv"
  lat_only="$tmp_dir/latency.txt"
  sorted_lat="$tmp_dir/latency-sorted.txt"
  cat "$tmp_dir"/client-*.csv > "$merged"
  cut -d, -f1 "$merged" > "$lat_only"
  sort -n "$lat_only" > "$sorted_lat"

  local total success errors avg min max p50 p95 throughput run_ts
  total="$(wc -l < "$merged" | tr -d ' ')"
  success="$(awk -F, '$3 == 1 {c++} END {print c+0}' "$merged")"
  errors=$((total - success))
  avg="$(awk -F, '{s+=$1; n++} END {if (n==0) printf "0.000"; else printf "%.3f", s/n}' "$merged")"
  min="$(awk -F, 'NR==1{m=$1} $1<m{m=$1} END{if (NR==0) printf "0.000"; else printf "%.3f", m}' "$merged")"
  max="$(awk -F, 'NR==1{m=$1} $1>m{m=$1} END{if (NR==0) printf "0.000"; else printf "%.3f", m}' "$merged")"
  p50="$(percentile_from_sorted "$sorted_lat" 50)"
  p95="$(percentile_from_sorted "$sorted_lat" 95)"
  throughput="$(awk -v total="$total" -v ms="$duration_ms" 'BEGIN {printf "%.3f", (total * 1000.0) / ms}')"
  run_ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
    "$run_ts" "$mode" "$scenario_name" "$clients" "$requests_per_client" "$total" "$success" "$errors" \
    "$duration_ms" "$throughput" "$avg" "$min" "$p50" "$p95" "$max" "$SOAP_ENDPOINT_URL" >> "$OUTPUT_FILE"

  echo "SOAP scenario '$scenario_name' done: total=$total success=$success errors=$errors throughput=${throughput}req/s"
  rm -rf "$tmp_dir"
}

run_mode() {
  local mode="$1"
  local clients_csv requests_per_client
  case "$mode" in
    baseline)
      clients_csv="$BASELINE_CLIENTS"
      requests_per_client="$BASELINE_REQUESTS"
      ;;
    increasing)
      clients_csv="$INCREASING_CLIENTS"
      requests_per_client="$INCREASING_REQUESTS"
      ;;
    stress)
      clients_csv="$STRESS_CLIENTS"
      requests_per_client="$STRESS_REQUESTS"
      ;;
    *)
      echo "Unknown mode: $mode" >&2
      exit 1
      ;;
  esac

  if [[ -n "$CLIENTS_OVERRIDE" ]]; then
    clients_csv="$CLIENTS_OVERRIDE"
  fi

  IFS=',' read -r -a client_steps <<< "$clients_csv"
  local c
  for c in "${client_steps[@]}"; do
    run_scenario "$mode" "$c" "$requests_per_client" "${mode}-c${c}-r${requests_per_client}"
  done
}

echo "SOAP load test"
echo "  Endpoint: $SOAP_ENDPOINT_URL"
echo "  Mode: $MODE"
echo "  Output: $OUTPUT_FILE"

run_mode "$MODE"
echo "CSV written to: $OUTPUT_FILE"
