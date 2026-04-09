#!/usr/bin/env bash
set -euo pipefail

RMI_REGISTRY_PORT="${RMI_REGISTRY_PORT:-1099}"
RMI_SERVICE_PORT="${RMI_SERVICE_PORT:-1100}"

for port in "${RMI_SERVICE_PORT}" "${RMI_REGISTRY_PORT}"; do
  pids="$(
    ss -ltnp | awk -v port=":${port}" '
      index($4, port) {
        while (match($0, /pid=[0-9]+/)) {
          print substr($0, RSTART + 4, RLENGTH - 4)
          $0 = substr($0, RSTART + RLENGTH)
        }
      }
    ' | sort -u
  )"
  if [[ -n "${pids}" ]]; then
    while IFS= read -r pid; do
      [[ -n "${pid}" ]] || continue
      kill "${pid}" >/dev/null 2>&1 || true
    done <<< "${pids}"
  fi
done
