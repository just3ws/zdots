#!/usr/bin/env bats
# tests/cmd_analytics.bats — Command analytics capture: PHI boundary + Redis drain

setup() {
  load "setup.bash"
  setup_environment
}

# ---------------------------------------------------------------------------
# _zca_redact — PHI boundary for analytics capture
# ---------------------------------------------------------------------------

@test "cmd_analytics: _zca_redact suppresses conn_string — returns non-zero" {
  run zsh -c '
    ZDOTS_CMD_ANALYTICS=1
    _ZCA_INIT=1
    ZDOTDIR="'"$ZDOTDIR"'"
    source '"$ZDOTDIR"'/conf.d/56-cmd-analytics.zsh
    _zca_redact "psql postgresql://user:pass@host/db"
    printf "exit:%d\n" $?
  '
  [[ "$output" == *"exit:1"* ]]
  [[ "$output" != *"pass"* ]]
}

@test "cmd_analytics: _zca_redact redacts cli_credentials" {
  run zsh -c '
    ZDOTS_CMD_ANALYTICS=1
    _ZCA_INIT=1
    ZDOTDIR="'"$ZDOTDIR"'"
    source '"$ZDOTDIR"'/conf.d/56-cmd-analytics.zsh
    result=$(_zca_redact "psql --password secretval mydb")
    printf "%s\n" "$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"secretval"* ]]
}

@test "cmd_analytics: _zca_redact passes clean command through" {
  run zsh -c '
    ZDOTS_CMD_ANALYTICS=1
    _ZCA_INIT=1
    ZDOTDIR="'"$ZDOTDIR"'"
    source '"$ZDOTDIR"'/conf.d/56-cmd-analytics.zsh
    _zca_redact "git status"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "git status" ]]
}

# ---------------------------------------------------------------------------
# _zca_precmd — suppress path clears the pending command
# ---------------------------------------------------------------------------

@test "cmd_analytics: precmd clears _ZCA_CMD on suppressed command" {
  run zsh -c '
    zmodload zsh/mathfunc 2>/dev/null || true
    ZDOTS_CMD_ANALYTICS=1
    _ZCA_INIT=1
    ZDOTS_REDIS_PORT=1
    ZDOTDIR="'"$ZDOTDIR"'"
    source '"$ZDOTDIR"'/conf.d/56-cmd-analytics.zsh
    _ZCA_CMD="psql postgresql://user:pass@host/db"
    _ZCA_START=$EPOCHREALTIME
    _ZCA_CWD=/tmp
    ZDOTS_LAST_EXIT=0
    _zca_precmd
    printf "cmd:%s\n" "$_ZCA_CMD"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "cmd:" ]]
}

# ---------------------------------------------------------------------------
# Cross-layer: analytics hook reads PHI patterns from registry
# ---------------------------------------------------------------------------

@test "cmd_analytics: cross-layer — analytics hook uses registry suppress pattern" {
  run zsh -c '
    ZDOTS_CMD_ANALYTICS=1
    _ZCA_INIT=1
    ZDOTDIR="'"$ZDOTDIR"'"
    source '"$ZDOTDIR"'/conf.d/56-cmd-analytics.zsh
    _zca_redact "psql postgresql://user:pass@host/db"
    printf "exit:%d\n" $?
  '
  [[ "$output" == *"exit:1"* ]]
}

@test "cmd_analytics: cross-layer — analytics hook uses registry credential pattern" {
  run zsh -c '
    ZDOTS_CMD_ANALYTICS=1
    _ZCA_INIT=1
    ZDOTDIR="'"$ZDOTDIR"'"
    source '"$ZDOTDIR"'/conf.d/56-cmd-analytics.zsh
    result=$(_zca_redact "curl https://api.example.com --api-key token123")
    printf "%s\n" "$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"token123"* ]]
}

# ---------------------------------------------------------------------------
# _drain_redis_to_sqlite — extracted from bin/zdots-ctx via sed
# ---------------------------------------------------------------------------

_drain_setup() {
  # Skip if required tools are unavailable
  redis-cli ping >/dev/null 2>&1 || skip "Redis not available"
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  # Temp state dir matching XDG_STATE_HOME layout
  _DRAIN_STATE=$(mktemp -d)
  mkdir -p "$_DRAIN_STATE/zdots"
  _DRAIN_DB="$_DRAIN_STATE/zdots/history.sqlite3"

  sqlite3 "$_DRAIN_DB" "
    PRAGMA journal_mode=WAL;
    CREATE TABLE IF NOT EXISTS command_runs (
      id          INTEGER PRIMARY KEY,
      session_id  TEXT    NOT NULL,
      ts          INTEGER NOT NULL,
      cwd         TEXT,
      cmd         TEXT    NOT NULL,
      args        TEXT,
      exit_code   INTEGER,
      duration_ms INTEGER,
      profile     TEXT,
      imported_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
    );
  "
}

@test "drain: no-ops silently when Redis is unreachable" {
  _drain_setup
  run bash -c "
    _svc_log() { :; }
    XDG_STATE_HOME='$_DRAIN_STATE'
    ZDOTS_REDIS_HOST=127.0.0.1
    ZDOTS_REDIS_PORT=1
    eval \"\$(sed -n '/^_drain_redis_to_sqlite/,/^}/p' '$ZDOTDIR/bin/zdots-ctx')\"
    _drain_redis_to_sqlite
    printf 'exit:%d\n' \$?
  "
  rm -rf "$_DRAIN_STATE"
  [[ "$output" == *"exit:0"* ]]
}

@test "drain: transfers entries from Redis to SQLite" {
  _drain_setup
  local session_key="zdots:cmds:bats-drain-$$"
  local entry
  entry=$(jq -cn '{session_id:"bats-test",ts:1234567890,cwd:"/tmp",cmd:"git",args:"status",exit_code:0,duration_ms:42,profile:"test"}')
  printf '%s\n' "$entry" | redis-cli -x RPUSH "$session_key" >/dev/null

  run bash -c "
    _svc_log() { :; }
    XDG_STATE_HOME='$_DRAIN_STATE'
    eval \"\$(sed -n '/^_drain_redis_to_sqlite/,/^}/p' '$ZDOTDIR/bin/zdots-ctx')\"
    _drain_redis_to_sqlite
    sqlite3 '$_DRAIN_DB' 'SELECT count(*) FROM command_runs;'
  "
  # Cleanup in case test fails
  redis-cli DEL "$session_key" >/dev/null 2>&1 || true
  rm -rf "$_DRAIN_STATE"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "drain: deletes Redis key on success" {
  _drain_setup
  local session_key="zdots:cmds:bats-del-$$"
  local entry
  entry=$(jq -cn '{session_id:"bats-del",ts:1234567891,cwd:"/tmp",cmd:"ls",args:"",exit_code:0,duration_ms:5,profile:"test"}')
  printf '%s\n' "$entry" | redis-cli -x RPUSH "$session_key" >/dev/null

  bash -c "
    _svc_log() { :; }
    XDG_STATE_HOME='$_DRAIN_STATE'
    eval \"\$(sed -n '/^_drain_redis_to_sqlite/,/^}/p' '$ZDOTDIR/bin/zdots-ctx')\"
    _drain_redis_to_sqlite
  "

  run redis-cli EXISTS "$session_key"
  redis-cli DEL "$session_key" >/dev/null 2>&1 || true
  rm -rf "$_DRAIN_STATE"
  [ "$output" -eq 0 ]
}

@test "drain: no-ops on empty Redis list" {
  _drain_setup
  local session_key="zdots:cmds:bats-empty-$$"
  # Create key with empty list (RPUSH then immediately DEL to get 0-length key)
  # Actually, just don't push anything — KEYS scan returns nothing for this session
  run bash -c "
    _svc_log() { :; }
    XDG_STATE_HOME='$_DRAIN_STATE'
    eval \"\$(sed -n '/^_drain_redis_to_sqlite/,/^}/p' '$ZDOTDIR/bin/zdots-ctx')\"
    _drain_redis_to_sqlite
    sqlite3 '$_DRAIN_DB' 'SELECT count(*) FROM command_runs;'
  "
  rm -rf "$_DRAIN_STATE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}
