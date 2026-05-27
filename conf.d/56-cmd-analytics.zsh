# conf.d/56-cmd-analytics.zsh — Real-time command analytics capture.
#
# Writes every executed command with exit code, duration, CWD, and session
# context. Primary write target is Redis (synchronous, atomic — no race
# condition with zdots-ctx capture). Falls back to async SQLite if Redis is
# unavailable. Feeds zdots-ctx sync-history → PostgreSQL for pattern analysis.
#
# Redis key: zdots:cmds:<session_id>  (list of JSON objects, TTL 24h)
# SQLite fallback: $XDG_STATE_HOME/zdots/history.sqlite3
#
# Enable: set ZDOTS_CMD_ANALYTICS=1 in .zdots.local
# Default: off (0) — enable deliberately after reviewing PHI implications.

[[ "${ZDOTS_CMD_ANALYTICS:-0}" == "1" ]] || return 0

# Eagerly compile PHI patterns — no patterns defined here, all from registry.
if [[ -r "${ZDOTDIR}/lib/phi_scrubber.bash" ]]; then
  source "${ZDOTDIR}/lib/phi_scrubber.bash"
  phi_scrubber_init 2>/dev/null || true
fi

typeset -g _ZCA_DB="${XDG_STATE_HOME:-$HOME/.local/state}/zdots/history.sqlite3"
typeset -g _ZCA_REDIS_HOST="${ZDOTS_REDIS_HOST:-127.0.0.1}"
typeset -g _ZCA_REDIS_PORT="${ZDOTS_REDIS_PORT:-6379}"
typeset -g _ZCA_START=0
typeset -g _ZCA_CMD=""
typeset -g _ZCA_CWD=""

# Create SQLite fallback table once per session in a background process.
if [[ -z "${_ZCA_INIT:-}" ]]; then
  (
    mkdir -p "${_ZCA_DB:h}" 2>/dev/null
    sqlite3 "$_ZCA_DB" >/dev/null 2>&1 <<'SQL'
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
  # Redact via PHI Pattern Registry. Suppress-flagged patterns (conn strings)
  # return non-zero — caller should skip the analytics insert entirely.
  # Pattern source: etc/phi-patterns.yaml. No patterns defined here.
  if phi_should_suppress "$1"; then
    return 1
  fi
  phi_scrub <<< "$1"
}

_zca_sql_esc() {
  local s="$1"
  printf '%s' "${s//\'/\'\'}"
}

# _zca_redis_write — synchronous RPUSH to the session's command list.
# Returns 0 on success, 1 if Redis is unavailable or write fails.
# Requires redis-cli and jq. Key expires after 24h.
_zca_redis_write() {
  local session_id="$1" ts="$2" cwd="$3" cmd="$4" args="$5"
  local exit_code="$6" duration_ms="$7" profile="$8"

  command -v redis-cli >/dev/null 2>&1 || return 1
  command -v jq        >/dev/null 2>&1 || return 1

  local key="zdots:cmds:${session_id}"
  local json
  local filter='{session_id:$session_id,ts:$ts,cwd:$cwd,cmd:$cmd,args:$args,exit_code:$exit_code,duration_ms:$duration_ms,profile:$profile}'
  json=$(jq -cn \
    --arg     session_id  "$session_id"  \
    --argjson ts          "$ts"          \
    --arg     cwd         "$cwd"         \
    --arg     cmd         "$cmd"         \
    --arg     args        "$args"        \
    --argjson exit_code   "$exit_code"   \
    --argjson duration_ms "$duration_ms" \
    --arg     profile     "$profile"     \
    "$filter") || return 1

  printf '%s\n' "$json" \
    | redis-cli -h "$_ZCA_REDIS_HOST" -p "$_ZCA_REDIS_PORT" -x \
        RPUSH "$key" >/dev/null 2>&1 || return 1

  # Set TTL only on first write — EXPIRE is a no-op if key already has one.
  redis-cli -h "$_ZCA_REDIS_HOST" -p "$_ZCA_REDIS_PORT" -q \
    EXPIRE "$key" 86400 >/dev/null 2>&1 || true
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

  # Suppress-check before any computation — suppressed commands do no work.
  local raw
  raw="$(_zca_redact "$_ZCA_CMD")" || { _ZCA_CMD=""; return 0; }

  typeset -i duration_ms=$(( ($EPOCHREALTIME - _ZCA_START) * 1000 ))
  typeset -i ts=$(( $EPOCHREALTIME ))
  local session_id="${ZDOTS_TRACE_ID:-session-$$}"
  local profile="${ZDOTS_ENV_PROFILE:-unknown}"
  local cmd="${raw[(w)1]}"
  local args="${raw#$cmd}"; args="${args## }"

  # Primary: Redis (synchronous — zdots-ctx capture sees a complete list).
  # Fallback: async SQLite (race condition possible if capture runs immediately).
  if ! _zca_redis_write \
       "$session_id" "$ts" "$_ZCA_CWD" "$cmd" "$args" \
       "$exit_code" "$duration_ms" "$profile"; then

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
  fi

  _ZCA_CMD=""
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _zca_preexec
add-zsh-hook precmd  _zca_precmd
