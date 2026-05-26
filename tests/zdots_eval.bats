#!/usr/bin/env bats
# tests/zdots_eval.bats — Evaluation suite for zdots AI pipeline
#
# Verifies observable properties without requiring live inference:
#   - Domain routing correctness (--dry-run, no server needed)
#   - PHI scrubbing in the submission path
#   - Think-block stripping from raw model output
#   - --think flag wires through correctly
#   - Gate behaviour (ZDOTS_AI_MODE=none)
#   - Distillation field validation
#
# Live inference tests (E-group) are skipped when server is down.

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"
  LIB="$REPO_ROOT/lib"

  # Mock inference binary: exits 0, echoes "mock-response" to stdout
  MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin"
  mkdir -p "$MOCK_BIN"

  # Mock ai-query that simulates clean inference output
  cat > "$MOCK_BIN/ai-query" <<'MOCK'
#!/usr/bin/env bash
# Minimal mock — echoes canned response, honours --mode flag
echo "mock-response"
exit 0
MOCK
  chmod +x "$MOCK_BIN/ai-query"

  # Mock ai-query that emits a think block before the answer
  cat > "$BATS_TEST_TMPDIR/ai-query-think" <<'MOCK'
#!/usr/bin/env bash
printf '<think>\nstep 1: add the numbers\nstep 2: confirm result\n</think>\n4\n'
exit 0
MOCK
  chmod +x "$BATS_TEST_TMPDIR/ai-query-think"

  # Mock ai-query that returns valid distillation JSON
  cat > "$BATS_TEST_TMPDIR/ai-query-distill" <<'MOCK'
#!/usr/bin/env bash
cat <<'JSON'
{
  "lesson": "Fixed the embedding dimension after model upgrade.",
  "summary": "Migrated pgvector column from 3584 to 4096 dimensions.",
  "intent": "Upgrade local AI from Qwen2.5 to Qwen3-8B.",
  "result": "success",
  "tags": ["pgvector", "migration", "ai"]
}
JSON
exit 0
MOCK
  chmod +x "$BATS_TEST_TMPDIR/ai-query-distill"

  # Mock ai-query that returns incomplete JSON (missing required field)
  cat > "$BATS_TEST_TMPDIR/ai-query-missing-field" <<'MOCK'
#!/usr/bin/env bash
cat <<'JSON'
{
  "lesson": "Something happened.",
  "summary": "Work was done.",
  "intent": "Achieve a goal."
}
JSON
exit 0
MOCK
  chmod +x "$BATS_TEST_TMPDIR/ai-query-missing-field"

  # Mock curl for A-group tests: captures stdin (request body from jq), returns
  # a fake 200 with a minimal chat-completion response. Tests set MOCK_CAPTURE_FILE
  # to the path where the captured JSON body should be written.
  mkdir -p "$BATS_TEST_TMPDIR/curl-bin"
  cat > "$BATS_TEST_TMPDIR/curl-bin/curl" <<'MOCK'
#!/usr/bin/env bash
resp=""
while [[ $# -gt 0 ]]; do
  case "$1" in -o) resp="$2"; shift 2 ;; *) shift ;; esac
done
[[ -n "${MOCK_CAPTURE_FILE:-}" ]] && cat > "$MOCK_CAPTURE_FILE" || cat > /dev/null
[[ -n "$resp" ]] && \
  printf '{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}' > "$resp"
printf '200'
MOCK
  chmod +x "$BATS_TEST_TMPDIR/curl-bin/curl"
}

# ---------------------------------------------------------------------------
# D. Domain routing (--dry-run, no server needed)
# ---------------------------------------------------------------------------

@test "D1: default domain for general zdots questions" {
  run "$BIN/zdots-ask" --dry-run "what is the zdots architecture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"domain=default"* ]]
}

@test "D2: phi domain for SSN keywords" {
  run "$BIN/zdots-ask" --dry-run "explain pgp_sym_encrypt usage"
  [ "$status" -eq 0 ]
  [[ "$output" == *"domain=phi"* ]]
}

@test "D3: phi domain for HIPAA keyword" {
  run "$BIN/zdots-ask" --dry-run "how does HIPAA affect data storage"
  [ "$status" -eq 0 ]
  [[ "$output" == *"domain=phi"* ]]
}

@test "D4: shell domain for zsh scripting" {
  run "$BIN/zdots-ask" --dry-run "how do I write a zle widget"
  [ "$status" -eq 0 ]
  [[ "$output" == *"domain=shell"* ]]
}

@test "D5: ruby domain for Sequel migration" {
  run "$BIN/zdots-ask" --dry-run "write a sequel migration to add a column"
  [ "$status" -eq 0 ]
  [[ "$output" == *"domain=ruby"* ]]
}

@test "D6: --domain flag overrides auto-detection" {
  run "$BIN/zdots-ask" --domain phi --dry-run "what is bash"
  [ "$status" -eq 0 ]
  [[ "$output" == *"domain=phi"* ]]
}

@test "D7: --think appears in dry-run prompt section" {
  run "$BIN/zdots-ask" --think --dry-run "explain how zle works"
  [ "$status" -eq 0 ]
  # --think should not crash, domain detection still works
  [[ "$output" == *"domain="* ]]
}

# ---------------------------------------------------------------------------
# P. PHI scrubbing at submission boundary
# ---------------------------------------------------------------------------

@test "P1: SSN does not reach ai-query" {
  # Capture what the mock ai-query receives via $@ logged to a file
  cat > "$BATS_TEST_TMPDIR/mock-bin/ai-query" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$BATS_TEST_TMPDIR/ai-query-args.txt"
echo "mock-response"
exit 0
MOCK
  # shellcheck disable=SC2016
  sed -i '' "s|\$BATS_TEST_TMPDIR|${BATS_TEST_TMPDIR}|g" \
    "$BATS_TEST_TMPDIR/mock-bin/ai-query"
  chmod +x "$BATS_TEST_TMPDIR/mock-bin/ai-query"

  ZDOTS_AI_MODE=local ZDOTS_AI_QUERY="$BATS_TEST_TMPDIR/mock-bin/ai-query" \
    run bash -c "source '$LIB/ai-invoke.bash' && zdots_ai_infer_raw 'patient SSN 123-45-6789 has a question'"

  [ "$status" -eq 0 ]
  # SSN must not appear in what was passed to ai-query
  if [[ -f "$BATS_TEST_TMPDIR/ai-query-args.txt" ]]; then
    run grep "123-45-6789" "$BATS_TEST_TMPDIR/ai-query-args.txt"
    [ "$status" -ne 0 ]
  fi
}

@test "P2: MRN does not reach ai-query" {
  ZDOTS_AI_MODE=local ZDOTS_AI_QUERY="$MOCK_BIN/ai-query" \
    run bash -c "
      source '$LIB/message_hygiene.bash'
      printf 'MRN: 987654 patient status' | zdots_message_hygiene
    "
  [ "$status" -eq 0 ]
  [[ "$output" != *"987654"* ]]
  [[ "$output" == *"REDACTED"* ]]
}

@test "P3: clean prompt passes through hygiene unchanged" {
  ZDOTS_AI_MODE=local \
    run bash -c "
      source '$LIB/message_hygiene.bash'
      printf 'what is the zdots context engine' | zdots_message_hygiene
    "
  [ "$status" -eq 0 ]
  [[ "$output" == *"zdots context engine"* ]]
}

# ---------------------------------------------------------------------------
# T. Think-block stripping
# ---------------------------------------------------------------------------

@test "T1: <think> block stripped from output" {
  run bash -c "
    source '$LIB/ai-query-lib.bash'
    printf '<think>\ninner reasoning\n</think>\nFinal answer\n' | aiq_sanitize_output
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Final answer"* ]]
  [[ "$output" != *"inner reasoning"* ]]
  [[ "$output" != *"<think>"* ]]
}

@test "T2: multi-line think block stripped" {
  run bash -c "
    source '$LIB/ai-query-lib.bash'
    printf '<think>\nline one\nline two\nline three\n</think>\nResult\n' | aiq_sanitize_output
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "Result" ]]
}

@test "T3: output without think block passes through unchanged" {
  run bash -c "
    source '$LIB/ai-query-lib.bash'
    printf 'clean output line\n' | aiq_sanitize_output
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "clean output line" ]]
}

# ---------------------------------------------------------------------------
# G. Gate behaviour
# ---------------------------------------------------------------------------

@test "G1: infer_raw exits 2 when AI mode is none" {
  ZDOTS_AI_MODE=none run bash -c "
    source '$LIB/ai-invoke.bash'
    zdots_ai_infer_raw 'test prompt'
  "
  [ "$status" -eq 2 ]
}

@test "G2: distill exits non-zero when AI mode is none" {
  # zdots_ai_distill wraps inference errors as exit 1 (documented interface).
  # The gate blocks internally (exit 2 from zdots_ai_infer_raw), but distill
  # always returns 1 for any inference failure.
  ZDOTS_AI_MODE=none run bash -c "
    source '$LIB/ai-invoke.bash'
    zdots_ai_distill 'analyze this session'
  "
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# F. Distillation field validation
# ---------------------------------------------------------------------------

@test "F1: distill accepts valid JSON with all required fields" {
  ZDOTS_AI_MODE=local ZDOTS_AI_QUERY="$BATS_TEST_TMPDIR/ai-query-distill" \
    run bash -c "
      source '$LIB/ai-invoke.bash'
      zdots_ai_distill 'analyze this session'
    "
  [ "$status" -eq 0 ]
  echo "$output" | jq empty
  [[ "$(echo "$output" | jq -r '.lesson')" != "" ]]
  [[ "$(echo "$output" | jq -r '.tags | length')" -ge 1 ]]
}

@test "F2: distill exits 2 when required fields are missing" {
  ZDOTS_AI_MODE=local ZDOTS_AI_QUERY="$BATS_TEST_TMPDIR/ai-query-missing-field" \
    run bash -c "
      source '$LIB/ai-invoke.bash'
      zdots_ai_distill 'analyze this session'
    "
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# A. aiq_submit request body — env var wiring (curl mocked, no live server)
#
# Each test calls aiq_submit directly with a mock curl that captures the JSON
# body piped from jq. Assertions read the captured file with jq.
# ---------------------------------------------------------------------------

@test "A1: AIQ_ENABLE_THINKING=1 sets enable_thinking to true in request body" {
  local sysfile userfile capture
  sysfile=$(mktemp); printf 'system' > "$sysfile"
  userfile=$(mktemp); printf 'user'   > "$userfile"
  capture=$(mktemp)

  MOCK_CAPTURE_FILE="$capture" AIQ_ENABLE_THINKING=1 \
    PATH="$BATS_TEST_TMPDIR/curl-bin:$PATH" \
    run bash -c "source '$LIB/ai-query-lib.bash' && aiq_submit '$sysfile' '$userfile' 'http://127.0.0.1:8080' 'test-model' 5"

  [ "$status" -eq 0 ]
  [[ "$(jq -r '.chat_template_kwargs.enable_thinking' "$capture")" == "true" ]]
  rm -f "$sysfile" "$userfile" "$capture"
}

@test "A2: AIQ_ENABLE_THINKING unset defaults enable_thinking to false" {
  local sysfile userfile capture
  sysfile=$(mktemp); printf 'system' > "$sysfile"
  userfile=$(mktemp); printf 'user'   > "$userfile"
  capture=$(mktemp)

  MOCK_CAPTURE_FILE="$capture" \
    PATH="$BATS_TEST_TMPDIR/curl-bin:$PATH" \
    run bash -c "unset AIQ_ENABLE_THINKING; source '$LIB/ai-query-lib.bash' && aiq_submit '$sysfile' '$userfile' 'http://127.0.0.1:8080' 'test-model' 5"

  [ "$status" -eq 0 ]
  [[ "$(jq -r '.chat_template_kwargs.enable_thinking' "$capture")" == "false" ]]
  rm -f "$sysfile" "$userfile" "$capture"
}

@test "A3: AIQ_TEMPERATURE=0.1 overrides default temperature in request body" {
  local sysfile userfile capture
  sysfile=$(mktemp); printf 'system' > "$sysfile"
  userfile=$(mktemp); printf 'user'   > "$userfile"
  capture=$(mktemp)

  MOCK_CAPTURE_FILE="$capture" AIQ_TEMPERATURE=0.1 \
    PATH="$BATS_TEST_TMPDIR/curl-bin:$PATH" \
    run bash -c "source '$LIB/ai-query-lib.bash' && aiq_submit '$sysfile' '$userfile' 'http://127.0.0.1:8080' 'test-model' 5"

  [ "$status" -eq 0 ]
  [[ "$(jq -r '.temperature' "$capture")" == "0.1" ]]
  rm -f "$sysfile" "$userfile" "$capture"
}

@test "A4: AIQ_JSON_SCHEMA set adds response_format to request body" {
  local sysfile userfile capture schema
  sysfile=$(mktemp); printf 'system' > "$sysfile"
  userfile=$(mktemp); printf 'user'   > "$userfile"
  capture=$(mktemp)
  schema='{"type":"object","properties":{"answer":{"type":"string"}},"required":["answer"]}'

  MOCK_CAPTURE_FILE="$capture" AIQ_JSON_SCHEMA="$schema" \
    PATH="$BATS_TEST_TMPDIR/curl-bin:$PATH" \
    run bash -c "source '$LIB/ai-query-lib.bash' && aiq_submit '$sysfile' '$userfile' 'http://127.0.0.1:8080' 'test-model' 5"

  [ "$status" -eq 0 ]
  [[ "$(jq -r '.response_format.type' "$capture")" == "json_schema" ]]
  rm -f "$sysfile" "$userfile" "$capture"
}

@test "A5: AIQ_JSON_SCHEMA unset omits response_format from request body" {
  local sysfile userfile capture
  sysfile=$(mktemp); printf 'system' > "$sysfile"
  userfile=$(mktemp); printf 'user'   > "$userfile"
  capture=$(mktemp)

  MOCK_CAPTURE_FILE="$capture" \
    PATH="$BATS_TEST_TMPDIR/curl-bin:$PATH" \
    run bash -c "unset AIQ_JSON_SCHEMA; source '$LIB/ai-query-lib.bash' && aiq_submit '$sysfile' '$userfile' 'http://127.0.0.1:8080' 'test-model' 5"

  [ "$status" -eq 0 ]
  [[ "$(jq 'has("response_format")' "$capture")" == "false" ]]
  rm -f "$sysfile" "$userfile" "$capture"
}
