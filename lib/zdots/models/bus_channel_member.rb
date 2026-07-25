# frozen_string_literal: true

require_relative "../db"

module Zdots
  module Models
    # Per-participant read cursor for a channel — composite key, no
    # surrogate id. Sequel needs the composite primary key declared
    # explicitly since it can't infer it from the schema alone here.
    class BusChannelMember < Sequel::Model(Zdots.db[:bus_channel_members])
      set_primary_key %i[channel_id participant_id]
      unrestrict_primary_key

      def self.cursor_for(channel_id, participant_id)
        find_or_create(channel_id: channel_id, participant_id: participant_id)
      end
    end
  end
end
