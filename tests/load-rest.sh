#!/usr/bin/env bash
set -euo pipefail

REST_URL="${REST_URL:-http://localhost:8081/rest/meals}"
MODE="${MODE:-baseline}"
METHOD="${METHOD:-GET}"
DATA_FILE="${DATA_FILE:-}"
HEADER_VALUE="${HEADER_VALUE:-}"
TIMEOUT_SEC="${TIMEOUT_SEC:-15}"
BASELINE_REQUESTS="${BASELINE_REQUESTS:-20}"
INCREASING_REQUESTS="${INCREASING_REQUESTS:-50}"
STRESS_REQUESTS="${STRESS_REQUESTS:-100}"
BASELINE_CLIENTS="${BASELINE_CLIENTS:-1}"
INCREASING_CLIENTS="${INCREASING_CLIENTS:-1,5,10,20}"
STRESS_CLIENTS="${STRESS_CLIENTS:-20,40,80}"
CLIENTS_OVERRIDE=""
OUTPUT_FILE="${OUTPUT_FILE:-}"

usage() {
  cat <<'EOF'
Usage: tests/load-rest.sh [options]

REST load test runner with three modes:
  baseline   - single, light run
  increasing - stepped concurrent client runs
  stress     - heavier concurrent runs

Options:
  --url URL              Target REST endpoint (default: $REST_URL)
  --mode MODE            baseline|increasing|stress (default: $MODE)
  --clients LIST         Override clients. Single value or comma list.
  --requests N           Requests per client for the selected mode
  --timeout SEC          Curl timeout in seconds (default: $TIMEOUT_SEC)
  --method METHOD        HTTP method (default: $METHOD)
  --data-file PATH       Optional payload file
  --header VALUE         Optional single HTTP header
  --output PATH          CSV output path (default: tests/results/load-rest-<timestamp>.csv)
  -h, --help             Show this help

Environment overrides:
  REST_URL, MODE, METHOD, DATA_FILE, HEADER_VALUE, TIMEOUT_SEC
  BASELINE_REQUESTS, INCREASING_REQUESTS, STRESS_REQUESTS
  BASELINE_CLIENTS, INCREASING_CLIENTS, STRESS_CLIENTS, OUTPUT_FILE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) REST_URL="$2"; shift 2 ;;
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
    --method) METHOD="$2"; shift 2 ;;
    --data-file) DATA_FILE="$2"; shift 2 ;;
    --header) HEADER_VALUE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

for n in "$TIMEOUT_SEC" "$BASELINE_REQUESTS" "$INCREASING_REQUESTS" "$STRESS_REQUESTS" "$BASELINE_CLIENTS"; do
  if ! [[ "$n" =~ ^[0-9]+$ ]] || [[ "$n" -lt 1 ]]; then
    echo "Numeric configuration values must be positive integers." >&2
    exit 1
  fi
done

if [[ -n "$DATA_FILE" && ! -f "$DATA_FILE" ]]; then
  echo "Payload file not found: $DATA_FILE" >&2
  exit 1
fi

timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
results_dir="tests/results"
mkdir -p "$results_dir"
if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$results_dir/load-rest-$timestamp.csv"
fi

if [[ ! -f "$OUTPUT_FILE" ]]; then
  cat > "$OUTPUT_FILE" <<'EOF'
run_timestamp,mode,scenario,clients,requests_per_client,total_requests,success,errors,duration_ms,throughput_rps,avg_latency_ms,min_latency_ms,p50_latency_ms,p95_latency_ms,max_latency_ms,url,method
EOF
fi

client_request() {
  local out_file="$1"
  local requests="$2"
  local timeout="$3"
  local method="$4"
  local url="$5"
  local data_file="$6"
  local header_value="$7"
  local i result code time_s latency_ms ok

  for ((i=1; i<=requests; i++)); do
    args=(-sS -m "$timeout" -o /dev/null -w "%{time_total},%{http_code}" -X "$method")
    if [[ -n "$header_value" ]]; then
      args+=(-H "$header_value")
    fi
    if [[ -n "$data_file" ]]; then
      args+=(--data-binary "@$data_file")
    fi
    args+=("$url")

    if result="$(curl "${args[@]}" 2>/dev/null)"; then
      time_s="${result%%,*}"
      code="${result##*,}"
    else
      time_s="$timeout"
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
  local run_ts

  if ! [[ "$clients" =~ ^[0-9]+$ ]] || [[ "$clients" -lt 1 ]]; then
    echo "Invalid client count in scenario '$scenario_name': $clients" >&2
    return 1
  fi
  if ! [[ "$requests_per_client" =~ ^[0-9]+$ ]] || [[ "$requests_per_client" -lt 1 ]]; then
    echo "Invalid requests_per_client in scenario '$scenario_name': $requests_per_client" >&2
    return 1
  fi

  echo "Running scenario '$scenario_name': clients=$clients requests_per_client=$requests_per_client"

  local tmp_dir start_ms end_ms duration_ms
  tmp_dir="$(mktemp -d)"
  start_ms="$(date +%s%3N)"

  local client
  for ((client=1; client<=clients; client++)); do
    client_request "$tmp_dir/client-$client.csv" "$requests_per_client" "$TIMEOUT_SEC" "$METHOD" "$REST_URL" "$DATA_FILE" "$HEADER_VALUE" &
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

  local total success errors avg min max p50 p95 throughput
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

  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
    "$run_ts" "$mode" "$scenario_name" "$clients" "$requests_per_client" "$total" "$success" "$errors" \
    "$duration_ms" "$throughput" "$avg" "$min" "$p50" "$p95" "$max" "$REST_URL" "$METHOD" >> "$OUTPUT_FILE"

  echo "Scenario '$scenario_name' done: total=$total success=$success errors=$errors throughput=${throughput}req/s"
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

echo "REST load test"
echo "  URL: $REST_URL"
echo "  Mode: $MODE"
echo "  Method: $METHOD"
echo "  Output: $OUTPUT_FILE"

run_mode "$MODE"
echo "CSV written to: $OUTPUT_FILE"
