# frozen_string_literal: true

# Transcription/ingestion pipeline ledger (Z-164). Durable record of every
# ingested source and its per-stage progress — distinct from the transient
# `jobs` queue, which drives execution. A finished source still shows here.
#
# PHI policy (Z-163, ratified): no patient-identifying plaintext lands here.
# Public sources store their real title/uri; private sources (local/sharepoint)
# store a hash-based source_uri + an operator-supplied non-PHI label in `title`,
# and source_snapshot is filtered to the non-PHI fingerprint set before write.

Sequel.migration do
  up do
    create_table?(:media_sources) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      varchar :source_type, size: 20, null: false        # youtube | vimeo | local | sharepoint
      varchar :source_uri, size: 1024, null: false, unique: true  # canonical id; hash-based for private (never a path)
      varchar :source_id, size: 255                       # yt id | sha256
      varchar :title, size: 500                           # public title, or operator label for private
      integer :duration_sec
      varchar :ingest_status, size: 20, null: false, default: "queued"  # queued | running | done | failed
      jsonb :source_snapshot, null: false, default: Sequel.lit("'{}'::jsonb")  # write-once, non-PHI fingerprint
      timestamptz :captured_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table?(:pipeline_runs) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      foreign_key :media_source_id, :media_sources, type: :uuid, null: false, on_delete: :cascade
      varchar :stage, size: 20, null: false               # raw | cleaned | distilled | landed | promoted
      varchar :status, size: 20, null: false, default: "pending"  # pending | running | done | failed | skipped
      varchar :content_hash, size: 64                     # SHA-256 of stage output (cache/idempotency)
      varchar :artifact_path, size: 1024                  # path in the retention store
      jsonb :run_params, null: false, default: Sequel.lit("'{}'::jsonb")  # model, whisper profile, flags
      text :error_message
      timestamptz :started_at
      timestamptz :finished_at
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS idx_media_sources_status ON media_sources(ingest_status)"
    run "CREATE INDEX IF NOT EXISTS idx_pipeline_runs_source ON pipeline_runs(media_source_id)"
    # one row per stage per source (Z-169 relaxes this when chunk_index arrives)
    run "CREATE UNIQUE INDEX IF NOT EXISTS idx_pipeline_runs_source_stage ON pipeline_runs(media_source_id, stage)"

    # zdots-brain (zdots_rw) writes; the context-engine dashboard (zdots_ro) reads.
    %w[media_sources pipeline_runs].each do |table|
      run "GRANT SELECT, INSERT, UPDATE ON #{table} TO zdots_rw"
      run "GRANT SELECT ON #{table} TO zdots_ro"
    end
  end

  down do
    drop_table?(:pipeline_runs)
    drop_table?(:media_sources)
  end
end
