# providers/trace/local.zsh — Local JSONL trace provider

zdots_trace_init() {
  _zdots_trace_file="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/traces.jsonl"
  mkdir -p "$_zdots_trace_file:h" 2>/dev/null || true
  [[ -f "$_zdots_trace_file" ]] || touch "$_zdots_trace_file"
  export _ZDOTS_TRACE_INITIALIZED=1
}

# zdots_trace_log EVENT_TYPE DATA
# Logs a structured event to the trace file.
zdots_trace_log() {
  [[ "${_ZDOTS_TRACE_INITIALIZED:-0}" == "1" ]] || return 0
  
  local event_type="$1"
  local data="$2"
  local timestamp="$(date +%Y-%m-%dT%H:%M:%S%z)"
  
  # Minimal JSON construction for portability
  # We escape double quotes in data if any.
  local escaped_data="$(echo "$data" | sed 's/"/\\"/g')"
  
  printf '{"ts":"%s","sid":"%s","event":"%s","data":"%s"}\n' \
    "$timestamp" "$ZDOTS_SESSION_ID" "$event_type" "$escaped_data" \
    >> "$_zdots_trace_file"
}
