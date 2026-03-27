# providers/trace/local.zsh — Local JSONL trace provider

zdots_trace_init() {
  _zdots_trace_file="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/traces.jsonl"
  
  # Ensure restricted directory (700)
  if [[ ! -d "$_zdots_trace_file:h" ]]; then
    mkdir -p "$_zdots_trace_file:h"
  fi
  chmod 700 "$_zdots_trace_file:h" 2>/dev/null || true
  
  # Ensure restricted file (600)
  if [[ ! -f "$_zdots_trace_file" ]]; then
    touch "$_zdots_trace_file"
  fi
  chmod 600 "$_zdots_trace_file" 2>/dev/null || true
  
  export _ZDOTS_TRACE_INITIALIZED=1
}

# zdots_trace_redact DATA
# Returns redacted data masking common secrets.
zdots_trace_redact() {
  local data="$1"
  # Basic Redaction: Masking values after common password/secret flags
  echo "$data" | sed -E 's/(-p|--password|--api-key|--token|--secret|--auth|--authorization)[[:space:]:]+[^[:space:]]+/\1 [REDACTED]/gI'
}

# zdots_trace_log EVENT_TYPE DATA
# Logs a structured event to the trace file with basic redaction.
zdots_trace_log() {
  [[ "${_ZDOTS_TRACE_INITIALIZED:-0}" == "1" ]] || return 0
  
  local event_type="$1"
  local data="$2"
  local timestamp="$(date +%Y-%m-%dT%H:%M:%S%z)"
  
  local redacted_data=$(zdots_trace_redact "$data")
  
  # Minimal JSON construction for portability
  local escaped_data="$(echo "$redacted_data" | sed 's/"/\\"/g')"
  
  printf '{"ts":"%s","sid":"%s","spid":"%s","event":"%s","data":"%s"}\n' \
    "$timestamp" "$ZDOTS_TRACE_ID" "$ZDOTS_SPAN_ID" "$event_type" "$escaped_data" \
    >> "$_zdots_trace_file"
}
