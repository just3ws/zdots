#!/usr/bin/env bash
# lib/svc-registry.bash — the single source of truth for the Platform Service
# catalog and its health/state probes.
#
# Before this module, the service catalog (labels, logs, endpoints) and the
# health probes (curl /health, redis-cli ping, colima status, …) were defined
# twice — once in bin/zsvc (_svc_meta / _svc_health_text / _svc_state_pid) and
# again in bin/zdots-ctl (_ai_up / _embed_up / _otel_up / …). This module holds
# one descriptor per service and one probe per concern; both scripts derive
# from it.
#
# Public interface:
#   zdots_svc_resolve <alias>   → echo canonical name; exit 1 if unknown
#   zdots_svc_managed           → echo the zsvc-controllable services, in order
#   zdots_svc_state   <svc>     → echo "state\tpid" (launchd/colima/nginx)
#   zdots_svc_healthy <svc>     → exit 0 if the service's liveness probe passes
#
# Descriptor accessors (all return empty string if service unknown):
#   zdots_svc_display <svc>     → human-readable name
#   zdots_svc_label <svc>       → launchd service label
#   zdots_svc_log <svc>         → log file path
#   zdots_svc_ctl <svc>         → control script (bin/ basename or command name)
#   zdots_svc_endpoint <svc>    → health check endpoint URL
#   zdots_svc_type <svc>        → service type (launchd|plist|nginx|colima|derived)
#   zdots_svc_install <svc>     → install ctl command
#   zdots_svc_start <svc>       → start ctl command
#   zdots_svc_stop <svc>        → stop ctl command
#   zdots_svc_restart <svc>     → restart ctl command
#   zdots_svc_status <svc>      → status ctl command
#   zdots_svc_health <svc>      → liveness probe (function, not string)
#   zdots_svc_logs <svc>        → logs ctl command
#   zdots_svc_validate <svc>    → validate ctl command
#
# Per-service descriptor (associative arrays keyed by canonical name):
#   ZDOTS_SVC_DISPLAY / _LABEL / _LOG / _CTL / _ENDPOINT / _TYPE
#   ZDOTS_SVC_INSTALL / _START / _STOP / _RESTART / _STATUS / _HEALTH / _LOGS / _VALIDATE
#   ZDOTS_SVC_MANAGED (1 = zsvc lifecycle-controllable)
#
# TYPE drives state probing: launchd | plist (user LaunchAgent) | nginx (system
# LaunchDaemon) | colima | derived (no launchd object — health-only).

# The descriptor arrays below are this module's public interface — populated
# here and read by the sourcing scripts (bin/zsvc, bin/zdots-ctl); shellcheck
# can't see their external use when analysing this file in isolation.
# shellcheck disable=SC2034
[[ -n "${_SVC_REGISTRY_LOADED:-}" ]] && return 0
readonly _SVC_REGISTRY_LOADED=1

_SVC_REG_ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
ZDOTS_SVC_BIN="${_SVC_REG_ZDOTDIR}/bin"
_SVC_REG_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
_SVC_REG_BREW="$(brew --prefix 2>/dev/null || printf '/opt/homebrew')"

declare -ag ZDOTS_SVC_ALL=()
declare -Ag ZDOTS_SVC_ALIAS=()
declare -Ag ZDOTS_SVC_DISPLAY=()  ZDOTS_SVC_LABEL=()    ZDOTS_SVC_LOG=()
declare -Ag ZDOTS_SVC_CTL=()      ZDOTS_SVC_ENDPOINT=() ZDOTS_SVC_TYPE=()
declare -Ag ZDOTS_SVC_MANAGED=()
declare -Ag ZDOTS_SVC_INSTALL=()  ZDOTS_SVC_START=()    ZDOTS_SVC_STOP=()
declare -Ag ZDOTS_SVC_RESTART=()  ZDOTS_SVC_STATUS=()   ZDOTS_SVC_HEALTH=()
declare -Ag ZDOTS_SVC_LOGS=()     ZDOTS_SVC_VALIDATE=()
declare -Ag ZDOTS_SVC_PROBE_FN=()  # Function name for health probe dispatch
declare -Ag _ZDOTS_PROBE_DISPATCH=()  # Built at load time: maps service → probe function

# _svc_reg "name|display|label|log|ctl|endpoint|type|managed|aliases|install|start|stop|restart|status|health|logs|validate|probe_fn"
# Empty fields are allowed (||). ctl is a bin/ basename or empty. aliases is a
# space-separated list within its field. probe_fn is the function name that will
# be called to check service health (e.g., "zdots_probe_llama").
_svc_reg() {
  local name display label log ctl endpoint type managed aliases \
        install start stop restart status health logs validate probe_fn a
  IFS='|' read -r name display label log ctl endpoint type managed aliases \
        install start stop restart status health logs validate probe_fn <<< "$1"

  ZDOTS_SVC_ALL+=("$name")
  ZDOTS_SVC_DISPLAY[$name]="$display"
  ZDOTS_SVC_LABEL[$name]="$label"
  ZDOTS_SVC_LOG[$name]="$log"
  ZDOTS_SVC_CTL[$name]="$ctl"
  ZDOTS_SVC_ENDPOINT[$name]="$endpoint"
  ZDOTS_SVC_TYPE[$name]="$type"
  ZDOTS_SVC_MANAGED[$name]="$managed"
  ZDOTS_SVC_INSTALL[$name]="$install"
  ZDOTS_SVC_START[$name]="$start"
  ZDOTS_SVC_STOP[$name]="$stop"
  ZDOTS_SVC_RESTART[$name]="$restart"
  ZDOTS_SVC_STATUS[$name]="$status"
  ZDOTS_SVC_HEALTH[$name]="$health"
  ZDOTS_SVC_LOGS[$name]="$logs"
  ZDOTS_SVC_VALIDATE[$name]="$validate"
  ZDOTS_SVC_PROBE_FN[$name]="$probe_fn"

  ZDOTS_SVC_ALIAS[$name]="$name"
  for a in $aliases; do ZDOTS_SVC_ALIAS[$a]="$name"; done
}

# ── The catalog ─────────────────────────────────────────────────────────────
# Endpoints resolve from the same env vars both consumers already honour.
# Fields: name|display|label|log|ctl|endpoint|type|managed|aliases|install|start|stop|restart|status|health|logs|validate|probe_fn
_svc_reg "llama|llama-server|com.zdots.llama-server|${_SVC_REG_STATE}/llama-server.log|llama-ctl|${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:11500}|launchd|1|llama-server ai server|install|start|stop|restart|status|health|logs|validate|zdots_probe_llama"
_svc_reg "embed|llama-embed|com.zdots.llama-embed|${_SVC_REG_STATE}/llama-embed.log|llama-ctl|${ZDOTS_AI_EMBED_ENDPOINT:-http://127.0.0.1:11501}|launchd|1|llama-embed embedding|install-embed|start-embed|stop-embed||status-embed||||zdots_probe_embed"
_svc_reg "otel|otel-collector|com.zdots.otel-collector|${_SVC_REG_STATE}/otel-collector.log|otel-collector|http://127.0.0.1:4318|launchd|1|otel-collector telemetry collector|install|start|stop|restart|status|health|logs|validate|zdots_probe_otel"
_svc_reg "o2|openobserve|com.zdots.openobserve|${_SVC_REG_STATE}/openobserve.log|openobserve-ctl|http://127.0.0.1:5080|launchd|1|openobserve observability obs telemetry-ui|install|start|stop|restart|status|health|logs||zdots_probe_o2"
_svc_reg "colima|colima|com.zdots.colima-autostart||colima||colima|1|vm docker||start|stop||status||logs||zdots_probe_colima"
_svc_reg "nginx|nginx|homebrew.mxcl.nginx|${_SVC_REG_BREW}/var/log/nginx/error.log|nginx-ctl|https://my.local (+ llama/embed/o2.local)|nginx|1|web proxy||start|stop|restart|status|health|logs|validate|zdots_probe_nginx"
_svc_reg "postgres|postgresql@18|homebrew.mxcl.postgresql@18|${_SVC_REG_BREW}/var/log/postgresql@18.log||postgresql:///my (:5432)|plist|1|postgresql pg db database||start|stop|restart|status|health|||zdots_probe_postgres"
_svc_reg "redis|redis|homebrew.mxcl.redis|${_SVC_REG_BREW}/var/log/redis.log||127.0.0.1:6379|plist|1|cache kv||start|stop|restart|status|health|||zdots_probe_redis"
_svc_reg "worker|zdots-worker|com.zdots.worker|${_SVC_REG_STATE}/zdots-worker.log|zdots-worker|jobs queue (my)|launchd|1|jobs brain-worker|install|start|stop|restart|status|health|logs||zdots_probe_worker"
# Health-only platform services (not zsvc lifecycle-managed):
_svc_reg "ctx|context-engine|||zdots-ctx|postgres|derived|0|intelligence|||||||||zdots_probe_ctx"

# ── Lookups ─────────────────────────────────────────────────────────────────

# Resolve an alias (or canonical name) to its canonical name.
zdots_svc_resolve() {
  local key="${ZDOTS_SVC_ALIAS[$1]:-}"
  [[ -n "$key" ]] || return 1
  printf '%s' "$key"
}

# The zsvc-controllable services, in registration order.
zdots_svc_managed() {
  local s
  for s in "${ZDOTS_SVC_ALL[@]}"; do
    [[ "${ZDOTS_SVC_MANAGED[$s]}" == "1" ]] && printf '%s\n' "$s"
  done
  return 0
}

# ── State probe (single source) ─────────────────────────────────────────────

# echo "state\tpid" for a launchd target. state is the launchctl state word
# (e.g. running) or not-registered; pid is the numeric pid or '-'.
_zdots_svc_launchd_state() {
  local target="$1" out state pid
  if out=$(launchctl print "$target" 2>/dev/null); then
    state=$(printf '%s\n' "$out" | awk '/[[:space:]]state = / {print $NF; exit}')
    pid=$(printf '%s\n'   "$out" | awk '/[[:space:]]pid = /   {print $NF; exit}')
    printf '%s\t%s' "${state:-unknown}" "${pid:--}"
  else
    printf 'not-registered\t-'
  fi
}

zdots_svc_state() {
  local name; name="$(zdots_svc_resolve "$1")" || { printf 'unknown\t-'; return; }
  local type="${ZDOTS_SVC_TYPE[$name]}" label="${ZDOTS_SVC_LABEL[$name]}"
  case "$type" in
    colima)  colima status >/dev/null 2>&1 && printf 'running\t-' || printf 'stopped\t-' ;;
    nginx)   _zdots_svc_launchd_state "system/${label}" ;;
    derived) printf 'n/a\t-' ;;
    *)       _zdots_svc_launchd_state "gui/$(id -u)/${label}" ;;
  esac
}

# ── Health probe functions (registerable) ──────────────────────────────────
# Each probe returns 0 (healthy) or 1 (unhealthy).

zdots_probe_llama() {
  curl -sf --max-time 3 "${ZDOTS_SVC_ENDPOINT[llama]}/health" >/dev/null 2>&1
}

zdots_probe_embed() {
  curl -sf --max-time 3 "${ZDOTS_SVC_ENDPOINT[embed]}/health" >/dev/null 2>&1
}

zdots_probe_otel() {
  "${ZDOTS_SVC_BIN}/otel-collector" health >/dev/null 2>&1
}

zdots_probe_o2() {
  curl -sf --max-time 3 "${ZDOTS_SVC_ENDPOINT[o2]}/healthz" >/dev/null 2>&1
}

zdots_probe_colima() {
  colima status >/dev/null 2>&1
}

zdots_probe_nginx() {
  curl -s --max-time 3 -o /dev/null "http://localhost/" 2>/dev/null
}

zdots_probe_postgres() {
  command -v pg_isready >/dev/null 2>&1 && pg_isready -q 2>/dev/null
}

zdots_probe_redis() {
  [[ "$(redis-cli -h "${ZDOTS_REDIS_HOST:-127.0.0.1}" -p "${ZDOTS_REDIS_PORT:-6379}" ping 2>/dev/null)" == "PONG" ]]
}

zdots_probe_worker() {
  "${ZDOTS_SVC_BIN}/zdots-worker" health >/dev/null 2>&1
}

zdots_probe_ctx() {
  "${ZDOTS_SVC_BIN}/zdots-ctx" status >/dev/null 2>&1
}

# ── Probe dispatch (built at load time) ─────────────────────────────────────

# Build the dispatch table at load time: service name → probe function.
# Validates that all probes exist; fails hard if a probe is missing.
_build_probe_dispatch() {
  local svc probe_fn
  for svc in "${ZDOTS_SVC_ALL[@]}"; do
    probe_fn="${ZDOTS_SVC_PROBE_FN[$svc]}"
    if [[ -z "$probe_fn" ]]; then
      printf 'svc-registry: ERROR: service %s has no probe_fn registered\n' "$svc" >&2
      return 1
    fi
    # Verify the probe function exists
    if ! declare -f "$probe_fn" >/dev/null 2>&1; then
      printf 'svc-registry: ERROR: probe function %s for service %s does not exist\n' "$probe_fn" "$svc" >&2
      return 1
    fi
    _ZDOTS_PROBE_DISPATCH[$svc]="$probe_fn"
  done
  return 0
}

# ── Health probe (single source) ────────────────────────────────────────────

# Exit 0 if the service's liveness probe passes. Dispatches to the registered
# probe function for the service (built at load time). One definition per
# service, consumed by both zsvc (_svc_health_text) and zdots-ctl (_*_up).
zdots_svc_healthy() {
  local name; name="$(zdots_svc_resolve "$1")" || return 2
  local probe_fn="${_ZDOTS_PROBE_DISPATCH[$name]:-}"
  if [[ -z "$probe_fn" ]]; then
    return 2
  fi
  # Call the registered probe function
  "$probe_fn"
}

# ── Descriptor accessors (avoid direct array access) ──────────────────────────

# All accessors return empty string if service not found (caller should check).

zdots_svc_display() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_DISPLAY[$name]:-}"
}

zdots_svc_label() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_LABEL[$name]:-}"
}

zdots_svc_log() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_LOG[$name]:-}"
}

zdots_svc_ctl() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_CTL[$name]:-}"
}

zdots_svc_endpoint() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_ENDPOINT[$name]:-}"
}

zdots_svc_type() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_TYPE[$name]:-}"
}

zdots_svc_install() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_INSTALL[$name]:-}"
}

zdots_svc_start() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_START[$name]:-}"
}

zdots_svc_stop() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_STOP[$name]:-}"
}

zdots_svc_restart() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_RESTART[$name]:-}"
}

zdots_svc_status() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_STATUS[$name]:-}"
}

zdots_svc_logs() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_LOGS[$name]:-}"
}

zdots_svc_validate() {
  local name; name="$(zdots_svc_resolve "$1")" || return 0
  printf '%s' "${ZDOTS_SVC_VALIDATE[$name]:-}"
}

# ── Initialization ──────────────────────────────────────────────────────────
# Build the probe dispatch table at load time. Fails hard if any probe is missing.
if ! _build_probe_dispatch; then
  printf 'svc-registry: FATAL: probe dispatch table build failed\n' >&2
  exit 1
fi
