# providers/trace/otlp.zsh — OpenTelemetry OTLP trace provider (Semantic Conventions)

zdots_trace_init() {
  # Endpoint for OTLP/HTTP collector
  export OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}"
  export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-zdots-shell}"
  
  # Resource Attributes (OTEL_RESOURCE_ATTRIBUTES)
  # Standard: process.pid, process.owner, os.type, host.name
  local os_type="$(uname -s | tr '[:upper:]' '[:lower:]')"
  local shell_name="${SHELL:t}"
  local is_interactive="false"; [[ -o interactive ]] && is_interactive="true"
  
  # Construct Resource JSON once
  export _ZDOTS_OTEL_RESOURCE_JSON=$(printf '{"attributes":[{"key":"service.name","value":{"stringValue":"%s"}},{"key":"process.pid","value":{"intValue":%d}},{"key":"process.owner","value":{"stringValue":"%s"}},{"key":"process.executable.name","value":{"stringValue":"%s"}},{"key":"process.interactive","value":{"boolValue":%s}},{"key":"os.type","value":{"stringValue":"%s"}},{"key":"host.name","value":{"stringValue":"%s"}}]}' \
    "$OTEL_SERVICE_NAME" "$$" "$USER" "$shell_name" "$is_interactive" "$os_type" "$(hostname)")

  # Initialize the local trace as well (Hybrid)
  zdots_require trace local
  zdots_trace_init
}

zdots_trace_log() {
  local event_type="$1"
  local data="$2"
  
  # Perform redaction once
  local redacted_data=$(zdots_trace_redact "$data")
  
  # 1. Local logging (JSONL)
  zdots_trace_log_local "$event_type" "$redacted_data"
  
  # 2. Remote logging (OTLP) if enabled
  if [[ "${ZDOTS_TELEMETRY_ENABLED:-0}" == "1" ]]; then
    _zdots_trace_send_otlp "$event_type" "$redacted_data"
  fi
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

  # Start/End times (nanoseconds since epoch)
  local start_time_nano=$(date +%s000000000)

  # OTLP Trace Payload (W3C Trace ID must be 16 bytes hex, Span ID 8 bytes hex)
  # W3C Trace ID: $ZDOTS_TRACE_ID
  # W3C Span ID:  $ZDOTS_SPAN_ID
  
  local payload=$(printf '{"resourceSpans":[{"resource":%s,"scopeSpans":[{"spans":[{"traceId":"%s","spanId":"%s","name":"%s","startTimeUnixNano":"%s","endTimeUnixNano":"%s","attributes":[{"key":"process.command_line","value":{"stringValue":"%s"}},{"key":"event.type","value":{"stringValue":"%s"}}]}]}]}]}' \
    "$_ZDOTS_OTEL_RESOURCE_JSON" "$ZDOTS_TRACE_ID" "$ZDOTS_SPAN_ID" "$span_name" "$start_time_nano" "$start_time_nano" "$cmd_line" "$event_name")
    
  # Send asynchronously (background)
  command curl -s -X POST -H "Content-Type: application/json" \
    -d "$payload" "$OTEL_EXPORTER_OTLP_ENDPOINT/v1/traces" >/dev/null 2>&1 &
}

# Alias local trace to local provider function
zdots_trace_log_local() {
  local event_type="$1"
  local redacted_data="$2"
  local timestamp="$(date +%Y-%m-%dT%H:%M:%S%z)"
  local escaped_data="$(echo "$redacted_data" | sed 's/"/\\"/g')"
  printf '{"ts":"%s","sid":"%s","spid":"%s","event":"%s","data":"%s"}\n' \
    "$timestamp" "$ZDOTS_TRACE_ID" "$ZDOTS_SPAN_ID" "$event_type" "$escaped_data" \
    >> "$_zdots_trace_file"
}
