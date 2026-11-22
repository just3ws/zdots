#!/usr/bin/env bash
# lib/sdk/cli-audit.bash — Tenant CLI SDK: NDJSON command-audit shim (Z-185, ADR-0005).
#
# Emits START and END NDJSON records with write-class taxonomy (read-only |
# lake-write | db-mutating) and chains onto any existing EXIT trap without
# clobbering it.
#
# Usage:
#   source "${ZDOTDIR:-$HOME/.config/zsh}/lib/sdk/cli-audit.bash"
#   zdots_audit_init "my-tool" "read-only"

_zdots_audit_json_esc() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

_zdots_audit_now_ms() {
  if [ -n "${EPOCHREALTIME:-}" ]; then
    awk -v t="$EPOCHREALTIME" 'BEGIN { printf "%.0f", t * 1000 }'
  else
    printf '%s000' "$(date +%s)"
  fi
}

_zdots_audit_emit() {
  local event="$1" rc="${2:-}" dur="${3:-}"
  local log_file="${ZDOTS_AUDIT_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/zdots/cli-audit.jsonl}"
  mkdir -p "${log_file%/*}" 2>/dev/null || return 0
  local ts tool_e class_e trace_e
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tool_e="$(_zdots_audit_json_esc "${_ZDOTS_AUDIT_TOOL:-unknown}")"
  class_e="$(_zdots_audit_json_esc "${_ZDOTS_AUDIT_CLASS:-read-only}")"
  trace_e="$(_zdots_audit_json_esc "${ZDOTS_TRACE_ID:-}")"
  if [ "$event" = "END" ]; then
    printf '{"ts":"%s","event":"END","tool":"%s","write_class":"%s","pid":%d,"rc":%d,"duration_ms":%d,"trace_id":"%s"}\n' \
      "$ts" "$tool_e" "$class_e" "$$" "${rc:-0}" "${dur:-0}" "$trace_e" >> "$log_file" 2>/dev/null || true
  else
    printf '{"ts":"%s","event":"START","tool":"%s","write_class":"%s","pid":%d,"trace_id":"%s"}\n' \
      "$ts" "$tool_e" "$class_e" "$$" "$trace_e" >> "$log_file" 2>/dev/null || true
  fi
}

_zdots_audit_on_exit() {
  local _rc=$?
  local _end_ms _dur=0
  _end_ms="$(_zdots_audit_now_ms)"
  if [ -n "${_ZDOTS_AUDIT_START_MS:-}" ]; then
    _dur=$(( _end_ms - _ZDOTS_AUDIT_START_MS ))
    [ "$_dur" -lt 0 ] && _dur=0
  fi
  _zdots_audit_emit "END" "$_rc" "$_dur"
  if [ -n "${_ZDOTS_AUDIT_PREV_TRAP:-}" ]; then
    eval "$_ZDOTS_AUDIT_PREV_TRAP" || true
  fi
  return "$_rc"
}

# zdots_audit_init <tool> <write_class>
# write_class: read-only | lake-write | db-mutating
zdots_audit_init() {
  local tool="${1:?zdots_audit_init: tool name required}"
  local write_class="${2:-read-only}"
  case "$write_class" in
    read-only|lake-write|db-mutating) ;;
    *)
      printf 'zdots_audit_init: invalid write_class "%s" (expected read-only|lake-write|db-mutating)\n' "$write_class" >&2
      return 1
      ;;
  esac

  _ZDOTS_AUDIT_TOOL="$tool"
  _ZDOTS_AUDIT_CLASS="$write_class"
  _ZDOTS_AUDIT_START_MS="$(_zdots_audit_now_ms)"
  _zdots_audit_emit "START"

  # Preserve any pre-existing EXIT trap by chaining it inside _zdots_audit_on_exit.
  local existing
  existing="$(trap -p EXIT 2>/dev/null || true)"
  if [ -n "$existing" ]; then
    existing="${existing#trap -- \'}"
    existing="${existing%\' EXIT}"
    existing="${existing%\' SIGEXIT}"
    [ "$existing" = "_zdots_audit_on_exit" ] && existing=""
    _ZDOTS_AUDIT_PREV_TRAP="$existing"
  else
    _ZDOTS_AUDIT_PREV_TRAP=""
  fi
  trap '_zdots_audit_on_exit' EXIT
}
