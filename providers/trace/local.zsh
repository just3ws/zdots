# providers/trace/local.zsh — Local JSONL trace provider

# File setup extracted so otlp.zsh can reuse without function-overwrite conflicts.
_zdots_trace_file_init() {
  _zdots_trace_file="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/traces.jsonl"

  # Ensure restricted directory (700)
  if [[ ! -d "$_zdots_trace_file:h" ]]; then
    mkdir -p "$_zdots_trace_file:h"
  fi
  chmod 700 "$_zdots_trace_file:h" 2>/dev/null || true

  # Simple Log Rotation (prevent infinite growth)
  # Max size: ~10MB
  if [[ -f "$_zdots_trace_file" ]]; then
    # stat -f%z for BSD/Mac, stat -c%s for Linux
    local size=$(stat -f %z "$_zdots_trace_file" 2>/dev/null || stat -c %s "$_zdots_trace_file" 2>/dev/null || echo 0)
    if (( size > 10485760 )); then
      mv -f "$_zdots_trace_file" "$_zdots_trace_file.old" 2>/dev/null || true
    fi
  fi

  # Ensure restricted file (600)
  if [[ ! -f "$_zdots_trace_file" ]]; then
    touch "$_zdots_trace_file"
  fi
  chmod 600 "$_zdots_trace_file" 2>/dev/null || true

  # Hold ONE append fd for the shell's lifetime. A per-event `>>` open/close
  # pays a content-proportional scan on managed machines (measured: 14.6ms at
  # 1.7MB, 4.3ms at 500K, linear — endpoint security scans on write-close); a
  # held fd writes in ~0.15ms at any size. Rotation stays init-time: after mv,
  # already-open shells keep appending to the .old inode until they restart —
  # the pre-existing tradeoff, unchanged.
  if [[ -z "${_zdots_trace_fd:-}" ]]; then
    exec {_zdots_trace_fd}>>"$_zdots_trace_file" 2>/dev/null || _zdots_trace_fd=""
  fi
}

zdots_trace_init() {
  # Load zsh/datetime for strftime and EPOCHSECONDS — no-fork timestamps.
  zmodload zsh/datetime 2>/dev/null || true
  _zdots_trace_file_init
  _ZDOTS_TRACE_INITIALIZED=1
}

# _zdots_trace_redact_var DATA — sets $_zdots_redacted without a fork when
# the resident scrubber (Z-283) is up. This path runs in preexec for EVERY
# command; the old $(echo | sed) cost 3 forks + 1 exec per command and was a
# drifting hand-copy of the registry — the exact 3-engine problem ADR-0002
# unified the Go binary to end. env.sh's zdots_trace_redact stays as the
# POSIX/coproc-less fallback. A suppress-match ('2') conservatively replaces
# the WHOLE payload, a superset of the old conn-substring redaction.
_zdots_trace_redact_var() {
  if (( ${+functions[_phi_srv_scrub]} )) && [[ "${ZDOTS_PHI_COPROC:-1}" == "1" ]] \
     && _phi_srv_scrub "$1"; then
    if [[ "$_phi_srv_status" == "2" ]]; then
      _zdots_redacted="[REDACTED-CONN]"
    else
      _zdots_redacted="$_phi_srv_payload"
    fi
    return 0
  fi
  _zdots_redacted="$(zdots_trace_redact "$1")"
}

# zdots_trace_log EVENT_TYPE DATA
# Logs a structured event to the trace file with basic redaction.
zdots_trace_log() {
  [[ "${_ZDOTS_TRACE_INITIALIZED:-0}" == "1" ]] || return 0

  local event_type="$1"
  local data="$2"
  # strftime from zsh/datetime — no fork
  local timestamp; strftime -s timestamp '%Y-%m-%dT%H:%M:%S%z' $EPOCHSECONDS

  _zdots_trace_redact_var "$data"
  local redacted_data="$_zdots_redacted"
  # Escape double quotes via parameter expansion — no fork
  local escaped_data="${redacted_data//\"/\\\"}"

  if [[ -n "${_zdots_trace_fd:-}" ]]; then
    printf '{"ts":"%s","sid":"%s","spid":"%s","event":"%s","data":"%s"}\n' \
      "$timestamp" "$ZDOTS_TRACE_ID" "$ZDOTS_SPAN_ID" "$event_type" "$escaped_data" \
      >&"$_zdots_trace_fd"
  else
    printf '{"ts":"%s","sid":"%s","spid":"%s","event":"%s","data":"%s"}\n' \
      "$timestamp" "$ZDOTS_TRACE_ID" "$ZDOTS_SPAN_ID" "$event_type" "$escaped_data" \
      >> "$_zdots_trace_file"
  fi
}
