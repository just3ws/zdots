#!/usr/bin/env bats
# tests/zdots_storage_hygiene.bats — CLI contract tests for zdots-storage and zdots-hygiene

setup() {
  load "setup.bash"
  setup_environment
}

# ── zdots-storage interface contract ──────────────────────────────────────────

@test "zdots-storage: --help exits 0" {
  run zdots-storage --help
  [ "$status" -eq 0 ]
}

@test "zdots-storage: outputs human readable summary" {
  run zdots-storage
  [ "$status" -eq 0 ]
  [[ "$output" =~ "System Storage Buckets" ]]
  [[ "$output" =~ "Models:" ]]
}

@test "zdots-storage: --json outputs valid json with expected schema" {
  run zdots-storage --json
  [ "$status" -eq 0 ]
  local root_status
  root_status=$(echo "$output" | jq -r '.root_status')
  [ "$root_status" != "null" ]
  local models_status
  models_status=$(echo "$output" | jq -r '.buckets.models.status')
  [ "$models_status" != "null" ]
}

# ── zdots-hygiene interface contract ──────────────────────────────────────────

@test "zdots-hygiene: --help exits 0" {
  run zdots-hygiene --help
  [ "$status" -eq 0 ]
}

@test "zdots-hygiene: default mode is dry run" {
  run zdots-hygiene
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dry run" ]]
  [[ "$output" =~ "Candidate Evictions" ]]
}

@test "zdots-hygiene: unknown option exits non-zero" {
  run zdots-hygiene --invalid-flag
  [ "$status" -ne 0 ]
}
