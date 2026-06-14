#!/usr/bin/env bats
# tests/history_intelligence.bats — Seam ⑦ synthesis layer
#
# Covers: --help contract, JSON schema, PHI accountability surface, hook slow
# detection, command failure inference, --gate exit code, and graceful
# degradation when the db/tables/atuin are absent. All tests run against a
# synthetic temp db (never the real history) and pass --no-atuin so they are
# deterministic and PHI-free.

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin/history-intelligence"

  DB="$BATS_TEST_TMPDIR/hist.sqlite3"
  sqlite3 "$DB" <<SQL
CREATE TABLE shell_hook_metrics (id INTEGER PRIMARY KEY, session_id TEXT, ts_ms INTEGER, hook TEXT, status TEXT, elapsed_ms INTEGER, threshold_ms INTEGER, host TEXT, imported_at INTEGER);
CREATE TABLE command_runs (id INTEGER PRIMARY KEY, session_id TEXT, ts INTEGER, cwd TEXT, cmd TEXT, args TEXT, exit_code INTEGER, duration_ms INTEGER, profile TEXT, imported_at INTEGER);
INSERT INTO shell_hook_metrics (session_id,ts_ms,hook,status,elapsed_ms,threshold_ms,host) VALUES
 ('s1', (strftime('%s','now')*1000), 'phi-history','clean', 5, 1, 'h'),
 ('s1', (strftime('%s','now')*1000), 'phi-history','clean', 256, 1, 'h'),
 ('s1', (strftime('%s','now')*1000), 'phi-history','scrub_failure', 6, 1, 'h'),
 ('s1', (strftime('%s','now')*1000), 'phi-history','scrub_failure', 7, 1, 'h');
INSERT INTO command_runs (session_id,ts,cwd,cmd,args,exit_code,duration_ms,profile) VALUES
 ('s1', strftime('%s','now'), '/x','zdots-doctor','',1, 120,'home'),
 ('s1', strftime('%s','now'), '/x','zdots-doctor','',1, 90,'home'),
 ('s1', strftime('%s','now'), '/x','zdots-doctor','',0, 80,'home');
SQL
}

run_hi() { run "$BIN" --db "$DB" --no-atuin --no-color "$@"; }

@test "hi: --help exits 0 and prints usage" {
  run "$BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage:"* ]]
}

@test "hi: --json emits the declared schema" {
  run_hi --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.schema == "zdots.history-intelligence.v1"' >/dev/null
}

@test "hi: PHI accountability counts scrub_failure events" {
  run_hi --json
  printf '%s\n' "$output" | jq -e '.phi_accountability.scrub_failure == 2' >/dev/null
  printf '%s\n' "$output" | jq -e '.phi_accountability.total_dropped == 2' >/dev/null
}

@test "hi: scrub_failure raises a high-severity phi signal" {
  run_hi --json
  printf '%s\n' "$output" | jq -e '
    [.signals[] | select(.kind == "phi" and .severity == "high")] | length == 1
  ' >/dev/null
}

@test "hi: --gate exits non-zero when a high signal is present" {
  run_hi --gate --json
  [ "$status" -eq 1 ]
}

@test "hi: --gate exits 0 when no high signal (clean db)" {
  CLEAN="$BATS_TEST_TMPDIR/clean.sqlite3"
  sqlite3 "$CLEAN" "CREATE TABLE shell_hook_metrics (id INTEGER PRIMARY KEY, session_id TEXT, ts_ms INTEGER, hook TEXT, status TEXT, elapsed_ms INTEGER, threshold_ms INTEGER, host TEXT, imported_at INTEGER); INSERT INTO shell_hook_metrics (session_id,ts_ms,hook,status,elapsed_ms,threshold_ms,host) VALUES ('s',(strftime('%s','now')*1000),'phi-history','clean',5,1,'h');"
  run "$BIN" --db "$CLEAN" --no-atuin --no-color --gate --json
  [ "$status" -eq 0 ]
}

@test "hi: slow hook over floor raises a performance signal" {
  run_hi --json
  printf '%s\n' "$output" | jq -e '
    [.signals[] | select(.kind == "performance")] | length >= 1
  ' >/dev/null
}

@test "hi: --slow-ms above the outlier suppresses the performance signal" {
  run_hi --json --slow-ms 500
  printf '%s\n' "$output" | jq -e '
    [.signals[] | select(.kind == "performance")] | length == 0
  ' >/dev/null
}

@test "hi: recurring command failure raises a reliability signal" {
  run_hi --json
  printf '%s\n' "$output" | jq -e '
    [.signals[] | select(.kind == "reliability")]
    | any(.message | test("zdots-doctor"))
  ' >/dev/null
}

@test "hi: --phi --json restricts output to phi accountability + phi signals" {
  run_hi --phi --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e 'has("phi_accountability")' >/dev/null
  printf '%s\n' "$output" | jq -e '.signals | all(.kind == "phi")' >/dev/null
  printf '%s\n' "$output" | jq -e 'has("hook_health") | not' >/dev/null
}

@test "hi: missing db degrades gracefully (exit 0)" {
  run "$BIN" --db "$BATS_TEST_TMPDIR/nope.sqlite3" --no-atuin --no-color
  [ "$status" -eq 0 ]
  [[ "$output" == *"Interface Signals"* ]]
}

@test "hi: empty db (no tables) degrades gracefully" {
  EMPTY="$BATS_TEST_TMPDIR/empty.sqlite3"
  sqlite3 "$EMPTY" "SELECT 1;" >/dev/null
  run "$BIN" --db "$EMPTY" --no-atuin --no-color --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.phi_accountability.available == false' >/dev/null
}

@test "hi: --quiet prints signals but omits detail sections" {
  run_hi --quiet
  [ "$status" -eq 0 ]
  [[ "$output" == *"Interface Signals"* ]]
  [[ "$output" != *"PHI Accountability"* ]]
}

@test "hi: read-only — does not mutate the db" {
  before=$(stat -f '%m' "$DB")
  run_hi --json
  sleep 1
  after=$(stat -f '%m' "$DB")
  [ "$before" = "$after" ]
}
