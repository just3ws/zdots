# conf.d/56-cmd-analytics.zsh — Real-time command analytics capture.
#
# Writes every executed command to a SQLite command_runs table with exit code,
# duration, CWD, and session context. Feeds zdots-ctx sync-history → PostgreSQL
# for pattern analysis. No external deps — pure SQLite, never blocks the prompt.
#
# Enable: set ZDOTS_CMD_ANALYTICS=1 in .zdots.local
# Default: off (0) — enable deliberately after reviewing PHI implications.

[[ "${ZDOTS_CMD_ANALYTICS:-0}" == "1" ]] || return 0

typeset -g _ZCA_DB="${XDG_STATE_HOME:-$HOME/.local/state}/zdots/history.sqlite3"
typeset -g _ZCA_START=0
typeset -g _ZCA_CMD=""
typeset -g _ZCA_CWD=""

# Create command_runs table once per session in a background process.
if [[ -z "${_ZCA_INIT:-}" ]]; then
  (
    mkdir -p "${_ZCA_DB:h}" 2>/dev/null
    sqlite3 "$_ZCA_DB" 2>/dev/null <<'SQL'
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
CREATE INDEX IF NOT EXISTS idx_cruns_session  ON command_runs (session_id);
CREATE INDEX IF NOT EXISTS idx_cruns_cmd      ON command_runs (cmd);
CREATE INDEX IF NOT EXISTS idx_cruns_exit     ON command_runs (exit_code);
CREATE INDEX IF NOT EXISTS idx_cruns_ts       ON command_runs (ts);
CREATE INDEX IF NOT EXISTS idx_cruns_cwd      ON command_runs (cwd);
SQL
  ) &!
  typeset -g _ZCA_INIT=1
fi

_zca_redact() {
  # Inline redact matching history-import: mask credential-bearing flags/params.
  # Does not fork unless a sensitive pattern is present.
  local raw="$1"
  if [[ "$raw" =~ '(password|passwd|token|secret|api.?key|access.?token|auth)(=|[[:space:]])' ]]; then
    raw="${raw//${MATCH}*/[REDACTED]}"
  fi
  printf '%s' "$raw"
}

_zca_sql_esc() {
  local s="$1"
  printf '%s' "${s//\'/\'\'}"
}

_zca_preexec() {
  _ZCA_START=$EPOCHREALTIME
  _ZCA_CMD="$1"
  _ZCA_CWD="$PWD"
}

_zca_precmd() {
  # Use ZDOTS_LAST_EXIT (set by 05-observability.zsh precmd which runs first).
  # Fall back to $? for environments where that hook is absent.
  local exit_code="${ZDOTS_LAST_EXIT:-$?}"

  [[ -z "$_ZCA_CMD" ]] && return 0

  local duration_ms=$(( int(($EPOCHREALTIME - _ZCA_START) * 1000) ))
  local ts=$(( int($EPOCHREALTIME) ))
  local session_id="${ZDOTS_TRACE_ID:-session-$$}"
  local profile="${ZDOTS_ENV_PROFILE:-unknown}"

  local raw
  raw="$(_zca_redact "$_ZCA_CMD")"
  local cmd="${raw[(w)1]}"
  local args="${raw#$cmd}"; args="${args## }"

  local db="$_ZCA_DB"
  local session_esc cwd_esc cmd_esc args_esc profile_esc
  session_esc="$(_zca_sql_esc "$session_id")"
  cwd_esc="$(_zca_sql_esc "$_ZCA_CWD")"
  cmd_esc="$(_zca_sql_esc "$cmd")"
  args_esc="$(_zca_sql_esc "$args")"
  profile_esc="$(_zca_sql_esc "$profile")"

  (
    sqlite3 "$db" 2>/dev/null \
      "INSERT INTO command_runs(session_id,ts,cwd,cmd,args,exit_code,duration_ms,profile) \
       VALUES('${session_esc}',${ts},'${cwd_esc}','${cmd_esc}','${args_esc}',${exit_code},${duration_ms},'${profile_esc}');"
  ) &!

  _ZCA_CMD=""
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _zca_preexec
add-zsh-hook precmd  _zca_precmd
