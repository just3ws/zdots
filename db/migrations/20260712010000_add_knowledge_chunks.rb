# frozen_string_literal: true

Sequel.migration do
  up do
    run "CREATE EXTENSION IF NOT EXISTS vector"

    create_table(:knowledge_chunks) do
      uuid :id, default: Sequel.function(:gen_random_uuid), primary_key: true
      uuid :media_source_id, null: false
      Float :start_sec
      Float :end_sec
      String :speaker
      String :content, null: false
      column :embedding, "vector(768)"
      
      DateTime :created_at, default: Sequel.function(:now)
      DateTime :updated_at, default: Sequel.function(:now)

      foreign_key [:media_source_id], :media_sources, key: :id, on_delete: :cascade
      index :media_source_id
    end

    run "CREATE INDEX knowledge_chunks_embedding_hnsw_idx ON knowledge_chunks USING hnsw (embedding vector_cosine_ops)"
  end

  down do
    drop_table(:knowledge_chunks)
  end
end
