#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

status=0

check_cmd() {
  local cmd="$1"
  local hint="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[OK] $cmd found"
  else
    echo "[FAIL] $cmd not found. $hint"
    status=1
  fi
}

check_java17() {
  if ! command -v java >/dev/null 2>&1; then
    echo "[FAIL] java not found."
    status=1
    return
  fi

  local version_line
  version_line="$(java -version 2>&1 | head -n1)"
  echo "[INFO] java version: $version_line"

  if [[ "$version_line" != *"17."* && "$version_line" != *"\"17\""* ]]; then
    echo "[FAIL] Java 17 is required."
    status=1
  else
    echo "[OK] Java 17 detected"
  fi
}

check_cmd mvn "Install Maven (e.g., sudo apt install maven)."
check_cmd ant "Install Ant for RMI tasks (e.g., sudo apt install ant)."
check_cmd curl "Install curl (e.g., sudo apt install curl)."
check_java17

echo "[INFO] validating required folders"
for d in rest soap rmi deploy/local deploy/azure tests report; do
  if [[ -d "$ROOT_DIR/$d" ]]; then
    echo "[OK] $d exists"
  else
    echo "[FAIL] Missing folder: $d"
    status=1
  fi
done

if [[ "$status" -eq 0 ]]; then
  echo "[PASS] Local prerequisites look good."
else
  echo "[FAIL] Local prerequisites are not ready yet."
fi

exit "$status"
