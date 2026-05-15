# frozen_string_literal: true

Sequel.migration do
  up do
    run 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'
    run 'CREATE EXTENSION IF NOT EXISTS "pg_trgm"'
    run 'CREATE EXTENSION IF NOT EXISTS "unaccent"'
    run 'CREATE EXTENSION IF NOT EXISTS "vector"'

    create_table?(:methodologies) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      text :slug, unique: true, null: false
      text :title, null: false
      text :content, null: false
      column :tags, "text[]", default: Sequel.lit("'{}'::text[]")
      jsonb :metadata, default: Sequel.lit("'{}'::jsonb")
      column :embedding, "vector(3584)"
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS methodologies_search_idx ON methodologies USING GIN (to_tsvector('english', title || ' ' || content))"
    # HNSW/IVFFlat index has a limit of 2000 dimensions. Qwen2.5-Coder (3584) exceeds this.
    # Linear scan is sufficient for small-scale local context.

    create_table?(:lessons) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      text :content, null: false
      text :context
      column :tags, "text[]", default: Sequel.lit("'{}'::text[]")
      text :source_trace_id
      column :embedding, "vector(3584)"
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS lessons_search_idx ON lessons USING GIN (to_tsvector('english', content || ' ' || coalesce(context, '')))"

    run "DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'job_status') THEN CREATE TYPE job_status AS ENUM ('pending', 'running', 'completed', 'failed', 'dead'); END IF; END $$;"

    create_table?(:jobs) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      text :type, null: false
      jsonb :payload, null: false
      column :status, "job_status", default: "pending"
      int :priority, default: 10
      int :attempts, default: 0
      text :trace_id
      text :error_message
      text :fingerprint, unique: true
      timestamptz :next_run_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
      jsonb :metadata, default: Sequel.lit("'{}'::jsonb")
    end

    run "CREATE INDEX IF NOT EXISTS jobs_status_priority_idx ON jobs (status, priority DESC, created_at ASC)"
    run "CREATE INDEX IF NOT EXISTS jobs_next_run_at_idx ON jobs (status, next_run_at ASC, priority DESC) WHERE status = 'pending'"

    create_table?(:session_residue) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      text :trace_id, unique: true
      text :summary
      text :intent
      text :result
      int :command_count, default: 0
      jsonb :metadata, default: Sequel.lit("'{}'::jsonb")
      timestamptz :processed_into_docs_at
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
