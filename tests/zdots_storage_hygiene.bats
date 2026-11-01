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

@test "zdots-storage: applies the configurable primary-volume reserve" {
  run env ZDOTS_STORAGE_RESERVE_GB=999 zdots-storage --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.disk_reserve_gb')" = "999" ]
  [ "$(echo "$output" | jq -r '.root_status')" = "warn" ]
}

@test "zdots-storage: counts the my repository backup directory" {
  local my_root="$BATS_TEST_TMPDIR/my"
  mkdir -p "$my_root/backups"
  printf 'test backup metadata\n' > "$my_root/backups/test.sql.gz"

  run env ZDOTS_MY_ROOT="$my_root" zdots-storage --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.buckets.backups.my_bytes')" -gt 0 ]
}

@test "zdots-storage: rejects an invalid reserve setting" {
  run env ZDOTS_STORAGE_RESERVE_GB=unlimited zdots-storage --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"must be a non-negative integer"* ]]
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
