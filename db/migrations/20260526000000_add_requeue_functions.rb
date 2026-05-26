# frozen_string_literal: true

Sequel.migration do
  up do
    run <<~SQL
      -- requeue_job: reset a job to pending so it will be claimed again.
      -- Called by cmd_requeue and cmd_triage in bin/zdots-ctx.
      CREATE OR REPLACE FUNCTION requeue_job(p_id uuid)
      RETURNS void AS $$
      BEGIN
        UPDATE jobs
        SET status        = 'pending',
            attempts      = 0,
            error_message = NULL,
            updated_at    = CURRENT_TIMESTAMP,
            next_run_at   = CURRENT_TIMESTAMP
        WHERE id = p_id;
      END;
      $$ LANGUAGE plpgsql;

      -- clear_stale_jobs: mark running jobs older than p_interval as failed.
      -- Returns the number of jobs updated.
      -- Called by cmd_clear_stale_jobs in bin/zdots-ctx.
      CREATE OR REPLACE FUNCTION clear_stale_jobs(p_interval interval DEFAULT '3 minutes')
      RETURNS integer AS $$
      DECLARE
        v_count integer;
      BEGIN
        UPDATE jobs
        SET status        = 'failed',
            error_message = 'Job timed out or worker crashed (stale for ' || p_interval::text || ')',
            updated_at    = CURRENT_TIMESTAMP
        WHERE status    = 'running'
          AND updated_at < CURRENT_TIMESTAMP - p_interval;

        GET DIAGNOSTICS v_count = ROW_COUNT;
        RETURN v_count;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  down do
    run "DROP FUNCTION IF EXISTS requeue_job(uuid);"
    run "DROP FUNCTION IF EXISTS clear_stale_jobs(interval);"
  end
end
