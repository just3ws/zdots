#!/usr/bin/env bats
# tests/imperial_date.bats — Imperial Dating System beacon (decision-007).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  BIN="$REPO_ROOT/bin/imperial-date"
}

@test "imperial-date: stamps the release date 2026-06-14 as 0452026.M3" {
  run "$BIN" 2026-06-14
  [ "$status" -eq 0 ]
  [ "$output" = "0452026.M3" ]
}

@test "imperial-date: format is CFFFYYY.M# (check, fraction, year, millennium)" {
  run "$BIN" 2026-06-14
  [[ "$output" =~ ^[0-9][0-9]{3}[0-9]{3}\.M[0-9]+$ ]]
}

@test "imperial-date: early-month date does not hit the octal trap (008/009)" {
  run "$BIN" 2026-01-08
  [ "$status" -eq 0 ]
  [ "$output" = "0021026.M3" ]
}

@test "imperial-date: decode round-trips within 1 day" {
  stamp="$("$BIN" 2026-06-14)"
  run "$BIN" --decode "$stamp"
  [ "$status" -eq 0 ]
  # ±1 day from the fraction granularity (~8.76h/unit)
  [[ "$output" == 2026-06-1[34]* ]]
}

@test "imperial-date: millennium boundary — 2001 is M3, year 001" {
  run "$BIN" 2001-01-01
  [ "$status" -eq 0 ]
  [ "$output" = "0002001.M3" ]
}

@test "imperial-date: --help exits 0" {
  run "$BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Imperial Dating System"* ]]
}

@test "imperial-date: the VERSION beacon is a well-formed imperial stamp" {
  # The beacon re-stamps at every release (decision-007 §5) — a hardcoded
  # value here failed on every re-stamp (0452026 -> 0526026 -> 0556026).
  # Assert the imperial-CalVer shape instead; drift across peers is
  # zdots-doctor's job, not this suite's.
  run cat "$REPO_ROOT/VERSION"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{7}\.M[0-9]$ ]]
}
