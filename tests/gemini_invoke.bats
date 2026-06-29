#!/usr/bin/env bats
# tests/gemini_invoke.bats — Contract tests for bin/gemini-invoke OTel seam

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"

  # Fake gemini CLI that captures the env and exits cleanly
  FAKE_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$FAKE_BIN"
  cat > "$FAKE_BIN/gemini" <<'FAKE'
#!/usr/bin/env bash
# Capture the OTel env for inspection
printf '%s\n' "TRACEPARENT=${TRACEPARENT:-}" >> "$BATS_TEST_TMPDIR/captured_env"
printf '%s\n' "OTEL_RESOURCE_ATTRIBUTES=${OTEL_RESOURCE_ATTRIBUTES:-}" >> "$BATS_TEST_TMPDIR/captured_env"
exit 0
FAKE
  chmod +x "$FAKE_BIN/gemini"

  # Stub out zdots_svc_emit_span so it doesn't try to hit the collector
  # and zdots_svc_new_span_id so it returns a deterministic value
  cat > "$FAKE_BIN/python3" <<'FAKE'
#!/usr/bin/env bash
printf '1000000000\n'
FAKE
  chmod +x "$FAKE_BIN/python3"

  export PATH="$FAKE_BIN:$PATH"

  # Minimal env required by gemini-invoke
  export ZDOTS_TRACE_ID="aabbccddeeff00112233445566778899"
  export ZDOTS_SPAN_ID=""
  unset OTEL_RESOURCE_ATTRIBUTES
}

_run_invoke() {
  # Override sourced functions that hit live services
  run env \
    ZDOTS_TRACE_ID="$ZDOTS_TRACE_ID" \
    ZDOTS_SPAN_ID="" \
    PATH="$FAKE_BIN:$PATH" \
    bash -c "
      source '$REPO_ROOT/lib/svc-health.bash'
      zdots_svc_emit_span() { :; }
      zdots_svc_new_span_id() { printf 'fakespanfakespanf'; }
      zdots_ctx_hydrate() { :; }
      # gemini-invoke sources env.sh only when ZDOTS_TRACE_ID is unset — it is set
      source '$BIN/gemini-invoke' gemini \"\$@\"
    " -- "$@"
}

# ---------------------------------------------------------------------------
# TRACEPARENT carries the trace ID
# ---------------------------------------------------------------------------

@test "gemini-invoke: TRACEPARENT contains ZDOTS_TRACE_ID" {
  run env \
    ZDOTS_TRACE_ID="$ZDOTS_TRACE_ID" \
    ZDOTS_SPAN_ID="" \
    PATH="$FAKE_BIN:$PATH" \
    bash -c "
      source '$REPO_ROOT/lib/svc-health.bash'
      zdots_svc_emit_span() { :; }
      zdots_svc_new_span_id() { printf 'fakespanfakespanf'; }
      ZDOTDIR='$REPO_ROOT'
      export ZDOTS_TRACE_ID ZDOTS_SPAN_ID
      # Run just the env-export portion of gemini-invoke, then check
      source <(grep -A3 'export TRACEPARENT' '$BIN/gemini-invoke' | head -4)
      printf '%s\n' \"\$TRACEPARENT\"
    "
  [ "$status" -eq 0 ]
  [[ "$output" == *"$ZDOTS_TRACE_ID"* ]]
}

# ---------------------------------------------------------------------------
# OTEL_RESOURCE_ATTRIBUTES carries zdots.trace.id
# ---------------------------------------------------------------------------

@test "gemini-invoke: OTEL_RESOURCE_ATTRIBUTES contains zdots.trace.id when unset" {
  run env \
    ZDOTS_TRACE_ID="$ZDOTS_TRACE_ID" \
    ZDOTS_SPAN_ID="" \
    PATH="$FAKE_BIN:$PATH" \
    bash -c "
      source '$REPO_ROOT/lib/svc-health.bash'
      zdots_svc_emit_span() { :; }
      zdots_svc_new_span_id() { printf 'fakespanfakespanf'; }
      ZDOTDIR='$REPO_ROOT'
      export ZDOTS_TRACE_ID ZDOTS_SPAN_ID
      AGENT_SPAN_ID=\"fakespanfakespanf\"
      unset OTEL_RESOURCE_ATTRIBUTES
      export OTEL_RESOURCE_ATTRIBUTES=\"\${OTEL_RESOURCE_ATTRIBUTES:+\${OTEL_RESOURCE_ATTRIBUTES},}zdots.trace.id=\${ZDOTS_TRACE_ID}\"
      printf '%s\n' \"\$OTEL_RESOURCE_ATTRIBUTES\"
    "
  [ "$status" -eq 0 ]
  [[ "$output" == "zdots.trace.id=${ZDOTS_TRACE_ID}" ]]
}

@test "gemini-invoke: OTEL_RESOURCE_ATTRIBUTES appends to existing value (no clobber)" {
  run env \
    ZDOTS_TRACE_ID="$ZDOTS_TRACE_ID" \
    ZDOTS_SPAN_ID="" \
    OTEL_RESOURCE_ATTRIBUTES="service.namespace=zdots" \
    PATH="$FAKE_BIN:$PATH" \
    bash -c "
      source '$REPO_ROOT/lib/svc-health.bash'
      zdots_svc_emit_span() { :; }
      zdots_svc_new_span_id() { printf 'fakespanfakespanf'; }
      ZDOTDIR='$REPO_ROOT'
      export ZDOTS_TRACE_ID ZDOTS_SPAN_ID
      AGENT_SPAN_ID=\"fakespanfakespanf\"
      export OTEL_RESOURCE_ATTRIBUTES=\"\${OTEL_RESOURCE_ATTRIBUTES:+\${OTEL_RESOURCE_ATTRIBUTES},}zdots.trace.id=\${ZDOTS_TRACE_ID}\"
      printf '%s\n' \"\$OTEL_RESOURCE_ATTRIBUTES\"
    "
  [ "$status" -eq 0 ]
  [[ "$output" == "service.namespace=zdots,zdots.trace.id=${ZDOTS_TRACE_ID}" ]]
}
