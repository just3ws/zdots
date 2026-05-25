#!/usr/bin/env bats
# tests/ai_invoke.bats — AI Invocation Interface: zdots_ai_infer_raw + zdots_ai_distill
#
# Test groups:
#   A. zdots_ai_infer_raw — gate, hygiene, delegation to ai-query
#   B. zdots_ai_distill   — JSON validation, error propagation
#   C. zdots_ai_infer_raw — integration with mock ai-query

setup() {
  load "setup.bash"
  setup_environment

  MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin"
  mkdir -p "$MOCK_BIN"

  # Default mock ai-query: exits 0, returns a minimal JSON response
  cat > "$MOCK_BIN/ai-query" <<'MOCK'
#!/usr/bin/env bash
echo '{"lesson":"test lesson","summary":"s","intent":"i","result":"r","tags":[]}'
MOCK
  chmod +x "$MOCK_BIN/ai-query"

  # Default env: local AI mode, loopback endpoint
  export ZDOTS_AI_MODE=local
  export ZDOTS_AI_ENDPOINT=http://127.0.0.1:8080
  export ZDOTDIR="$REPO_ROOT"
}

# ---------------------------------------------------------------------------
# A. zdots_ai_infer_raw — gate and input validation
# ---------------------------------------------------------------------------

@test "ai_invoke: infer_raw exits 2 when ZDOTS_AI_MODE=none" {
  run bash -c "
    export ZDOTS_AI_MODE=none
    export ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/ai-invoke.bash
    zdots_ai_infer_raw 'hello'
  "
  [ "$status" -eq 2 ]
}

@test "ai_invoke: infer_raw exits 2 with empty prompt" {
  run bash -c "
    export ZDOTS_AI_MODE=local
    export ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/ai-invoke.bash
    zdots_ai_infer_raw ''
  "
  [ "$status" -eq 2 ]
}

@test "ai_invoke: infer_raw exits 1 when ai-query not found" {
  run bash -c "
    export ZDOTS_AI_MODE=local
    export ZDOTDIR='$BATS_TEST_TMPDIR'
    mkdir -p '$BATS_TEST_TMPDIR/lib'
    cp '$ZDOTDIR/lib/ai-invoke.bash' '$BATS_TEST_TMPDIR/lib/'
    cp '$ZDOTDIR/lib/ai_boundary.bash' '$BATS_TEST_TMPDIR/lib/'
    cp '$ZDOTDIR/lib/message_hygiene.bash' '$BATS_TEST_TMPDIR/lib/'
    cp '$ZDOTDIR/lib/phi_scrubber.bash' '$BATS_TEST_TMPDIR/lib/'
    mkdir -p '$BATS_TEST_TMPDIR/etc'
    cp '$ZDOTDIR/etc/phi-patterns.yaml' '$BATS_TEST_TMPDIR/etc/'
    source '$BATS_TEST_TMPDIR/lib/ai-invoke.bash'
    zdots_ai_infer_raw 'hello'
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"ai-query not found"* ]]
}

@test "ai_invoke: infer_raw runs hygiene — PHI stripped before delegation" {
  # ai-query mock captures its arguments to a file
  cat > "$MOCK_BIN/ai-query" <<'MOCK'
#!/usr/bin/env bash
echo "$@" > "$BATS_TEST_TMPDIR/aiq-args"
cat "$BATS_TEST_TMPDIR/aiq-args"
MOCK
  chmod +x "$MOCK_BIN/ai-query"

  run bash -c "
    export ZDOTS_AI_QUERY='$MOCK_BIN/ai-query'
    export ZDOTS_AI_MODE=local
    export ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/ai-invoke.bash
    zdots_ai_infer_raw 'patient SSN 123-45-6789 here'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" != *"123-45-6789"* ]]
}

@test "ai_invoke: infer_raw passes system prompt to ai-query" {
  cat > "$MOCK_BIN/ai-query" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@"
MOCK
  chmod +x "$MOCK_BIN/ai-query"

  run bash -c "
    export ZDOTS_AI_QUERY='$MOCK_BIN/ai-query'
    export ZDOTS_AI_MODE=local
    export ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/ai-invoke.bash
    zdots_ai_infer_raw 'my prompt' 'my system prompt'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"my system prompt"* ]]
  [[ "$output" == *"--system"* ]]
}

@test "ai_invoke: infer_raw omits --system when no system prompt given" {
  cat > "$MOCK_BIN/ai-query" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@"
MOCK
  chmod +x "$MOCK_BIN/ai-query"

  run bash -c "
    export ZDOTS_AI_QUERY='$MOCK_BIN/ai-query'
    export ZDOTS_AI_MODE=local
    export ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/ai-invoke.bash
    zdots_ai_infer_raw 'just a prompt'
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"--system"* ]]
}

# ---------------------------------------------------------------------------
# B. zdots_ai_distill — JSON validation and error propagation
# ---------------------------------------------------------------------------

@test "ai_invoke: distill returns valid JSON on success" {
  cat > "$MOCK_BIN/ai-query" <<'MOCK'
#!/usr/bin/env bash
echo '{"lesson":"l","summary":"s","intent":"i","result":"r","tags":["a"]}'
MOCK
  chmod +x "$MOCK_BIN/ai-query"

  run bash -c "
    export ZDOTS_AI_QUERY='$MOCK_BIN/ai-query'
    export ZDOTS_AI_MODE=local
    export ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/ai-invoke.bash
    zdots_ai_distill 'summarize session'
  "
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq empty
}

@test "ai_invoke: distill exits 2 when model returns non-JSON" {
  cat > "$MOCK_BIN/ai-query" <<'MOCK'
#!/usr/bin/env bash
echo "sorry, I cannot help with that"
MOCK
  chmod +x "$MOCK_BIN/ai-query"

  run bash -c "
    export ZDOTS_AI_QUERY='$MOCK_BIN/ai-query'
    export ZDOTS_AI_MODE=local
    export ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/ai-invoke.bash
    zdots_ai_distill 'summarize session'
  "
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid or empty JSON"* ]]
}

@test "ai_invoke: distill exits 1 when inference fails" {
  cat > "$MOCK_BIN/ai-query" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
  chmod +x "$MOCK_BIN/ai-query"

  run bash -c "
    export ZDOTS_AI_QUERY='$MOCK_BIN/ai-query'
    export ZDOTS_AI_MODE=local
    export ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/ai-invoke.bash
    zdots_ai_distill 'summarize session'
  "
  [ "$status" -eq 1 ]
}

@test "ai_invoke: distill exits 2 with empty prompt" {
  run bash -c "
    export ZDOTS_AI_MODE=local
    export ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/ai-invoke.bash
    zdots_ai_distill ''
  "
  [ "$status" -eq 2 ]
}

@test "ai_invoke: distill extracts JSON from prose-wrapped response" {
  cat > "$MOCK_BIN/ai-query" <<'MOCK'
#!/usr/bin/env bash
printf 'Here is your summary:\n{"lesson":"l","summary":"s","intent":"i","result":"r","tags":[]}\nDone.\n'
MOCK
  chmod +x "$MOCK_BIN/ai-query"

  run bash -c "
    export ZDOTS_AI_QUERY='$MOCK_BIN/ai-query'
    export ZDOTS_AI_MODE=local
    export ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/ai-invoke.bash
    zdots_ai_distill 'summarize'
  "
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '.lesson' >/dev/null
}
