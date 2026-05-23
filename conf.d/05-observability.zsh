# conf.d/05-observability.zsh — Shell observability and tracing hooks

if [[ -n "$(command -v zdots_trace_init)" ]]; then
  if [[ -z "${_ZDOTS_TRACE_INITIALIZED:-}" ]]; then
    zdots_trace_init
    zdots_trace_log "session_start" "profile=${ZDOTS_ENV_PROFILE:-unknown}, shell=$SHELL"
  fi

  # Cache otel-cli availability once at startup — avoids command -v fork per hook call.
  local _otel_bin="${commands[otel-cli]:-}"
  typeset -g _ZDOTS_OTEL_CLI_AVAILABLE=0
  [[ -n "$_otel_bin" ]] && _ZDOTS_OTEL_CLI_AVAILABLE=1

  # Hook: Directory Change
  _zdots_trace_chpwd() {
    zdots_trace_log "chdir" "$PWD"
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _zdots_trace_chpwd

  # Hook: Command Result (Post-execution: Error Tracing + Cognitive Load)
  _zdots_trace_precmd() {
    local last_status=$?
    export ZDOTS_LAST_EXIT="$last_status"

    # 1. Error Tracing
    if [[ $last_status -ne 0 ]]; then
      if [[ $_ZDOTS_OTEL_CLI_AVAILABLE -eq 1 ]]; then
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

    # 2. Cognitive Load Awareness (Frustration Detection)
    # Periodically check error velocity to trigger Calm Mode assistance.
    # We use a static counter to avoid checking every single command.
    (( _ZDOTS_CMD_COUNT++ ))
    if (( _ZDOTS_CMD_COUNT % 5 == 0 )); then
      # Source once (guard on function existence); never re-parse on every check.
      if (( ! ${+functions[zdots_check_cognitive_load]} )) && [[ -r "$ZDOTDIR/lib/cognitive-load.bash" ]]; then
        source "$ZDOTDIR/lib/cognitive-load.bash"
      fi
      if (( ${+functions[zdots_check_cognitive_load]} )); then
        if zdots_check_cognitive_load 3 5; then
          zdots_calm_mode
        fi
      fi
    fi
  }
  typeset -gi _ZDOTS_CMD_COUNT=0
  add-zsh-hook precmd _zdots_trace_precmd

  # Hook: Command Execution (Pre-execution: Rotate Span ID)
  _zdots_trace_preexec() {
    local cmd="$1"
    export ZDOTS_LAST_COMMAND="${cmd[1,512]}"

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

  # Heartbeat Span — backgrounded, never blocks prompt.
  if [[ $_ZDOTS_OTEL_CLI_AVAILABLE -eq 1 ]]; then
    # Capture load average — prefer /proc/loadavg (no fork on Linux),
    # else sysctl parameter expansion (one fork on macOS, acceptable at startup).
    local load_avg
    if [[ -r /proc/loadavg ]]; then
      read -r load_avg _ < /proc/loadavg
    else
      load_avg="$(sysctl -n vm.loadavg 2>/dev/null)"
      load_avg="${load_avg##\{ }"; load_avg="${load_avg%% *}"
      [[ -z "$load_avg" ]] && load_avg="unknown"
    fi

    # $OSTYPE is a Zsh built-in — no fork needed for OS name.
    local _os_name="${OSTYPE%%[0-9.]*}"

    (
      OTEL_SERVICE_NAME="$OTEL_SERVICE_NAME" \
      OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4317" \
      otel-cli span \
        --name "shell.heartbeat" \
        --attrs "profile=${ZDOTS_ENV_PROFILE:-unknown},os=${_os_name},sys.load_avg=$load_avg" \
        --force-trace-id "$ZDOTS_TRACE_ID" \
        --force-span-id "$ZDOTS_SPAN_ID" \
        >/dev/null 2>&1
    ) &!
  fi
fi
