# frozen_string_literal: true

# Switch embedding column from vector(4096) (Qwen3-8B n_embd) to vector(768)
# (Nomic embed-v2 MoE output dimension). Safe: ZDOTS_CAPTURE_ENABLED=0, tables
# are empty, no data loss or reindexing cost.
#
# 768 dims is well under the pgvector HNSW/IVFFlat 2000-dim limit, so we also
# create HNSW indexes here (not possible at 3584/4096 dims — see baseline migration).
Sequel.migration do
  up do
    run "ALTER TABLE methodologies ALTER COLUMN embedding TYPE vector(768)"
    run "ALTER TABLE lessons ALTER COLUMN embedding TYPE vector(768)"
    run "CREATE INDEX IF NOT EXISTS methodologies_embedding_idx ON methodologies USING hnsw (embedding vector_cosine_ops)"
    run "CREATE INDEX IF NOT EXISTS lessons_embedding_idx ON lessons USING hnsw (embedding vector_cosine_ops)"
  end

  down do
    run "DROP INDEX IF EXISTS methodologies_embedding_idx"
    run "DROP INDEX IF EXISTS lessons_embedding_idx"
    run "ALTER TABLE methodologies ALTER COLUMN embedding TYPE vector(4096)"
    run "ALTER TABLE lessons ALTER COLUMN embedding TYPE vector(4096)"
  end
end
