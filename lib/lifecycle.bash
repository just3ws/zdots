#!/usr/bin/env bash
# lib/lifecycle.bash — Unified Service Lifecycle Engine
#
# RATIONALE:
# Consolidates the logic for managing service lifecycles (start, stop, status, health)
# across different backends (launchd, Docker Compose, background processes).
#
# USAGE:
# Services should define their metadata and delegate to these primitives.

set -euo pipefail

# Internal helpers
_svc_log()  { printf '%s: %s\n' "${SVC_NAME:-platform}" "$*" >&2; }
_svc_ok()   { printf '%s: [ok]  %s\n' "${SVC_NAME:-platform}" "$*" >&2; }
_svc_warn() { printf '%s: [!!]  %s\n' "${SVC_NAME:-platform}" "$*" >&2; }
_svc_die()  { printf '%s: [err] %s\n' "${SVC_NAME:-platform}" "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# launchd (macOS)
# ---------------------------------------------------------------------------

zdots_svc_launchd_start() {
  local label="$1" plist="$2"
  if launchctl print "gui/$(id -u)/${label}" >/dev/null 2>&1; then
    _svc_ok "${label} is already running"
    return 0
  fi
  _svc_log "starting ${label}..."
  launchctl bootstrap "gui/$(id -u)" "$plist"
}

zdots_svc_launchd_stop() {
  local label="$1"
  _svc_log "stopping ${label}..."
  launchctl bootout "gui/$(id -u)/${label}" 2>/dev/null || true
}

zdots_svc_launchd_status() {
  local label="$1"
  local running=false pid=""
  if launchctl list "$label" >/dev/null 2>&1; then
    pid=$(launchctl list "$label" 2>/dev/null | grep '"PID"' | awk '{print $3}' | tr -d ';' || true)
    [[ -n "$pid" ]] && running=true
  fi
  echo "$running $pid"
}

# ---------------------------------------------------------------------------
# Docker Compose
# ---------------------------------------------------------------------------

zdots_svc_docker_start() {
  local compose_file="$1"
  _svc_log "starting container stack..."
  docker compose -f "$compose_file" up -d
}

zdots_svc_docker_stop() {
  local compose_file="$1"
  _svc_log "stopping container stack..."
  docker compose -f "$compose_file" down 2>/dev/null || true
}

zdots_svc_docker_status() {
  local compose_file="$1"
  docker compose -f "$compose_file" ps --format json 2>/dev/null || echo "[]"
}

# ---------------------------------------------------------------------------
# PID-based (Background Process / Linux / CI)
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Health & Waiting
# ---------------------------------------------------------------------------

zdots_svc_wait_for_url() {
  local label="$1" url="$2" timeout="${3:-30}"
  local elapsed=0
  _svc_log "waiting for ${label} at ${url}..."
  while ! curl -sf -m 2 "$url" >/dev/null 2>&1; do
    if [[ $elapsed -ge $timeout ]]; then
      _svc_die "timed out after ${timeout}s waiting for ${label}"
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  _svc_ok "${label} is ready"
}

zdots_svc_health_check_url() {
  local url="$1"
  local method="${2:-GET}"
  local payload="${3:-}"
  if [[ "$method" == "POST" ]]; then
    curl -sf -m 2 -X POST "$url" -H "Content-Type: application/json" -d "$payload" >/dev/null 2>&1
  else
    curl -sf -m 2 "$url" >/dev/null 2>&1
  fi
}

# ---------------------------------------------------------------------------
# Orchestration Primitives
# ---------------------------------------------------------------------------

zdots_svc_restart() {
  local stop_cmd="$1" start_cmd="$2"
  eval "$stop_cmd"
  sleep 1
  eval "$start_cmd"
}
