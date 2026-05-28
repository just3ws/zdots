# frozen_string_literal: true

# Adds shell_hook_metrics table for rare shell hook overhead samples.
# Receives data synced from the SQLite buffer (history.sqlite3 / shell_hook_metrics)
# via `zdots-ctx sync-history`. Enables isolating slow hook branches across sessions.
Sequel.migration do
  up do
    run <<~SQL
      CREATE TABLE IF NOT EXISTS shell_hook_metrics (
        id           BIGSERIAL PRIMARY KEY,
        session_id   TEXT        NOT NULL,
        ts_ms        BIGINT      NOT NULL,
        hook         TEXT        NOT NULL,
        status       TEXT        NOT NULL,
        elapsed_ms   BIGINT      NOT NULL,
        threshold_ms BIGINT      NOT NULL,
        host         TEXT,
        synced_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );

      CREATE UNIQUE INDEX IF NOT EXISTS idx_shell_hook_metrics_dedup
        ON shell_hook_metrics (session_id, ts_ms, hook, status, elapsed_ms, threshold_ms);

      CREATE INDEX IF NOT EXISTS idx_shell_hook_metrics_hook     ON shell_hook_metrics (hook);
      CREATE INDEX IF NOT EXISTS idx_shell_hook_metrics_status   ON shell_hook_metrics (status);
      CREATE INDEX IF NOT EXISTS idx_shell_hook_metrics_elapsed  ON shell_hook_metrics (elapsed_ms);
      CREATE INDEX IF NOT EXISTS idx_shell_hook_metrics_ts       ON shell_hook_metrics (ts_ms);
      CREATE INDEX IF NOT EXISTS idx_shell_hook_metrics_session  ON shell_hook_metrics (session_id);

      GRANT SELECT, INSERT, UPDATE, DELETE ON shell_hook_metrics TO zdots_rw;
      GRANT SELECT ON shell_hook_metrics TO zdots_ro;
      GRANT USAGE, SELECT, UPDATE ON shell_hook_metrics_id_seq TO zdots_rw;
    SQL
  end

  down do
    run <<~SQL
      DROP TABLE IF EXISTS shell_hook_metrics;
    SQL
  end
end
