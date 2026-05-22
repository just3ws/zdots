-- etc/db/migrations/001_initial_schema.sql
-- Initial schema for the PostgreSQL Intelligence Suite

-- Enable common extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- Try to enable vector extension if available (non-blocking)
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS vector;
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'vector extension not available, skipping.';
END $$;

-- 1. Methodologies: Preferred ways of working, architectural standards, personal policies.
CREATE TABLE IF NOT EXISTS methodologies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT[] DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Full-text search index for methodologies
CREATE INDEX IF NOT EXISTS methodologies_search_idx ON methodologies USING GIN (to_tsvector('english', title || ' ' || content));

-- 2. Lessons Learnt: Distilled insights from previous sessions, bug fixes, or new knowledge.
CREATE TABLE IF NOT EXISTS lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content TEXT NOT NULL,
    context TEXT, -- The problem being solved or the situation
    tags TEXT[] DEFAULT '{}',
    source_trace_id TEXT, -- Link back to OTel trace if available
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Full-text search index for lessons
CREATE INDEX IF NOT EXISTS lessons_search_idx ON lessons USING GIN (to_tsvector('english', content || ' ' || coalesce(context, '')));

-- 3. Session Residue: Summaries of significant shell sessions.
CREATE TABLE IF NOT EXISTS session_residue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trace_id TEXT UNIQUE,
    summary TEXT,
    intent TEXT,
    result TEXT,
    command_count INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Schema version tracking
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO schema_migrations (version) VALUES (1) ON CONFLICT (version) DO NOTHING;
