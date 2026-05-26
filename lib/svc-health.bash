#!/usr/bin/env bash
# lib/svc-health.bash — Shared service health, observability, and output helpers.
#
# Provides:
#   _svc_{log,ok,warn,die}         — internal logging helpers (stderr, respect SVC_NAME)
#   zdots_svc_wait_for_url         — poll URL until healthy or timeout
#   zdots_svc_loopback_listening   — test whether a loopback port is open (ss/lsof/netstat)
#   zdots_svc_health_check_url     — HTTP health check with loopback fallback
#   zdots_svc_restart              — stop + sleep 1 + start orchestration helper
#   zdots_svc_emit_span            — emit OTLP trace span to local collector
#   zdots_svc_new_span_id          — generate a random 16-char hex span ID
#   zdots_svc_logs                 — tail -f a log file
#   zdots_svc_print_status         — standardised status output (text or JSON)
#   zdots_svc_print_health         — standardised health output (text or JSON)
#
# Sourced by: svc-launchd.bash, svc-process.bash, and any tool that needs only
# health/observability without a backend (zdots-ctl, zdots-ctx, gemini-invoke).
#
# K8s note: a future lib/svc-k8s.bash will source this file for the shared
# helpers while adding kubectl/Colima-specific lifecycle primitives.

[[ -n "${_SVC_HEALTH_LOADED:-}" ]] && return 0
readonly _SVC_HEALTH_LOADED=1

# ---------------------------------------------------------------------------
# Internal logging helpers (respect the caller's SVC_NAME context variable)
# ---------------------------------------------------------------------------
_svc_log()  { printf '%s: %s\n'       "${SVC_NAME:-platform}" "$*" >&2; }
_svc_ok()   { printf '%s: [ok]  %s\n' "${SVC_NAME:-platform}" "$*" >&2; }
_svc_warn() { printf '%s: [!!]  %s\n' "${SVC_NAME:-platform}" "$*" >&2; }
_svc_die()  { printf '%s: [err] %s\n' "${SVC_NAME:-platform}" "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Health & waiting
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

# zdots_svc_loopback_listening URL
# Returns 0 if a process is actively listening on the loopback port of URL.
# Only meaningful for loopback addresses — returns 1 immediately for anything else.
#
# Tool detection (jQuery-style: use the best available, fall through):
#   ss    — preferred on Linux (iproute2); absent on macOS
#   lsof  — BSD (macOS) and GNU; -F n emits structured n<addr> lines,
#            avoiding the fragile column-index approach that breaks on wide FD values
#   netstat — universal last resort; macOS uses dot-separated port (127.0.0.1.8080),
#             Linux uses colon-separated (127.0.0.1:8080) — [.:] handles both
zdots_svc_loopback_listening() {
  local host_port="${1#*://}"
  host_port="${host_port%%/*}"
  local host="${host_port%%:*}"
  local port="${host_port##*:}"

  [[ "$host" == "127.0.0.1" || "$host" == "localhost" || "$host" == "::1" ]] || return 1
  [[ "$port" =~ ^[0-9]+$ ]] || return 1

  if command -v ss >/dev/null 2>&1; then
    ss -tln 2>/dev/null \
      | awk '{print $4}' \
      | grep -qE "^(127\.0\.0\.1|\[::1\]|::1):${port}$"
    return
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -i "TCP:${port}" -sTCP:LISTEN -F n 2>/dev/null \
      | grep -qE "^n(127\.0\.0\.1|\[::1\]|localhost):"
    return
  fi

  if command -v netstat >/dev/null 2>&1; then
    netstat -an 2>/dev/null \
      | awk '/LISTEN/ {print $4}' \
      | grep -qE "^(127\.0\.0\.1|::1)[.:]${port}$"
    return
  fi

  return 1
}

zdots_svc_health_check_url() {
  local url="$1"
  local method="${2:-GET}"
  local payload="${3:-}"
  if [[ "$method" == "POST" ]]; then
    curl -sf -m 2 -X POST "$url" -H "Content-Type: application/json" -d "$payload" >/dev/null 2>&1 && return 0
  else
    curl -sf -m 2 "$url" >/dev/null 2>&1 && return 0
  fi
  zdots_svc_loopback_listening "$url"
}

# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

zdots_svc_restart() {
  local stop_cmd="$1" start_cmd="$2"
  eval "$stop_cmd"
  sleep 1
  eval "$start_cmd"
}

# ---------------------------------------------------------------------------
# Observability (OTLP tracing)
# ---------------------------------------------------------------------------

# zdots_svc_emit_span <name> <start_ts_nano> <end_ts_nano> [key=value ...]
# Emits a basic OTLP trace span to the local collector.
# Attributes are passed as key=value pairs; values may contain '='.
zdots_svc_emit_span() {
  local name="$1" start_ns="$2" end_ns="$3"
  shift 3

  local otlp_endpoint="${ZDOTS_OTLP_ENDPOINT:-http://127.0.0.1:4318}"
  if [[ -z "${ZDOTS_TRACE_ID:-}" ]]; then return 0; fi

  # Build attributes JSON in a single jq call — one subprocess regardless of
  # how many key=value pairs are passed.
  local attrs_json
  attrs_json=$(jq -cn '$ARGS.positional | map(
    index("=") as $i |
    { key: .[:$i], value: { stringValue: .[($i+1):] } }
  )' --args "$@")

  local payload
  payload=$(jq -nc \
    --arg name "$name" \
    --arg tid "$ZDOTS_TRACE_ID" \
    --arg sid "$ZDOTS_SPAN_ID" \
    --arg start "$start_ns" \
    --arg end "$end_ns" \
    --argjson attrs "$attrs_json" \
    '{
      resourceSpans: [{
        resource: { attributes: [{ key: "service.name", value: { stringValue: "zdots-agent" } }] },
        scopeSpans: [{
          spans: [{
            traceId: $tid,
            spanId: $sid,
            name: $name,
            startTimeUnixNano: $start,
            endTimeUnixNano: $end,
            attributes: $attrs,
            status: { code: 1 }
          }]
        }]
      }]
    }')

  curl -s -o /dev/null -X POST -H "Content-Type: application/json" \
    -d "$payload" "${otlp_endpoint}/v1/traces" || true
}

# zdots_svc_new_span_id — generate a random 8-byte (16-char) hex span ID.
zdots_svc_new_span_id() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    printf '%04x%04x%04x%04x' $RANDOM $RANDOM $RANDOM $RANDOM | head -c 16
  else
    openssl rand -hex 8
  fi
}

zdots_svc_logs() {
  local log_file="$1"
  trap 'exit 0' INT TERM
  mkdir -p "$(dirname "$log_file")"
  tail -f "$log_file"
}

# ---------------------------------------------------------------------------
# Standardised output (text or JSON)
# ---------------------------------------------------------------------------

# zdots_svc_print_status <json_bool> <running_bool> <pid> <endpoint> <log_file> [key=val ...]
zdots_svc_print_status() {
  local json="$1" running="$2" pid="$3" endpoint="$4" log_file="$5"
  shift 5

  if [[ "$json" == "true" ]]; then
    printf '{\n'
    printf '  "running": %s,\n' "$running"
    printf '  "pid": %s,\n'     "${pid:-null}"
    printf '  "endpoint": "%s",\n' "$endpoint"
    printf '  "log_file": "%s"' "$log_file"
    for kv in "$@"; do
      local k="${kv%%=*}" v="${kv#*=}"
      if [[ "$v" =~ ^(true|false|[0-9]+)$ ]]; then
        printf ',\n  "%s": %s'   "$k" "$v"
      else
        printf ',\n  "%s": "%s"' "$k" "$v"
      fi
    done
    printf '\n}\n'
  else
    if [[ "$running" == "true" ]]; then
      _svc_ok "running (PID: ${pid:-unknown})"
    else
      _svc_warn "not running"
    fi
    printf '%-12s %s\n' "endpoint" "$endpoint"
    printf '%-12s %s\n' "log"      "$log_file"
    for kv in "$@"; do
      local k="${kv%%=*}" v="${kv#*=}"
      printf '%-12s %s\n' "$k" "$v"
    done
  fi
}

# zdots_svc_print_health <json_bool> <healthy_bool> <endpoint> [key=val ...]
zdots_svc_print_health() {
  local json="$1" healthy="$2" endpoint="$3"
  shift 3

  if [[ "$json" == "true" ]]; then
    printf '{\n'
    printf '  "healthy": %s,\n' "$healthy"
    printf '  "endpoint": "%s"' "$endpoint"
    for kv in "$@"; do
      local k="${kv%%=*}" v="${kv#*=}"
      if [[ "$v" =~ ^(true|false|[0-9]+)$ ]]; then
        printf ',\n  "%s": %s'   "$k" "$v"
      else
        printf ',\n  "%s": "%s"' "$k" "$v"
      fi
    done
    printf '\n}\n'
  else
    if [[ "$healthy" == "true" ]]; then
      _svc_ok "healthy ($endpoint)"
      return 0
    else
      _svc_die "unhealthy ($endpoint)"
    fi
  fi
}
