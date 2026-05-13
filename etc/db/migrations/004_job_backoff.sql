-- etc/db/migrations/004_job_backoff.sql
-- Add next_run_at column for exponential backoff

ALTER TABLE jobs ADD COLUMN IF NOT EXISTS next_run_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

-- Backfill next_run_at for existing pending jobs
UPDATE jobs SET next_run_at = CURRENT_TIMESTAMP WHERE status = 'pending' AND next_run_at IS NULL;

-- Create an index to quickly find pending jobs that are ready to run
CREATE INDEX IF NOT EXISTS jobs_next_run_at_idx ON jobs (status, next_run_at ASC, priority DESC) WHERE status = 'pending';
