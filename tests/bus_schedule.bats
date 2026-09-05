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
  echo "$output" | jq -e '.message_bus.cli' >/dev/null
}

@test "bus: --help exits 0 and shows fluent DSL grammar" {
  BUS="$REPO_ROOT/bin/bus"
  run "$BUS" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"The Fluent Command-Line Interface for the Local Message Bus"* ]]
  [[ "$output" == *"bus stops"* ]]
  [[ "$output" == *"bus sign"* ]]
}

@test "bus: sign displays the policy contract" {
  BUS="$REPO_ROOT/bin/bus"
  run "$BUS" sign
  [ "$status" -eq 0 ]
  [[ "$output" == *"TAP ON THE SIGN"* ]]
  [[ "$output" == *"INFORMATIVE ONLY — ZERO SIDE-EFFECTS"* ]]
}

@test "bus: driver ping responds" {
  BUS="$REPO_ROOT/bin/bus"
  run "$BUS" driver ping
  [ "$status" -eq 0 ]
  [[ "$output" == *"busdriver"* ]]
}

@test "bus: default invocation outputs schedule" {
  BUS="$REPO_ROOT/bin/bus"
  run "$BUS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"The Local Message Bus Schedule & Route Guide"* ]]
}
