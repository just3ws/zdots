Sequel.migration do
  up do
    create_table?(:speaker_identities) do
      uuid :id, default: Sequel.function(:gen_random_uuid), primary_key: true
      String :name, null: false, unique: true
      column :voiceprint_data, :jsonb
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    unless schema(:media_sources).map(&:first).include?(:speaker_map)
      alter_table(:media_sources) do
        add_column :speaker_map, :jsonb, default: '{}'
      end
    end
  end

  down do
    if schema(:media_sources).map(&:first).include?(:speaker_map)
      alter_table(:media_sources) do
        drop_column :speaker_map
      end
    end
    drop_table?(:speaker_identities)
  end
end
