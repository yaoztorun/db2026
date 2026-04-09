#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

AZURE_HOST="${AZURE_HOST:?Set AZURE_HOST (remote DNS/IP)}"
AZURE_USER="${AZURE_USER:?Set AZURE_USER (remote SSH user)}"
AZURE_SSH_PORT="${AZURE_SSH_PORT:-22}"
AZURE_REMOTE_DIR="${AZURE_REMOTE_DIR:-$HOME/dsgt}"
AZURE_SSH_KEY_PATH="${AZURE_SSH_KEY_PATH:-}"
MONITOR_PORT="${MONITOR_PORT:-}"
MONITOR_LABEL="${MONITOR_LABEL:-}"
MONITOR_INTERVAL_SEC="${MONITOR_INTERVAL_SEC:-1}"

usage() {
  cat <<'EOF'
Usage: deploy/azure/start-monitor.sh [options]

Starts lightweight CPU/memory sampling on the remote VM for the process
listening on the selected port. Output is written to a CSV on the VM.

Options:
  --port PORT         Service port to monitor
  --label LABEL       Friendly label for the CSV filename
  --interval SEC      Sampling interval in seconds (default: 1)
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) MONITOR_PORT="$2"; shift 2 ;;
    --label) MONITOR_LABEL="$2"; shift 2 ;;
    --interval) MONITOR_INTERVAL_SEC="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${MONITOR_PORT}" ]]; then
  echo "Set MONITOR_PORT or pass --port." >&2
  exit 1
fi
if [[ -z "${MONITOR_LABEL}" ]]; then
  MONITOR_LABEL="port-${MONITOR_PORT}"
fi
if ! [[ "${MONITOR_INTERVAL_SEC}" =~ ^[0-9]+$ ]] || [[ "${MONITOR_INTERVAL_SEC}" -lt 1 ]]; then
  echo "MONITOR_INTERVAL_SEC must be a positive integer." >&2
  exit 1
fi

SSH_OPTS=(-p "${AZURE_SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
if [[ -n "${AZURE_SSH_KEY_PATH}" ]]; then
  SSH_OPTS+=(-i "${AZURE_SSH_KEY_PATH}")
fi

REMOTE="${AZURE_USER}@${AZURE_HOST}"
STAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
REMOTE_MONITOR_DIR="${AZURE_REMOTE_DIR}/monitor"
REMOTE_CSV="${REMOTE_MONITOR_DIR}/${MONITOR_LABEL}-${STAMP}.csv"
REMOTE_PID_FILE="${REMOTE_MONITOR_DIR}/${MONITOR_LABEL}.pid"
REMOTE_CURRENT_FILE="${REMOTE_MONITOR_DIR}/${MONITOR_LABEL}.current"
REMOTE_SCRIPT_FILE="${REMOTE_MONITOR_DIR}/${MONITOR_LABEL}-monitor.sh"

ssh "${SSH_OPTS[@]}" "${REMOTE}" "mkdir -p '${REMOTE_MONITOR_DIR}'"

ssh "${SSH_OPTS[@]}" "${REMOTE}" "
  set -euo pipefail
  if [[ -f '${REMOTE_PID_FILE}' ]]; then
    old_pid=\$(cat '${REMOTE_PID_FILE}' 2>/dev/null || true)
    if [[ -n \"\${old_pid}\" ]] && kill -0 \"\${old_pid}\" >/dev/null 2>&1; then
      kill \"\${old_pid}\" >/dev/null 2>&1 || true
    fi
  fi
  cat > '${REMOTE_CSV}' <<'EOF'
timestamp_utc,port,pid,cpu_pct,mem_pct,rss_kb,vsz_kb,etimes_sec,threads,state,cmd
EOF
  cat > '${REMOTE_SCRIPT_FILE}' <<'EOF'
#!/usr/bin/env bash
set -u

read_total_jiffies() {
  awk '/^cpu / {sum=0; for (i=2; i<=NF; i++) sum+=\$i; print sum; exit }' /proc/stat
}

read_proc_jiffies() {
  local target_pid="\$1"
  awk '{print \$14 + \$15}' "/proc/\${target_pid}/stat" 2>/dev/null
}

last_pid=""
last_total=""
last_proc=""

while true; do
  ts=\$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")
  pid=\$(ss -ltnp | awk 'index(\$4, \":${MONITOR_PORT}\") { if (match(\$0, /pid=[0-9]+/)) { print substr(\$0, RSTART+4, RLENGTH-4); exit } }')
  if [[ -n \"\${pid}\" ]]; then
    line=\$(ps -p \"\${pid}\" -o %cpu=,%mem=,rss=,vsz=,etimes=,nlwp=,state=,args= | sed -e 's/^[[:space:]]*//')
    if [[ -n \"\${line}\" ]]; then
      mem=\$(printf '%s\n' \"\${line}\" | awk '{print \$2}')
      rss=\$(printf '%s\n' \"\${line}\" | awk '{print \$3}')
      vsz=\$(printf '%s\n' \"\${line}\" | awk '{print \$4}')
      etimes=\$(printf '%s\n' \"\${line}\" | awk '{print \$5}')
      threads=\$(printf '%s\n' \"\${line}\" | awk '{print \$6}')
      state=\$(printf '%s\n' \"\${line}\" | awk '{print \$7}')
      cmd=\$(printf '%s\n' \"\${line}\" | cut -d' ' -f8- | sed 's/\"/\"\"/g')
      total_now=\$(read_total_jiffies)
      proc_now=\$(read_proc_jiffies \"\${pid}\" || true)
      cpu=\"\"
      if [[ -n \"\${proc_now}\" ]]; then
        if [[ \"\${pid}\" == \"\${last_pid}\" ]] && [[ -n \"\${last_total}\" ]] && [[ -n \"\${last_proc}\" ]]; then
          total_delta=\$((total_now - last_total))
          proc_delta=\$((proc_now - last_proc))
          if (( total_delta > 0 && proc_delta >= 0 )); then
            cpu=\$(awk -v p=\"\${proc_delta}\" -v t=\"\${total_delta}\" 'BEGIN { printf \"%.2f\", (p / t) * 100 }')
          else
            cpu=\"0.00\"
          fi
        else
          cpu=\"0.00\"
        fi
        last_pid=\"\${pid}\"
        last_total=\"\${total_now}\"
        last_proc=\"\${proc_now}\"
      else
        cpu=\"\"
        last_pid=\"\"
        last_total=\"\"
        last_proc=\"\"
      fi
      printf '%s,${MONITOR_PORT},%s,%s,%s,%s,%s,%s,%s,%s,\"%s\"\n' \
        \"\${ts}\" \"\${pid}\" \"\${cpu}\" \"\${mem}\" \"\${rss}\" \"\${vsz}\" \"\${etimes}\" \"\${threads}\" \"\${state}\" \"\${cmd}\"
    else
      printf '%s,${MONITOR_PORT},,,,,,,,,\n' \"\${ts}\"
      last_pid=\"\"
      last_total=\"\"
      last_proc=\"\"
    fi
  else
    printf '%s,${MONITOR_PORT},,,,,,,,,\n' \"\${ts}\"
    last_pid=\"\"
    last_total=\"\"
    last_proc=\"\"
  fi
  sleep '${MONITOR_INTERVAL_SEC}'
done
EOF
  chmod +x '${REMOTE_SCRIPT_FILE}'
  nohup '${REMOTE_SCRIPT_FILE}' >> '${REMOTE_CSV}' 2>/dev/null < /dev/null &
  monitor_pid=\$!
  printf '%s\n' \"\${monitor_pid}\" > '${REMOTE_PID_FILE}'
  printf '%s\n' '${REMOTE_CSV}' > '${REMOTE_CURRENT_FILE}'
"

echo "Remote monitor started for ${MONITOR_LABEL} on ${REMOTE}:${MONITOR_PORT}"
echo "  Remote CSV: ${REMOTE_CSV}"
