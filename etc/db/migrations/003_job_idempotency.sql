-- etc/db/migrations/003_job_idempotency.sql
-- Add fingerprint column for idempotent enqueuing

ALTER TABLE jobs ADD COLUMN IF NOT EXISTS fingerprint TEXT;

-- Backfill fingerprints for existing jobs
UPDATE jobs SET fingerprint = md5(type || payload::text) WHERE fingerprint IS NULL;

-- Create unique index
CREATE UNIQUE INDEX IF NOT EXISTS jobs_fingerprint_idx ON jobs (fingerprint);
