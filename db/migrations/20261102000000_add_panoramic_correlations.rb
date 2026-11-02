# Cross-system correlation references are separate from canonical media identity.
# One media source may participate in multiple business journeys over time.
Sequel.migration do
  up do
    create_table?(:panoramic_correlations) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      foreign_key :media_source_id, :media_sources, type: :uuid, null: false, on_delete: :cascade
      uuid :journey_id, null: false
      uuid :run_id, null: false, unique: true
      uuid :correlation_id, null: false
      varchar :workflow_id, size: 120, null: false
      varchar :flow_id, size: 120, null: false
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
    run "CREATE INDEX IF NOT EXISTS idx_panoramic_correlations_journey ON panoramic_correlations(journey_id, created_at)"
    run "CREATE INDEX IF NOT EXISTS idx_panoramic_correlations_source ON panoramic_correlations(media_source_id)"
    run "GRANT SELECT, INSERT, UPDATE ON panoramic_correlations TO zdots_rw"
    run "GRANT SELECT ON panoramic_correlations TO zdots_ro"
  end

  down do
    drop_table?(:panoramic_correlations)
  end
end
