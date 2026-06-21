# frozen_string_literal: true

# Z-169: long-video chunking. A chunked raw stage records one pipeline_runs row
# per audio window (chunk_index 0..N-1) plus one whole-stage summary row
# (chunk_index NULL) holding the stitched transcript. Per-chunk rows give
# resumable progress (N/M done) on the existing jobs queue — no media_chunks table.
Sequel.migration do
  up do
    alter_table(:pipeline_runs) do
      add_column :chunk_index, Integer # NULL = whole-stage row; 0..N-1 = per-chunk window
    end

    # Relax one-row-per-stage to allow per-chunk rows. COALESCE(chunk_index,-1)
    # keeps whole-stage rows (NULL→-1) unique while permitting many chunk rows.
    run "DROP INDEX IF EXISTS idx_pipeline_runs_source_stage"
    run "CREATE UNIQUE INDEX IF NOT EXISTS idx_pipeline_runs_source_stage_chunk " \
        "ON pipeline_runs(media_source_id, stage, COALESCE(chunk_index, -1))"
  end

  down do
    run "DROP INDEX IF EXISTS idx_pipeline_runs_source_stage_chunk"
    run "CREATE UNIQUE INDEX IF NOT EXISTS idx_pipeline_runs_source_stage " \
        "ON pipeline_runs(media_source_id, stage)"
    alter_table(:pipeline_runs) { drop_column :chunk_index }
  end
end
