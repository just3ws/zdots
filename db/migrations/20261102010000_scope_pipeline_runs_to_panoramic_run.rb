# A canonical source can be reprocessed by distinct Panoramic executions.
# Preserve one stage history per execution, with legacy runs under a nil key.
Sequel.migration do
  up do
    alter_table(:pipeline_runs) do
      add_column :panoramic_run_id, :uuid
    end
    run "DROP INDEX IF EXISTS idx_pipeline_runs_source_stage_chunk"
    run <<~SQL
      CREATE UNIQUE INDEX idx_pipeline_runs_source_stage_chunk_panoramic
      ON pipeline_runs(
        media_source_id,
        stage,
        COALESCE(chunk_index, -1),
        COALESCE(panoramic_run_id, '00000000-0000-0000-0000-000000000000'::uuid)
      )
    SQL
    run "CREATE INDEX idx_pipeline_runs_panoramic_run ON pipeline_runs(panoramic_run_id, stage)"
  end

  down do
    run "DROP INDEX IF EXISTS idx_pipeline_runs_panoramic_run"
    run "DROP INDEX IF EXISTS idx_pipeline_runs_source_stage_chunk_panoramic"
    run "CREATE UNIQUE INDEX idx_pipeline_runs_source_stage_chunk " \
        "ON pipeline_runs(media_source_id, stage, COALESCE(chunk_index, -1))"
    alter_table(:pipeline_runs) do
      drop_column :panoramic_run_id
    end
  end
end
