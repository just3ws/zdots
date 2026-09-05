#!/usr/bin/env bats
# tests/bus_schedule.bats — contract tests for bus-schedule and its discovery contract.

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin/bus-schedule"
  CAP="$REPO_ROOT/bin/capabilities"
}

@test "bus-schedule: --help exits 0" {
  run "$BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: bus-schedule"* ]]
}

@test "bus-schedule: --json emits valid JSON with expected keys" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  run "$BIN" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq empty
  echo "$output" | jq -e '.snapshot_at' >/dev/null
  echo "$output" | jq -e '.observer' >/dev/null
  echo "$output" | jq -e '.busdriver' >/dev/null
  echo "$output" | jq -e '.channels' >/dev/null
}

@test "bus-schedule: --dump-dir writes ROUTE.md and schedule.json" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  TEST_DIR="$(mktemp -d)"
  run "$BIN" --dump-dir "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/BUS_SCHEDULE.md" ]
  [ -f "$TEST_DIR/bus_schedule.json" ]
  jq empty "$TEST_DIR/bus_schedule.json"
  rm -rf "$TEST_DIR"
}

@test "capabilities: --json advertises message_bus block" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  run "$CAP" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.message_bus.bus_schedule' >/dev/null
  echo "$output" | jq -e '.message_bus.snapshot_dir' >/dev/null
}
