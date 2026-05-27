# frozen_string_literal: true

# Adds command_runs table for shell command analytics.
# Receives data synced from the SQLite buffer (history.sqlite3 / command_runs)
# via `zdots-ctx sync-history`. Enables cross-session pattern analysis,
# failure rate queries, and sequence mining alongside session_residue / lessons.
Sequel.migration do
  up do
    run <<~SQL
      CREATE TABLE IF NOT EXISTS command_runs (
        id          BIGSERIAL PRIMARY KEY,
        session_id  TEXT        NOT NULL,
        ts          BIGINT      NOT NULL,
        cwd         TEXT,
        cmd         TEXT        NOT NULL,
        args        TEXT,
        exit_code   INTEGER,
        duration_ms INTEGER,
        profile     TEXT,
        host        TEXT,
        synced_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );

      CREATE UNIQUE INDEX IF NOT EXISTS idx_command_runs_dedup
        ON command_runs (session_id, ts, cmd, coalesce(args, ''));

      CREATE INDEX IF NOT EXISTS idx_command_runs_cmd     ON command_runs (cmd);
      CREATE INDEX IF NOT EXISTS idx_command_runs_exit    ON command_runs (exit_code);
      CREATE INDEX IF NOT EXISTS idx_command_runs_ts      ON command_runs (ts);
      CREATE INDEX IF NOT EXISTS idx_command_runs_session ON command_runs (session_id);
      CREATE INDEX IF NOT EXISTS idx_command_runs_cwd     ON command_runs (cwd);
      CREATE INDEX IF NOT EXISTS idx_command_runs_profile ON command_runs (profile);

      -- sync_state: generic key-value cursor store for incremental syncs.
      CREATE TABLE IF NOT EXISTS sync_state (
        key        TEXT        PRIMARY KEY,
        value      TEXT        NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );

      GRANT SELECT, INSERT, UPDATE, DELETE ON command_runs TO zdots_rw;
      GRANT SELECT ON command_runs TO zdots_ro;
      GRANT USAGE, SELECT, UPDATE ON command_runs_id_seq TO zdots_rw;

      GRANT SELECT, INSERT, UPDATE, DELETE ON sync_state TO zdots_rw;
      GRANT SELECT ON sync_state TO zdots_ro;
    SQL
  end

  down do
    run <<~SQL
      DROP TABLE IF EXISTS command_runs;
      DROP TABLE IF EXISTS sync_state;
    SQL
  end
end
