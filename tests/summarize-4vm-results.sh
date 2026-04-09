#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_DIR="${INPUT_DIR:-${SCRIPT_DIR}/results}"
OUTPUT_FILE="${OUTPUT_FILE:-${SCRIPT_DIR}/results/4vm-summary.csv}"

usage() {
  cat <<'EOF'
Usage: tests/summarize-4vm-results.sh [options]

Aggregates 4-VM CSV outputs into one summary CSV with client region, service
region, technology, mode, scenario, throughput, latency, and error metrics.

Options:
  --input-dir DIR        Directory containing 4-VM CSV files
  --output PATH          Output summary CSV path
  -h, --help             Show this help

Recognized filename pattern:
  <client>-to-<service>-<tech>-<mode>-r<round>.csv
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input-dir) INPUT_DIR="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

mkdir -p "$(dirname "${OUTPUT_FILE}")"

printf '%s\n' \
  'client_region,service_region,technology,mode,round,scenario,clients,requests_per_client,total_requests,success,errors,duration_ms,throughput_rps,avg_latency_ms,min_latency_ms,p50_latency_ms,p95_latency_ms,max_latency_ms,source_file' \
  > "${OUTPUT_FILE}"

find "${INPUT_DIR}" -maxdepth 1 -type f -name '*.csv' | sort | while read -r file; do
  base="$(basename "${file}")"
  if [[ ! "${base}" =~ ^([a-z0-9-]+)-to-([a-z0-9-]+)-([a-z]+)-([a-z]+)-r([0-9]+)\.csv$ ]]; then
    continue
  fi

  client_region="${BASH_REMATCH[1]}"
  service_region="${BASH_REMATCH[2]}"
  technology="${BASH_REMATCH[3]}"
  mode_from_file="${BASH_REMATCH[4]}"
  round="${BASH_REMATCH[5]}"

  awk -F, \
    -v client_region="${client_region}" \
    -v service_region="${service_region}" \
    -v technology="${technology}" \
    -v mode_from_file="${mode_from_file}" \
    -v round="${round}" \
    -v source_file="${file}" \
    'NR > 1 {
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
        client_region, service_region, technology, mode_from_file, round,
        $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, source_file
    }' "${file}" >> "${OUTPUT_FILE}"
done

echo "Summary CSV written to: ${OUTPUT_FILE}"
