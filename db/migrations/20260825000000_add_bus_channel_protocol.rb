# frozen_string_literal: true

# Channel "engagement protocol" — what's on-topic, what evidence standard
# applies, what NOT to post here. Discoverable in-band (bus-channels,
# bus-read) instead of living only in docs/message-bus.md. Nullable: most
# channels don't need one spelled out beyond their one-line topic.
Sequel.migration do
  up do
    alter_table(:bus_channels) do
      add_column :protocol, String, text: true
    end
  end

  down do
    alter_table(:bus_channels) { drop_column :protocol }
  end
end
