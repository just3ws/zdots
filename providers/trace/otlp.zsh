# providers/trace/otlp.zsh — OpenTelemetry OTLP trace provider (Semantic Conventions)
# Hybrid: writes to local JSONL + sends to OTLP collector when telemetry is enabled.

# Source local provider for _zdots_trace_file_init (file setup).
# We then override zdots_trace_init and zdots_trace_log with hybrid versions.
zdots_require trace local

zdots_trace_init() {
  # Load zsh/datetime for $EPOCHSECONDS, $EPOCHREALTIME, and strftime (no-fork timestamps)
  zmodload zsh/datetime 2>/dev/null || true

  # Endpoint for OTLP/HTTP collector
  OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://127.0.0.1:4318}"
  OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-zdots-shell}"

  # Resource Attributes (OTEL_RESOURCE_ATTRIBUTES)
  # Standard: process.pid, process.owner, os.type, host.name
  # $OSTYPE is a Zsh built-in (e.g. "darwin24.5.0", "linux-gnu") — no fork.
  local os_type="${${OSTYPE%%[0-9.]*}:l}"
  local shell_name="${SHELL:t}"
  local is_interactive="false"; [[ -o interactive ]] && is_interactive="true"

  # Construct Resource JSON once
  export _ZDOTS_OTEL_RESOURCE_JSON=$(printf '{"attributes":[{"key":"service.name","value":{"stringValue":"%s"}},{"key":"process.pid","value":{"intValue":%d}},{"key":"process.owner","value":{"stringValue":"%s"}},{"key":"process.executable.name","value":{"stringValue":"%s"}},{"key":"process.interactive","value":{"boolValue":%s}},{"key":"os.type","value":{"stringValue":"%s"}},{"key":"host.name","value":{"stringValue":"%s"}}]}' \
    "$OTEL_SERVICE_NAME" "$$" "$USER" "$shell_name" "$is_interactive" "$os_type" "$(hostname)")

  # Initialize local trace file (reuses _zdots_trace_file_init from local.zsh)
  _zdots_trace_file_init

  _ZDOTS_TRACE_INITIALIZED=1
}

zdots_trace_log() {
  [[ "${_ZDOTS_TRACE_INITIALIZED:-0}" == "1" ]] || return 0

  local event_type="$1"
  local data="$2"

  # Perform redaction once
  local redacted_data=$(zdots_trace_redact "$data")

  # 1. Local logging (JSONL)
  _zdots_trace_log_local "$event_type" "$redacted_data"

  # 2. Remote logging (OTLP) if enabled
  if [[ "${ZDOTS_TELEMETRY_ENABLED:-0}" == "1" ]]; then
    _zdots_trace_send_otlp "$event_type" "$redacted_data"
  fi
}

# _zdots_trace_log_local EVENT_TYPE REDACTED_DATA
# Writes a structured event to the local trace file.
_zdots_trace_log_local() {
  [[ -n "$_zdots_trace_file" ]] || return 0
  local event_type="$1"
  local redacted_data="$2"
  # strftime from zsh/datetime — no fork
  local timestamp; strftime -s timestamp '%Y-%m-%dT%H:%M:%S%z' $EPOCHSECONDS
  # Escape double quotes via parameter expansion — no fork
  local escaped_data="${redacted_data//\"/\\\"}"
  printf '{"ts":"%s","sid":"%s","spid":"%s","event":"%s","data":"%s"}\n' \
    "$timestamp" "$ZDOTS_TRACE_ID" "$ZDOTS_SPAN_ID" "$event_type" "$escaped_data" \
    >> "$_zdots_trace_file"
}

# _zdots_trace_send_otlp EVENT_TYPE DATA
_zdots_trace_send_otlp() {
  local event_name="$1"
  local cmd_line="$2"

  # Map event to Span Name (Semantic Convention: command execution)
  local span_name="$event_name"
  if [[ "$event_name" == "exec" ]]; then
    span_name="${cmd_line%% *}" # First word of command
  fi

  # Nanosecond timestamps via $EPOCHREALTIME (zsh/datetime) — no fork.
  # EPOCHREALTIME is "seconds.fractional"; normalize fractional to exactly 6 digits
  # (microseconds) then append 000 to get nanoseconds.
  local epoch_rt="$EPOCHREALTIME"
  local epoch_secs="${epoch_rt%.*}"
  local epoch_frac="${epoch_rt#*.}"
  epoch_frac="${epoch_frac[1,6]}"                                   # truncate to max 6 digits
  while [[ ${#epoch_frac} -lt 6 ]]; do epoch_frac+="0"; done       # pad to exactly 6
  local start_time_nano="${epoch_secs}${epoch_frac}000"
  local end_time_nano=$(( start_time_nano + 1000000 ))              # +1 ms minimum duration

  # JSON-escape command line and event name to prevent payload corruption
  local safe_cmd="${cmd_line//\\/\\\\}"; safe_cmd="${safe_cmd//\"/\\\"}"
  local safe_span="${span_name//\\/\\\\}"; safe_span="${safe_span//\"/\\\"}"
  local safe_event="${event_name//\\/\\\\}"; safe_event="${safe_event//\"/\\\"}"

  # OTLP Trace Payload — kind:1 = SPAN_KIND_INTERNAL
  local payload=$(printf '{"resourceSpans":[{"resource":%s,"scopeSpans":[{"spans":[{"traceId":"%s","spanId":"%s","name":"%s","kind":1,"startTimeUnixNano":"%s","endTimeUnixNano":"%s","attributes":[{"key":"process.command_line","value":{"stringValue":"%s"}},{"key":"event.type","value":{"stringValue":"%s"}}]}]}]}]}' \
    "$_ZDOTS_OTEL_RESOURCE_JSON" "$ZDOTS_TRACE_ID" "$ZDOTS_SPAN_ID" "$safe_span" "$start_time_nano" "$end_time_nano" "$safe_cmd" "$safe_event")

  # Send asynchronously (background)
  command curl -s -X POST -H "Content-Type: application/json" \
    -d "$payload" "$OTEL_EXPORTER_OTLP_ENDPOINT/v1/traces" >/dev/null 2>&1 &!
}
