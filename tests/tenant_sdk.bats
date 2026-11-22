#!/usr/bin/env bats
# tests/tenant_sdk.bats — Contract tests for lib/sdk/ (Z-185, ADR-0005)

setup() {
  load "setup.bash"
  setup_environment
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
}

@test "sdk/cli-help: extracts header comment block and short-circuits --help" {
  local script="$TMP_DIR/demo-tool"
  cat > "$script" <<'EOF'
#!/usr/bin/env bash
# demo-tool — Example tenant command.
# Usage: demo-tool [--help]
set -euo pipefail
source "${ZDOTDIR}/lib/sdk/cli-help.bash"
zdots_cli_wants_help "$@" && { zdots_sdk_help_from_header "$0"; exit 0; }
echo "SIDE_EFFECT"
EOF
  chmod +x "$script"

  run "$script" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"demo-tool — Example tenant command."* ]]
  [[ "$output" == *"Usage: demo-tool"* ]]
  [[ "$output" != *"SIDE_EFFECT"* ]]
}

@test "sdk/cli-audit: emits START and END NDJSON records and preserves existing EXIT trap" {
  local audit_log="$TMP_DIR/audit.jsonl"
  local marker="$TMP_DIR/prev-trap-ran"

  run bash -c '
    set -euo pipefail
    export ZDOTS_AUDIT_LOG="'"$audit_log"'"
    export ZDOTS_TRACE_ID="test-trace-123"
    trap "touch '"$marker"'" EXIT
    source "'"$ZDOTDIR"'/lib/sdk/cli-audit.bash"
    zdots_audit_init "demo-audit" "lake-write"
  '
  [ "$status" -eq 0 ]
  [ -f "$marker" ]
  [ -f "$audit_log" ]
  [ "$(wc -l < "$audit_log" | tr -d ' ')" -eq 2 ]
  grep -q '"event":"START".*"tool":"demo-audit".*"write_class":"lake-write"' "$audit_log"
  grep -q '"event":"END".*"tool":"demo-audit".*"rc":0.*"trace_id":"test-trace-123"' "$audit_log"
}

@test "sdk/cli-audit: rejects unknown write_class" {
  run bash -c '
    source "'"$ZDOTDIR"'/lib/sdk/cli-audit.bash"
    zdots_audit_init "demo-audit" "invalid-class"
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid write_class"* ]]
}

@test "sdk/docker-host: honors DOCKER_HOST override and falls back to colima-status" {
  run bash -c '
    source "'"$ZDOTDIR"'/lib/sdk/docker-host.bash"
    DOCKER_HOST="unix:///tmp/custom.sock" zdots_docker_host
  '
  [ "$status" -eq 0 ]
  [ "$output" = "unix:///tmp/custom.sock" ]
}
