# frozen_string_literal: true

Sequel.migration do
  up do
    run <<~SQL
      DROP FUNCTION IF EXISTS claim_next_job(text, text);
      CREATE OR REPLACE FUNCTION claim_next_job(p_worker_type text, p_trace_id text)
      RETURNS TABLE(id uuid, type text, payload jsonb) AS $$
      DECLARE
        v_job_id uuid;
      BEGIN
        UPDATE jobs
        SET status = 'running',
            trace_id = p_trace_id,
            attempts = attempts + 1,
            updated_at = CURRENT_TIMESTAMP
        WHERE jobs.id = (
          SELECT j.id
          FROM jobs j
          WHERE j.status = 'pending'
            AND (p_worker_type IS NULL OR j.type = p_worker_type)
            AND j.next_run_at <= CURRENT_TIMESTAMP
          ORDER BY j.priority DESC, j.created_at ASC
          FOR UPDATE SKIP LOCKED
          LIMIT 1
        )
        RETURNING jobs.id, jobs.type, jobs.payload INTO v_job_id, type, payload;

        IF v_job_id IS NOT NULL THEN
          id := v_job_id;
          RETURN NEXT;
        END IF;
      END;
      $$ LANGUAGE plpgsql;

      CREATE OR REPLACE FUNCTION fail_job(p_id uuid, p_error text)
      RETURNS void AS $$
      BEGIN
        UPDATE jobs
        SET status = CASE 
                        WHEN attempts >= 5 THEN 'dead'::job_status
                        ELSE 'pending'::job_status
                      END,
            error_message = p_error,
            next_run_at = CURRENT_TIMESTAMP + (INTERVAL '1 minute' * power(2, attempts)),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_id;
      END;
      $$ LANGUAGE plpgsql;

      CREATE OR REPLACE FUNCTION complete_job(p_id uuid)
      RETURNS void AS $$
      BEGIN
        UPDATE jobs
        SET status = 'completed',
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_id;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  down do
    run "DROP FUNCTION IF EXISTS claim_next_job(text, text);"
    run "DROP FUNCTION IF EXISTS fail_job(uuid, text);"
    run "DROP FUNCTION IF EXISTS complete_job(uuid);"
  end
end
