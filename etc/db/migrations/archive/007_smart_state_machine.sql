-- etc/db/migrations/007_smart_state_machine.sql
-- PL/pgSQL functions for atomic job state management

-- 1. claim_next_job: Atomically finds, locks, and marks a job as 'running'
CREATE OR REPLACE FUNCTION claim_next_job(p_worker_type TEXT DEFAULT NULL, p_trace_id TEXT DEFAULT NULL)
RETURNS TABLE(id UUID, type TEXT, payload JSONB) AS $$
BEGIN
    RETURN QUERY
    UPDATE jobs
    SET status = 'running',
        updated_at = CURRENT_TIMESTAMP,
        trace_id = p_trace_id
    WHERE jobs.id = (
        SELECT j.id FROM jobs j
        WHERE j.status = 'pending'
          AND j.next_run_at <= CURRENT_TIMESTAMP
          AND (p_worker_type IS NULL OR j.type = p_worker_type)
        ORDER BY j.priority DESC, j.created_at ASC
        FOR UPDATE SKIP LOCKED
        LIMIT 1
    )
    RETURNING jobs.id, jobs.type, jobs.payload;
END;
$$ LANGUAGE plpgsql;

-- 2. fail_job: Increments attempts and calculates exponential backoff or DLQ transition
CREATE OR REPLACE FUNCTION fail_job(p_id UUID, p_error TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE jobs
    SET attempts = attempts + 1,
        error_message = p_error,
        status = CASE 
            WHEN attempts + 1 >= 3 THEN 'dead'::job_status 
            ELSE 'failed'::job_status 
        END,
        updated_at = CURRENT_TIMESTAMP,
        next_run_at = CASE
            WHEN attempts + 1 >= 3 THEN CURRENT_TIMESTAMP
            ELSE CURRENT_TIMESTAMP + make_interval(mins => (POWER(attempts + 1, 2) * 5)::INTEGER)
        END
    WHERE jobs.id = p_id;
END;
$$ LANGUAGE plpgsql;

-- 3. complete_job: Marks a job as completed
CREATE OR REPLACE FUNCTION complete_job(p_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE jobs
    SET status = 'completed',
        updated_at = CURRENT_TIMESTAMP
    WHERE jobs.id = p_id;
END;
$$ LANGUAGE plpgsql;
