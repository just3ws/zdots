#!/usr/bin/env bats
# tests/agent_guide.bats — contract tests for agent-guide's machine-readable output.

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin/agent-guide"
}

@test "agent-guide: --help exits 0 without probing services" {
  run "$BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: agent-guide"* ]]
}

@test "agent-guide: --json emits valid JSON" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  run "$BIN" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq empty
}

@test "agent-guide: --json discovery block lists the zdots.localhost routes" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  run "$BIN" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.discovery.backlog | contains("zdots.localhost/backlog")' >/dev/null
  echo "$output" | jq -e '.discovery.services | contains("zsvc map")' >/dev/null
}

@test "agent-guide: --json mcp.servers includes o2-mcp and backlog" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  run "$BIN" --json
  [ "$status" -eq 0 ]
  names="$(echo "$output" | jq -r '.mcp.servers[].name')"
  [[ "$names" == *"o2-mcp"* ]]
  [[ "$names" == *"backlog"* ]]
}

@test "agent-guide: human output mentions /backlog and zsvc map" {
  run "$BIN"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/backlog"* ]]
  [[ "$output" == *"zsvc map"* ]]
}
