#!/usr/bin/env bats
# tests/nginx_regen_certs.bats — SAN-list assembly and --prune (Z-325)

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin/nginx-regen-certs"
}

@test "nginx-regen-certs --help lists --prune" {
  run "$BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--prune"* ]]
}

@test "nginx-regen-certs rejects unknown flags" {
  run "$BIN" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "--dry-run resolves a SAN set without changing anything" {
  run "$BIN" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"SANs ("* ]]
  [[ "$output" == *"dry run — nothing changed"* ]]
}

@test "--prune never yields more SANs than the default union" {
  run "$BIN" --dry-run
  [ "$status" -eq 0 ]
  local union_n
  union_n=$(sed -nE 's/.*SANs \(([0-9]+)\).*/\1/p' <<<"$output" | head -1)

  run "$BIN" --dry-run --prune
  [ "$status" -eq 0 ]
  local prune_n
  prune_n=$(sed -nE 's/.*SANs \(([0-9]+)\).*/\1/p' <<<"$output" | head -1)

  [ -n "$union_n" ] && [ -n "$prune_n" ]
  [ "$prune_n" -le "$union_n" ]
}

@test "--prune reports the SANs it drops (skips if cert already clean)" {
  local union_n prune_n
  union_n=$("$BIN" --dry-run 2>&1        | sed -nE 's/.*SANs \(([0-9]+)\).*/\1/p' | head -1)
  prune_n=$("$BIN" --dry-run --prune 2>&1 | sed -nE 's/.*SANs \(([0-9]+)\).*/\1/p' | head -1)
  [ "$prune_n" -lt "$union_n" ] || skip "cert has no stale SANs to prune"

  run "$BIN" --dry-run --prune
  [[ "$output" == *"no longer served:"* ]]
  # dropped count in the report matches the SAN-count delta
  local dropped_n
  dropped_n=$(sed -nE 's/.*dropping ([0-9]+) SAN.*/\1/p' <<<"$output" | head -1)
  [ "$dropped_n" -eq "$((union_n - prune_n))" ]
}
