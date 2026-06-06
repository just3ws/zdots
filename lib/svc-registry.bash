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

# _svc_reg "name|display|label|log|ctl|endpoint|type|managed|aliases|install|start|stop|restart|status|health|logs|validate"
# Empty fields are allowed (||). ctl is a bin/ basename or empty. aliases is a
# space-separated list within its field.
_svc_reg() {
  local name display label log ctl endpoint type managed aliases \
        install start stop restart status health logs validate a
  IFS='|' read -r name display label log ctl endpoint type managed aliases \
        install start stop restart status health logs validate <<< "$1"

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

  ZDOTS_SVC_ALIAS[$name]="$name"
  for a in $aliases; do ZDOTS_SVC_ALIAS[$a]="$name"; done
}

# ── The catalog ─────────────────────────────────────────────────────────────
# Endpoints resolve from the same env vars both consumers already honour.
_svc_reg "llama|llama-server|com.zdots.llama-server|${_SVC_REG_STATE}/llama-server.log|llama-ctl|${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:11500}|launchd|1|llama-server ai server|install|start|stop|restart|status|health|logs|validate"
_svc_reg "embed|llama-embed|com.zdots.llama-embed|${_SVC_REG_STATE}/llama-embed.log|llama-ctl|${ZDOTS_AI_EMBED_ENDPOINT:-http://127.0.0.1:11501}|launchd|1|llama-embed embedding|install-embed|start-embed|stop-embed||status-embed|||"
_svc_reg "otel|otel-collector|com.zdots.otel-collector|${_SVC_REG_STATE}/otel-collector.log|otel-collector|http://127.0.0.1:4318|launchd|1|otel-collector telemetry collector|install|start|stop|restart|status|health|logs|validate"
_svc_reg "o2|openobserve|com.zdots.openobserve|${_SVC_REG_STATE}/openobserve.log|openobserve-ctl|http://127.0.0.1:5080|launchd|1|openobserve observability obs telemetry-ui|install|start|stop|restart|status|health|logs|"
_svc_reg "colima|colima|com.zdots.colima-autostart||colima||colima|1|vm docker||start|stop||status||logs|"
_svc_reg "nginx|nginx|homebrew.mxcl.nginx|${_SVC_REG_BREW}/var/log/nginx/error.log|nginx-ctl|https://my.local (+ llama/embed/o2.local)|nginx|1|web proxy||start|stop|restart|status|health|logs|validate"
_svc_reg "postgres|postgresql@18|homebrew.mxcl.postgresql@18|${_SVC_REG_BREW}/var/log/postgresql@18.log||postgresql:///my (:5432)|plist|1|postgresql pg db database||start|stop|restart|status|health||"
_svc_reg "redis|redis|homebrew.mxcl.redis|${_SVC_REG_BREW}/var/log/redis.log||127.0.0.1:6379|plist|1|cache kv||start|stop|restart|status|health||"
_svc_reg "worker|zdots-worker|com.zdots.worker|${_SVC_REG_STATE}/zdots-worker.log|zdots-worker|jobs queue (my)|launchd|1|jobs brain-worker|install|start|stop|restart|status|health|logs|"
# Health-only platform services (not zsvc lifecycle-managed):
_svc_reg "ctx|context-engine|||zdots-ctx|postgres|derived|0|intelligence||||||||"

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

# ── Health probe (single source) ────────────────────────────────────────────

# Exit 0 if the service's liveness probe passes. One definition per service,
# consumed by both zsvc (_svc_health_text) and zdots-ctl (_*_up).
zdots_svc_healthy() {
  local name; name="$(zdots_svc_resolve "$1")" || return 2
  local ep="${ZDOTS_SVC_ENDPOINT[$name]}"
  case "$name" in
    llama|embed) curl -sf --max-time 3 "${ep}/health" >/dev/null 2>&1 ;;
    otel)        "${ZDOTS_SVC_BIN}/otel-collector" health >/dev/null 2>&1 ;;
    o2)          curl -sf --max-time 3 "${ep}/healthz" >/dev/null 2>&1 ;;
    colima)      colima status >/dev/null 2>&1 ;;
    nginx)       curl -s --max-time 3 -o /dev/null "http://localhost/" 2>/dev/null ;;
    postgres)    command -v pg_isready >/dev/null 2>&1 && pg_isready -q 2>/dev/null ;;
    redis)       [[ "$(redis-cli -h "${ZDOTS_REDIS_HOST:-127.0.0.1}" -p "${ZDOTS_REDIS_PORT:-6379}" ping 2>/dev/null)" == "PONG" ]] ;;
    worker)      "${ZDOTS_SVC_BIN}/zdots-worker" health >/dev/null 2>&1 ;;
    ctx)         "${ZDOTS_SVC_BIN}/zdots-ctx" status >/dev/null 2>&1 ;;
    *)           return 2 ;;
  esac
}
