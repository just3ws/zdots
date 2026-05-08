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

# zdots_svc_launchd_register — Generate and save a launchd plist
# Usage: zdots_svc_launchd_register <label> <plist_path> <binary> <log_path> [args...]
# Environment: ZDOTS_SVC_ENV_KEYS (space-separated list of env var names to include)
zdots_svc_launchd_register() {
  local label="$1" plist_path="$2" binary="$3" log_path="$4"
  shift 4
  local args=("$@")

  _svc_log "registering macOS launchd service: ${label}..."
  mkdir -p "$(dirname "$plist_path")"
  mkdir -p "$(dirname "$log_path")"

  # Build ProgramArguments XML
  local arg_xml=""
  for arg in "${args[@]}"; do
    arg_xml="${arg_xml}        <string>${arg}</string>\n"
  done

  # Build EnvironmentVariables XML
  local env_xml=""
  if [[ -n "${ZDOTS_SVC_ENV_KEYS:-}" ]]; then
    env_xml="    <key>EnvironmentVariables</key>\n    <dict>\n"
    for key in $ZDOTS_SVC_ENV_KEYS; do
      local val="${!key:-}"
      if [[ -n "$val" ]]; then
        env_xml="${env_xml}        <key>${key}</key>\n        <string>${val}</string>\n"
      fi
    done
    env_xml="${env_xml}    </dict>\n"
  fi

  cat <<PLIST > "$plist_path"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${binary}</string>
$(printf "$arg_xml")    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${log_path}</string>
    <key>StandardErrorPath</key>
    <string>${log_path}</string>
$(printf "$env_xml")</dict>
</plist>
PLIST
  _svc_ok "service registered at ${plist_path}"
}

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
