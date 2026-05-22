-- etc/db/migrations/002_jobs_schema.sql
-- Job queue schema for the Side-Effect Broker

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'job_status') THEN
        CREATE TYPE job_status AS ENUM ('pending', 'running', 'completed', 'failed');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type TEXT NOT NULL,
    payload JSONB NOT NULL,
    status job_status DEFAULT 'pending',
    priority INTEGER DEFAULT 10,
    attempts INTEGER DEFAULT 0,
    trace_id TEXT,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS jobs_status_priority_idx ON jobs (status, priority DESC, created_at ASC);
