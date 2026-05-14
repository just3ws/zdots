-- etc/db/migrations/006_vector_schema.sql
-- Add vector columns and indexes for semantic search

-- Only proceed if the vector extension is installed
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector') THEN
        -- Add vector columns (dimension size 3584 based on Qwen2.5-Coder)
        ALTER TABLE methodologies ADD COLUMN IF NOT EXISTS embedding vector(3584);
        ALTER TABLE lessons ADD COLUMN IF NOT EXISTS embedding vector(3584);

        -- Create HNSW indexes for fast cosine similarity (<=>) search
        CREATE INDEX IF NOT EXISTS methodologies_embedding_hnsw_idx ON methodologies USING hnsw (embedding vector_cosine_ops);
        CREATE INDEX IF NOT EXISTS lessons_embedding_hnsw_idx ON lessons USING hnsw (embedding vector_cosine_ops);
    ELSE
        RAISE NOTICE 'pgvector extension not installed. Skipping vector schema migration.';
    END IF;
END $$;
