#!/usr/bin/env bats
# tests/cli_contracts.bats — CLI grammar and interface contract tests
#
# Validates the command vocabulary and grammar contract established across
# the three service managers (llama-ctl, otel-collector, local-ci) and the
# orientation tools (agent-guide, capabilities).
#
# Tests are split into two groups:
#   Stateless — no live services required; always run.
#   Live      — require running services; skipped automatically when down.

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"
  AI_ENDPOINT="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:11500}"
  OTEL_ENDPOINT="http://127.0.0.1:4318"
  GRAFANA_URL="http://127.0.0.1:3000"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_service_managers() {
  echo "llama-ctl otel-collector local-ci"
}

_ai_up() {
  curl -sf -m 2 "${AI_ENDPOINT}/health" >/dev/null 2>&1
}

_otel_up() {
  launchctl list com.zdots.otel-collector 2>/dev/null | grep -q '"PID"'
}

_grafana_up() {
  curl -sf -m 2 "${GRAFANA_URL}/api/health" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# --help contract: every service manager responds to --help
# ---------------------------------------------------------------------------

@test "llama-ctl: --help exits 0" {
  run "$BIN/llama-ctl" --help
  [ "$status" -eq 0 ]
}

@test "otel-collector: --help exits 0" {
  run "$BIN/otel-collector" --help
  [ "$status" -eq 0 ]
}

@test "local-ci: --help exits 0" {
  run "$BIN/local-ci" --help
  [ "$status" -eq 0 ]
}

@test "agent-guide: --help exits 0" {
  run "$BIN/agent-guide" --help
  [ "$status" -eq 0 ]
}

@test "docker-reclaim: --help exits 0" {
  run "$BIN/docker-reclaim" --help
  [ "$status" -eq 0 ]
}

@test "docker-reclaim: force prune uses non-interactive colima prune" {
  local stub_bin="$BATS_TEST_TMPDIR/docker-reclaim-stubs"
  mkdir -p "$stub_bin"

  cat > "$stub_bin/docker" <<'EOF'
#!/bin/sh
exit 0
EOF
  cat > "$stub_bin/colima" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$BATS_TEST_TMPDIR/colima-args"
exit 0
EOF
  chmod +x "$stub_bin/docker" "$stub_bin/colima"

  stderr=$(PATH="$stub_bin:$PATH" BATS_TEST_TMPDIR="$BATS_TEST_TMPDIR" "$BIN/docker-reclaim" -f 2>&1 >/dev/null)
  status=$?

  [ "$status" -eq 0 ]
  [[ "$stderr" != *"Broken pipe"* ]]
  [[ "$stderr" != *"[y/N]"* ]]
  grep -q '^prune -f$' "$BATS_TEST_TMPDIR/colima-args"
}

@test "ai-query: --help exits 0" {
  run "$BIN/ai-query" --help
  [ "$status" -eq 0 ]
}

@test "zdots-ctl: --help exits 0" {
  run "$BIN/zdots-ctl" --help
  [ "$status" -eq 0 ]
}

# --help output must go to STDOUT (not STDERR) so it can be piped/paged.
@test "llama-ctl: --help output goes to stdout" {
  stdout=$("$BIN/llama-ctl" --help 2>/dev/null)
  [ -n "$stdout" ]
}

@test "otel-collector: --help output goes to stdout" {
  stdout=$("$BIN/otel-collector" --help 2>/dev/null)
  [ -n "$stdout" ]
}

@test "local-ci: --help output goes to stdout" {
  stdout=$("$BIN/local-ci" --help 2>/dev/null)
  [ -n "$stdout" ]
}

# ---------------------------------------------------------------------------
# Grammar contract: all three service managers share the same lifecycle verbs
# ---------------------------------------------------------------------------

@test "llama-ctl: help lists standard lifecycle verbs" {
  run "$BIN/llama-ctl" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"start"*    ]]
  [[ "$output" == *"stop"*     ]]
  [[ "$output" == *"restart"*  ]]
  [[ "$output" == *"status"*   ]]
  [[ "$output" == *"health"*   ]]
  [[ "$output" == *"logs"*     ]]
  [[ "$output" == *"install"*  ]]
}

@test "otel-collector: help lists standard lifecycle verbs" {
  run "$BIN/otel-collector" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"start"*    ]]
  [[ "$output" == *"stop"*     ]]
  [[ "$output" == *"restart"*  ]]
  [[ "$output" == *"status"*   ]]
  [[ "$output" == *"health"*   ]]
  [[ "$output" == *"logs"*     ]]
  [[ "$output" == *"install"*  ]]
}

@test "local-ci: help lists standard lifecycle verbs" {
  run "$BIN/local-ci" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"start"*    ]]
  [[ "$output" == *"stop"*     ]]
  [[ "$output" == *"restart"*  ]]
  [[ "$output" == *"status"*   ]]
  [[ "$output" == *"health"*   ]]
  [[ "$output" == *"logs"*     ]]
}

# ---------------------------------------------------------------------------
# --json flag: all three service managers advertise --json
# ---------------------------------------------------------------------------

@test "llama-ctl: help mentions --json" {
  run "$BIN/llama-ctl" --help
  [[ "$output" == *"--json"* ]]
}

@test "llama-ctl: chat endpoint is not legacy 8080 or 8090" {
  run "$BIN/llama-ctl" config --json
  [ "$status" -eq 0 ]
  port=$(printf '%s' "$output" | jq -r .port)
  [ "$port" = "11500" ]
  [ "$port" != "8080" ]
  [ "$port" != "8090" ]
}

@test "llama-ctl: embed endpoint is not legacy 8080 or 8090" {
  command -v yq >/dev/null 2>&1 || skip "yq required"
  port=$(yq '.embed_server.port' "$REPO_ROOT/etc/ai-models.yaml")
  [ "$port" = "11501" ]
  [ "$port" != "8080" ]
  [ "$port" != "8090" ]
}

@test "otel-collector: help mentions --json" {
  run "$BIN/otel-collector" --help
  [[ "$output" == *"--json"* ]]
}

@test "local-ci: help mentions --json" {
  run "$BIN/local-ci" --help
  [[ "$output" == *"--json"* ]]
}

@test "agent-guide: help mentions --json" {
  run "$BIN/agent-guide" --help
  [[ "$output" == *"--json"* ]]
}

# ---------------------------------------------------------------------------
# Removed vocabulary: deprecated aliases and renamed commands must not appear
# ---------------------------------------------------------------------------

@test "llama-ctl: 'hydrate' alias removed" {
  run "$BIN/llama-ctl" --help
  [[ "$output" != *"hydrate"* ]]
}

@test "llama-ctl: 'df' subcommand removed (replaced by model-df)" {
  run "$BIN/llama-ctl" --help
  # 'df' must not appear as a standalone word; 'model-df' is the correct name
  [[ "$output" != *"  df  "* ]]
  [[ "$output" != *"  df	"* ]]
  [[ "$output" == *"model-df"* ]]
}

@test "local-ci: 'up' subcommand removed (replaced by start)" {
  run "$BIN/local-ci" --help
  # 'up' must not appear as a subcommand entry
  [[ "$output" != *"  up "* ]]
  [[ "$output" == *"start"* ]]
}

@test "local-ci: 'down' subcommand removed (replaced by stop)" {
  run "$BIN/local-ci" --help
  [[ "$output" != *"  down "* ]]
  [[ "$output" == *"stop"* ]]
}

@test "local-ci: 'otel' sub-manager removed" {
  # The nested otel sub-manager was hidden vocabulary — it should be gone
  run "$BIN/local-ci" otel
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Error handling: unknown subcommands exit non-zero and emit usage to STDERR
# ---------------------------------------------------------------------------

@test "llama-ctl: unknown subcommand exits 1" {
  run "$BIN/llama-ctl" not-a-real-command
  [ "$status" -eq 1 ]
}

@test "llama-ctl: unknown subcommand emits usage to stderr not stdout" {
  stdout=$("$BIN/llama-ctl" not-a-real-command 2>/dev/null || true)
  stderr=$("$BIN/llama-ctl" not-a-real-command 2>&1 >/dev/null || true)
  # Stdout should be empty; usage should be on stderr
  [ -z "$stdout" ]
  [ -n "$stderr" ]
}

@test "otel-collector: unknown subcommand exits 1" {
  run "$BIN/otel-collector" not-a-real-command
  [ "$status" -eq 1 ]
}

@test "otel-collector: unknown subcommand emits usage to stderr not stdout" {
  stdout=$("$BIN/otel-collector" not-a-real-command 2>/dev/null || true)
  stderr=$("$BIN/otel-collector" not-a-real-command 2>&1 >/dev/null || true)
  [ -z "$stdout" ]
  [ -n "$stderr" ]
}

@test "local-ci: unknown subcommand exits 1" {
  run "$BIN/local-ci" not-a-real-command
  [ "$status" -eq 1 ]
}

@test "local-ci: unknown subcommand emits usage to stderr not stdout" {
  stdout=$("$BIN/local-ci" not-a-real-command 2>/dev/null || true)
  stderr=$("$BIN/local-ci" not-a-real-command 2>&1 >/dev/null || true)
  [ -z "$stdout" ]
  [ -n "$stderr" ]
}

# No-argument invocation should also exit non-zero with usage on stderr
@test "llama-ctl: no arguments exits 1" {
  run "$BIN/llama-ctl"
  [ "$status" -eq 1 ]
}

@test "otel-collector: no arguments exits 1" {
  run "$BIN/otel-collector"
  [ "$status" -eq 1 ]
}

@test "local-ci: no arguments exits 1" {
  run "$BIN/local-ci"
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# STDOUT/STDERR discipline: progress messages must not pollute stdout
# Data commands (status, --help) go to stdout; progress (start/stop) to stderr.
# We test this by running status with stderr suppressed and confirming stdout is
# not empty, and running a no-op path with stdout suppressed to check stderr.
# ---------------------------------------------------------------------------

@test "llama-ctl: status output goes to stdout" {
  # status always produces output regardless of server state
  stdout=$("$BIN/llama-ctl" status 2>/dev/null)
  [ -n "$stdout" ]
}

@test "otel-collector: status output goes to stdout" {
  stdout=$("$BIN/otel-collector" status 2>/dev/null)
  [ -n "$stdout" ]
}

@test "local-ci: status output goes to stdout" {
  stdout=$("$BIN/local-ci" status 2>/dev/null || true)
  [ -n "$stdout" ]
}

# ---------------------------------------------------------------------------
# SIGPIPE: piping to head -1 must not produce "Broken pipe" or "write error"
# ---------------------------------------------------------------------------

@test "llama-ctl: no broken pipe error when output truncated" {
  noise=$(bash -c '"$1" --help 2>&1 | head -1 >/dev/null; exit 0' _ "$BIN/llama-ctl")
  [[ "$noise" != *"Broken pipe"*  ]]
  [[ "$noise" != *"write error"*  ]]
  [[ "$noise" != *"broken pipe"*  ]]
}

@test "otel-collector: no broken pipe error when output truncated" {
  noise=$(bash -c '"$1" --help 2>&1 | head -1 >/dev/null; exit 0' _ "$BIN/otel-collector")
  [[ "$noise" != *"Broken pipe"*  ]]
  [[ "$noise" != *"write error"*  ]]
}

@test "local-ci: no broken pipe error when output truncated" {
  noise=$(bash -c '"$1" --help 2>&1 | head -1 >/dev/null; exit 0' _ "$BIN/local-ci")
  [[ "$noise" != *"Broken pipe"*  ]]
  [[ "$noise" != *"write error"*  ]]
}

@test "agent-guide: no broken pipe error when output truncated" {
  noise=$(bash -c '"$1" 2>&1 | head -1 >/dev/null; exit 0' _ "$BIN/agent-guide")
  [[ "$noise" != *"Broken pipe"*  ]]
  [[ "$noise" != *"write error"*  ]]
}

# ---------------------------------------------------------------------------
# Live service contracts — skip automatically when service is not running
# ---------------------------------------------------------------------------

@test "llama-ctl: status --json produces valid JSON" {
  if ! _ai_up; then skip "llama.cpp not running"; fi
  run "$BIN/llama-ctl" status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "llama-ctl: status separates HTTP health from socket presence" {
  run "$BIN/llama-ctl" status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("healthy")' >/dev/null
  echo "$output" | jq -e 'has("http_healthy")' >/dev/null
  echo "$output" | jq -e 'has("socket_listening")' >/dev/null
  [ "$(echo "$output" | jq -r '.healthy == .http_healthy')" = "true" ]
}

@test "llama-ctl: health exits 0 when server is up" {
  if ! _ai_up; then skip "llama.cpp not running"; fi
  run "$BIN/llama-ctl" health
  [ "$status" -eq 0 ]
}

@test "llama-ctl: health --json produces valid JSON" {
  if ! _ai_up; then skip "llama.cpp not running"; fi
  run "$BIN/llama-ctl" health --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "llama-ctl: health --json contains healthy:true" {
  if ! _ai_up; then skip "llama.cpp not running"; fi
  run "$BIN/llama-ctl" health --json
  result=$(echo "$output" | jq -r '.healthy')
  [ "$result" = "true" ]
}

@test "llama-ctl: status --json contains expected keys" {
  if ! _ai_up; then skip "llama.cpp not running"; fi
  run "$BIN/llama-ctl" status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("launchd")' >/dev/null
  echo "$output" | jq -e 'has("healthy")' >/dev/null
  echo "$output" | jq -e 'has("profile")' >/dev/null
  echo "$output" | jq -e 'has("endpoint")' >/dev/null
}

@test "otel-collector: status --json produces valid JSON" {
  if ! _otel_up; then skip "otelcol not running"; fi
  run "$BIN/otel-collector" status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "otel-collector: health exits 0 when collector is up" {
  if ! _otel_up; then skip "otelcol not running"; fi
  run "$BIN/otel-collector" health
  [ "$status" -eq 0 ]
}

@test "otel-collector: health --json produces valid JSON" {
  if ! _otel_up; then skip "otelcol not running"; fi
  run "$BIN/otel-collector" health --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "local-ci: status --json produces valid JSON" {
  if ! _grafana_up; then skip "LGTM stack not running"; fi
  run "$BIN/local-ci" status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "local-ci: health exits 0 when Grafana is up" {
  if ! _grafana_up; then skip "LGTM stack not running"; fi
  run "$BIN/local-ci" health
  [ "$status" -eq 0 ]
}

@test "local-ci: health --json produces valid JSON" {
  if ! _grafana_up; then skip "LGTM stack not running"; fi
  run "$BIN/local-ci" health --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "agent-guide: --json produces valid JSON" {
  run "$BIN/agent-guide" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "agent-guide: --json contains services, ai, otel, env keys" {
  run "$BIN/agent-guide" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.services' >/dev/null
  echo "$output" | jq -e '.ai'       >/dev/null
  echo "$output" | jq -e '.otel'     >/dev/null
  echo "$output" | jq -e '.env'      >/dev/null
}

@test "agent-guide: --json exposes zsvc machine-readable diagnostics" {
  run "$BIN/agent-guide" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.diagnostics.service_health_json == "zsvc health --json"' >/dev/null
  echo "$output" | jq -e '.diagnostics.service_logs_json == "zsvc logs all --json"' >/dev/null
  echo "$output" | jq -e '.docs.service_control | contains("zsvc")' >/dev/null
}

@test "zdots-ctl: unknown subcommand exits 1" {
  run "$BIN/zdots-ctl" not-a-real-command
  [ "$status" -eq 1 ]
}

@test "zdots-ctl: no arguments exits 1" {
  run "$BIN/zdots-ctl"
  [ "$status" -eq 1 ]
}

@test "zdots-ctl: status output goes to stdout" {
  stdout=$("$BIN/zdots-ctl" status 2>/dev/null)
  [ -n "$stdout" ]
}

@test "zdots-ctl: status --json produces valid JSON" {
  run "$BIN/zdots-ctl" status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "zdots-ctl: status --json contains expected keys" {
  run "$BIN/zdots-ctl" status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("colima")'         >/dev/null
  echo "$output" | jq -e 'has("lgtm")'           >/dev/null
  echo "$output" | jq -e 'has("otel_collector")' >/dev/null
  echo "$output" | jq -e 'has("ai_server")'      >/dev/null
  echo "$output" | jq -e 'has("ai_http_healthy")' >/dev/null
  echo "$output" | jq -e 'has("ai_socket_listening")' >/dev/null
  [ "$(echo "$output" | jq -r '.ai_server == .ai_http_healthy')" = "true" ]
}

@test "zdots-ctl: check exits 0 when platform healthy" {
  if ! curl -sf -m 2 http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
    skip "LGTM stack not running"
  fi
  run "$BIN/zdots-ctl" check
  [ "$status" -eq 0 ]
}

@test "zdots-ctl: no broken pipe error when output truncated" {
  noise=$(bash -c '"$1" --help 2>&1 | head -1 >/dev/null; exit 0' _ "$BIN/zdots-ctl")
  [[ "$noise" != *"Broken pipe"* ]]
  [[ "$noise" != *"write error"* ]]
}
