#!/usr/bin/env bash
# lib/shell_hook_metrics.bash — local storage for slow shell hook metrics.
#
# Records rare, threshold-breaching hook timings into the same SQLite history
# buffer used by command analytics. The row is later synced to PostgreSQL via
# `zdots-ctx sync-history`.

typeset -g _SHM_DB="${XDG_STATE_HOME:-$HOME/.local/state}/zdots/history.sqlite3"

shell_hook_metrics_sql_esc() {
  local s="$1"
  printf '%s' "${s//\'/\'\'}"
}

shell_hook_metrics_record() {
  local hook="$1"
  local metric_status="$2"
  local elapsed_ms="$3"
  local threshold_ms="$4"
  local ts_ms="$5"

  command -v sqlite3 >/dev/null 2>&1 || return 0

  local db="${_SHM_DB}"
  local session_id="${ZDOTS_TRACE_ID:-session-$$}"
  local host="${HOST:-$(hostname 2>/dev/null || echo unknown)}"
  local session_esc hook_esc status_esc host_esc

  session_esc="$(shell_hook_metrics_sql_esc "$session_id")"
  hook_esc="$(shell_hook_metrics_sql_esc "$hook")"
  status_esc="$(shell_hook_metrics_sql_esc "$metric_status")"
  host_esc="$(shell_hook_metrics_sql_esc "$host")"

  mkdir -p "${db%/*}" 2>/dev/null
  sqlite3 "$db" >/dev/null 2>&1 <<SQL
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS shell_hook_metrics (
  id           INTEGER PRIMARY KEY,
  session_id   TEXT    NOT NULL,
  ts_ms        INTEGER NOT NULL,
  hook         TEXT    NOT NULL,
  status       TEXT    NOT NULL,
  elapsed_ms   INTEGER NOT NULL,
  threshold_ms INTEGER NOT NULL,
  host         TEXT,
  imported_at  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
);
CREATE INDEX IF NOT EXISTS idx_shm_hook    ON shell_hook_metrics (hook);
CREATE INDEX IF NOT EXISTS idx_shm_status  ON shell_hook_metrics (status);
CREATE INDEX IF NOT EXISTS idx_shm_elapsed ON shell_hook_metrics (elapsed_ms);
CREATE INDEX IF NOT EXISTS idx_shm_ts      ON shell_hook_metrics (ts_ms);
CREATE INDEX IF NOT EXISTS idx_shm_session ON shell_hook_metrics (session_id);
INSERT INTO shell_hook_metrics(session_id, ts_ms, hook, status, elapsed_ms, threshold_ms, host)
VALUES('${session_esc}', ${ts_ms}, '${hook_esc}', '${status_esc}', ${elapsed_ms}, ${threshold_ms}, '${host_esc}');
SQL
  return 0
}
