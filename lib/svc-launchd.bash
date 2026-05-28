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

# shellcheck source=lib/svc-health.bash
source "${BASH_SOURCE[0]%/*}/svc-health.bash"

_zdots_svc_launchd_domain() {
  printf 'gui/%s' "$(id -u)"
}

_zdots_svc_launchd_target() {
  local label="$1"
  printf '%s/%s' "$(_zdots_svc_launchd_domain)" "$label"
}

_zdots_svc_launchd_validate_plist() {
  local plist="$1"
  if [[ ! -f "$plist" ]]; then
    _svc_warn "launchd plist is missing: ${plist}"
    return 1
  fi

  if command -v plutil >/dev/null 2>&1; then
    if ! plutil -lint "$plist" >/dev/null 2>&1; then
      _svc_warn "launchd plist is invalid: ${plist}"
      plutil -lint "$plist" >&2 || true
      return 1
    fi
  fi

  return 0
}

_zdots_svc_launchd_print_output() {
  local output="$1"
  [[ -n "$output" ]] || return 0
  printf '%s\n' "$output" | sed 's/^/  /' >&2
}

_zdots_svc_launchd_failure() {
  local action="$1" label="$2" plist="$3" status="$4" output="$5"
  local target
  target="$(_zdots_svc_launchd_target "$label")"

  _svc_warn "launchctl ${action} failed status=${status} label=${label}"
  _zdots_svc_launchd_print_output "$output"

  _svc_log "launchd target: ${target}"
  _svc_log "launchd plist: ${plist}"
  ls -l "$plist" >&2 || true

  if command -v plutil >/dev/null 2>&1; then
    plutil -lint "$plist" >&2 || true
  fi

  _svc_log "launchd state snapshot:"
  launchctl print "$target" >&2 || true

  _svc_log "next diagnostic command:"
  printf '  log show --style compact --last 5m --predicate '\''process == "launchd" OR eventMessage CONTAINS "%s"'\''\n' "$label" >&2
}

_zdots_svc_launchd_bootstrap() {
  local label="$1" plist="$2"
  local domain target output status
  domain="$(_zdots_svc_launchd_domain)"
  target="$(_zdots_svc_launchd_target "$label")"

  _zdots_svc_launchd_validate_plist "$plist" || return 1

  if output=$(launchctl bootstrap "$domain" "$plist" 2>&1); then
    return 0
  else
    status=$?
  fi

  if [[ "$status" -eq 5 ]]; then
    _svc_warn "launchctl bootstrap returned status=5; retrying once after bootout"
    _zdots_svc_launchd_print_output "$output"
    launchctl bootout "$target" >/dev/null 2>&1 || true
    if output=$(launchctl bootstrap "$domain" "$plist" 2>&1); then
      _svc_ok "${label} bootstrapped after stale service cleanup"
      return 0
    else
      status=$?
    fi
  fi

  _zdots_svc_launchd_failure "bootstrap" "$label" "$plist" "$status" "$output"
  return "$status"
}

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
$(printf '%b' "$arg_xml")    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${log_path}</string>
    <key>StandardErrorPath</key>
    <string>${log_path}</string>
$(printf '%b' "$env_xml")</dict>
</plist>
PLIST
  _svc_ok "service registered at ${plist_path}"
}

zdots_svc_launchd_start() {
  local label="$1" plist="$2"
  local target
  target="$(_zdots_svc_launchd_target "$label")"

  if launchctl print "$target" >/dev/null 2>&1; then
    local state
    state=$(launchctl print "$target" 2>/dev/null || true)
    if printf '%s\n' "$state" | grep -q 'state = running' &&
       printf '%s\n' "$state" | grep -q 'pid = [0-9]'; then
      _svc_ok "${label} is already running"
    else
      _svc_log "kickstarting ${label}..."
      local output status
      if output=$(launchctl kickstart -k "$target" 2>&1); then
        return 0
      else
        status=$?
      fi
      _svc_warn "launchctl kickstart failed status=${status}; re-bootstrapping ${label}"
      _zdots_svc_launchd_print_output "$output"
      launchctl bootout "$target" >/dev/null 2>&1 || true
      _zdots_svc_launchd_bootstrap "$label" "$plist"
      return $?
    fi
    return 0
  fi
  _svc_log "starting ${label}..."
  _zdots_svc_launchd_bootstrap "$label" "$plist"
}

zdots_svc_launchd_stop() {
  local label="$1"
  _svc_log "stopping ${label}..."
  launchctl bootout "$(_zdots_svc_launchd_target "$label")" 2>/dev/null || true
}

zdots_svc_launchd_status() {
  local label="$1"
  local running=false pid=""
  local state
  if state=$(launchctl print "$(_zdots_svc_launchd_target "$label")" 2>/dev/null); then
    if printf '%s\n' "$state" | grep -q 'state = running'; then
      running=true
      pid=$(printf '%s\n' "$state" | awk -F'= ' '/pid = / {print $2; exit}')
    fi
  fi
  echo "$running $pid"
}
