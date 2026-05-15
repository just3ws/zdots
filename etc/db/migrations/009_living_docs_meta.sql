-- etc/db/migrations/009_living_docs_meta.sql
-- Tracking for the Living Docs pipeline

ALTER TABLE session_residue ADD COLUMN IF NOT EXISTS processed_into_docs_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS session_residue_processed_idx ON session_residue (processed_into_docs_at) WHERE processed_into_docs_at IS NULL;
