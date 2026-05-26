#!/usr/bin/env bash
# lib/svc-launchd.bash — macOS launchd service lifecycle primitives.
#
# Provides:
#   zdots_svc_launchd_register  — write a launchd plist
#   zdots_svc_launchd_start     — bootstrap or kickstart a service
#   zdots_svc_launchd_stop      — bootout a service
#   zdots_svc_launchd_status    — echo "running|false <pid>"
#
# Depends on: svc-health.bash (sourced below)
# Sourced by: llama-ctl, otel-collector
#
# K8s note: kubectl/Colima lifecycle primitives belong in a future
# lib/svc-k8s.bash — do not add them here.

[[ -n "${_SVC_LAUNCHD_LOADED:-}" ]] && return 0
readonly _SVC_LAUNCHD_LOADED=1

source "${BASH_SOURCE[0]%/*}/svc-health.bash"

# ---------------------------------------------------------------------------
# zdots_svc_launchd_register <label> <plist_path> <binary> <log_path> [args...]
# Environment: ZDOTS_SVC_ENV_KEYS — space-separated list of env var names to
#   embed in the plist EnvironmentVariables dict.
# ---------------------------------------------------------------------------
zdots_svc_launchd_register() {
  local label="$1" plist_path="$2" binary="$3" log_path="$4"
  shift 4
  local args=("$@")

  _svc_log "registering macOS launchd service: ${label}..."
  mkdir -p "$(dirname "$plist_path")"
  mkdir -p "$(dirname "$log_path")"

  local arg_xml=""
  for arg in "${args[@]}"; do
    arg_xml="${arg_xml}        <string>${arg}</string>\n"
  done

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
    local state
    state=$(launchctl print "gui/$(id -u)/${label}" 2>/dev/null || true)
    if printf '%s\n' "$state" | grep -q 'state = running' &&
       printf '%s\n' "$state" | grep -q 'pid = [0-9]'; then
      _svc_ok "${label} is already running"
    else
      _svc_log "kickstarting ${label}..."
      launchctl kickstart -k "gui/$(id -u)/${label}"
    fi
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
  local state
  if state=$(launchctl print "gui/$(id -u)/${label}" 2>/dev/null); then
    if printf '%s\n' "$state" | grep -q 'state = running'; then
      running=true
      pid=$(printf '%s\n' "$state" | awk -F'= ' '/pid = / {print $2; exit}')
    fi
  fi
  echo "$running $pid"
}
