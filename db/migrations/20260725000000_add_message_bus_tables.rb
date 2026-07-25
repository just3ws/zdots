# frozen_string_literal: true

# Local message bus for AI-agent collaboration (channels, threaded messages,
# participants). Durable Postgres storage is the source of truth; live
# delivery to anything actively watching happens over Redis pub/sub
# (published by the app layer, not by triggers here) on `bus-post`.
#
# Threading: bus_messages.parent_id is null for a thread root, set for a
# reply — mirrors Slack's thread_ts model without a separate threads table.
# bus_channel_members tracks each participant's last-read cursor per channel
# (the "what's new for me" mechanism), same shape as an unread-count feed.

Sequel.migration do
  up do
    create_table?(:bus_participants) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      varchar :name, size: 255, null: false, unique: true
      varchar :kind, size: 20, null: false, default: "agent" # agent | human
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :last_seen_at
    end

    create_table?(:bus_channels) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      varchar :name, size: 255, null: false, unique: true
      text :topic
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table?(:bus_messages) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      foreign_key :channel_id, :bus_channels, type: :uuid, null: false, on_delete: :cascade
      foreign_key :participant_id, :bus_participants, type: :uuid, null: false
      foreign_key :parent_id, :bus_messages, type: :uuid # null = thread root
      text :body, null: false
      jsonb :metadata, null: false, default: Sequel.lit("'{}'::jsonb")
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table?(:bus_channel_members) do
      foreign_key :channel_id, :bus_channels, type: :uuid, null: false, on_delete: :cascade
      foreign_key :participant_id, :bus_participants, type: :uuid, null: false, on_delete: :cascade
      foreign_key :last_read_message_id, :bus_messages, type: :uuid
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      primary_key %i[channel_id participant_id]
    end

    run "CREATE INDEX IF NOT EXISTS idx_bus_messages_channel_created ON bus_messages(channel_id, created_at)"
    run "CREATE INDEX IF NOT EXISTS idx_bus_messages_parent ON bus_messages(parent_id)"

    %w[bus_participants bus_channels bus_messages bus_channel_members].each do |table|
      run "GRANT SELECT, INSERT, UPDATE ON #{table} TO zdots_rw"
      run "GRANT SELECT ON #{table} TO zdots_ro"
    end
  end

  down do
    drop_table?(:bus_channel_members)
    drop_table?(:bus_messages)
    drop_table?(:bus_channels)
    drop_table?(:bus_participants)
  end
end
