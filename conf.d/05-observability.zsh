# conf.d/05-observability.zsh — Shell observability and tracing hooks

if [[ -n "$(command -v zdots_trace_init)" ]]; then
  if [[ -z "${_ZDOTS_TRACE_INITIALIZED:-}" ]]; then
    zdots_trace_init
    zdots_trace_log "session_start" "profile=${ZDOTS_ENV_PROFILE:-unknown}, shell=$SHELL"
  fi

  # Hook: Directory Change
  _zdots_trace_chpwd() {
    zdots_trace_log "chdir" "$PWD"
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _zdots_trace_chpwd

  # Hook: Command Result (Post-execution: Error Tracing)
  _zdots_trace_precmd() {
    local last_status=$?
    
    # If the last command failed, send an error span
    if [[ $last_status -ne 0 ]]; then
      if command -v otel-cli >/dev/null 2>&1; then
        (
          OTEL_SERVICE_NAME="$OTEL_SERVICE_NAME" \
          OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4317" \
          otel-cli span \
            --name "command.error" \
            --attrs "status=$last_status,command=$ZDOTS_LAST_COMMAND" \
            --force-trace-id "$ZDOTS_TRACE_ID" \
            --force-span-id "$ZDOTS_SPAN_ID" \
            --status "error" \
            >/dev/null 2>&1
        ) &!
      fi
      zdots_trace_log "error" "status=$last_status, cmd=$ZDOTS_LAST_COMMAND"
    fi
  }
  add-zsh-hook precmd _zdots_trace_precmd

  # Hook: Command Execution (Pre-execution: Rotate Span ID)
  _zdots_trace_preexec() {
    local cmd="$1"
    export ZDOTS_LAST_COMMAND="$cmd"
    
    # Rotate Span ID for the new command (Span) — Zsh built-in, no forks
    printf -v ZDOTS_SPAN_ID '%04x%04x%04x%04x' $RANDOM $RANDOM $RANDOM $RANDOM
    export TRACEPARENT="00-${ZDOTS_TRACE_ID}-${ZDOTS_SPAN_ID}-01"
    
    zdots_trace_log "exec" "$cmd"
  }
  add-zsh-hook preexec _zdots_trace_preexec

  # Distributed Tracing Propagation (Curl Wrapper)
  curl() {
    # If ZDOTS_TRACE_PROPAGATION=1 (default), inject traceparent header.
    if [[ "${ZDOTS_TRACE_PROPAGATION:-1}" == "1" ]]; then
      command curl -H "traceparent: $TRACEPARENT" "$@"
    else
      command curl "$@"
    fi
  }

  # Heartbeat Span (Inspired by the Star Wars Saga 'Pulse')
  if command -v otel-cli >/dev/null 2>&1; then
    # Capture system health (Load Average) — prefer /proc/loadavg on Linux, sysctl on macOS
    local load_avg
    if [[ -r /proc/loadavg ]]; then
      read -r load_avg _ < /proc/loadavg
    else
      load_avg="$(sysctl -n vm.loadavg 2>/dev/null)" && load_avg="${load_avg##\{ }" && load_avg="${load_avg%% *}" || load_avg="unknown"
    fi
    
    # Send a backgrounded heartbeat span
    (
      OTEL_SERVICE_NAME="$OTEL_SERVICE_NAME" \
      OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4317" \
      otel-cli span \
        --name "shell.heartbeat" \
        --attrs "profile=${ZDOTS_ENV_PROFILE:-unknown},os=$(uname -s),sys.load_avg=$load_avg" \
        --force-trace-id "$ZDOTS_TRACE_ID" \
        --force-span-id "$ZDOTS_SPAN_ID" \
        >/dev/null 2>&1
    ) &!
  fi
fi
