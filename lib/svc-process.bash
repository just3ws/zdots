#!/usr/bin/env bash
# lib/svc-process.bash — PID-based background process lifecycle primitives.
#
# Provides:
#   zdots_svc_pid_start   — launch a background process with nohup
#   zdots_svc_pid_stop    — kill by PID file
#   zdots_svc_pid_status  — echo "running|false <pid>"
#
# Depends on: svc-health.bash (sourced below)
# Sourced by: otel-collector
#
# K8s note: a future lib/svc-k8s.bash will source svc-health.bash directly
# and add kubectl/Colima lifecycle primitives alongside this module.
# Docker Compose functions have no active callers and are intentionally
# omitted — add lib/svc-docker.bash if a caller materialises.

[[ -n "${_SVC_PROCESS_LOADED:-}" ]] && return 0
readonly _SVC_PROCESS_LOADED=1

source "${BASH_SOURCE[0]%/*}/svc-health.bash"

zdots_svc_pid_start() {
  local cmd="$1" log_file="$2" pid_file="$3"
  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    _svc_ok "process already running (PID: $(cat "$pid_file"))"
    return 0
  fi
  _svc_log "starting background process..."
  mkdir -p "$(dirname "$log_file")"
  mkdir -p "$(dirname "$pid_file")"
  nohup bash -c "$cmd" >> "$log_file" 2>&1 &
  echo "$!" > "$pid_file"
}

zdots_svc_pid_stop() {
  local pid_file="$1"
  if [[ -f "$pid_file" ]]; then
    local pid; pid=$(cat "$pid_file")
    _svc_log "stopping process (PID: $pid)..."
    kill "$pid" 2>/dev/null || true
    rm -f "$pid_file"
  fi
}

zdots_svc_pid_status() {
  local pid_file="$1"
  local running=false pid=""
  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    pid=$(cat "$pid_file")
    running=true
  fi
  echo "$running $pid"
}
