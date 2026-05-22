-- etc/db/migrations/008_autonomous_chaining.sql
-- Implement Job Chaining via triggers

-- 1. Add metadata column for job results
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

-- 2. Trigger function to chain follow-up jobs
CREATE OR REPLACE FUNCTION tr_fn_chain_jobs()
RETURNS TRIGGER AS $$
BEGIN
    -- Only chain when a job enters 'completed' state
    IF OLD.status != 'completed' AND NEW.status = 'completed' THEN
        
        -- Transcription -> Distill
        IF NEW.type = 'transcription' THEN
            -- We propagate the payload (url) and add the source job ID
            INSERT INTO jobs (type, payload, priority, fingerprint)
            VALUES (
                'distill', 
                NEW.payload || jsonb_build_object('source_job_id', NEW.id), 
                NEW.priority,
                md5('distill' || NEW.id::text)
            )
            ON CONFLICT (fingerprint) DO NOTHING;
        END IF;

    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create the trigger
DROP TRIGGER IF EXISTS tr_chain_completed_jobs ON jobs;
CREATE TRIGGER tr_chain_completed_jobs
AFTER UPDATE ON jobs
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'completed')
EXECUTE FUNCTION tr_fn_chain_jobs();
