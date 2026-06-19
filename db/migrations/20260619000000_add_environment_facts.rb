# frozen_string_literal: true

Sequel.migration do
  up do
    create_table?(:environment_facts) do
      serial :id, primary_key: true
      varchar :fact_key, size: 255, null: false
      jsonb :fact_value, null: false
      varchar :source, size: 50, default: "scan_script"  # scan_script | manual
      timestamptz :recorded_at, null: false
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS idx_environment_facts_key ON environment_facts(fact_key)"
    run "CREATE INDEX IF NOT EXISTS idx_environment_facts_recorded ON environment_facts(recorded_at DESC)"

    run "GRANT SELECT, INSERT, UPDATE ON environment_facts TO zdots_rw"
    run "GRANT SELECT ON environment_facts TO zdots_ro"
    run "GRANT USAGE, SELECT ON SEQUENCE environment_facts_id_seq TO zdots_rw"
  end

  down do
    drop_table?(:environment_facts)
  end
end
