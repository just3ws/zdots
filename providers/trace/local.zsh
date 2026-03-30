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
}

zdots_trace_init() {
  _zdots_trace_file_init
  _ZDOTS_TRACE_INITIALIZED=1
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
