# frozen_string_literal: true

require_relative "../db"

module Zdots
  module Models
    # A named identity in the message bus — an agent session or a human.
    # Identity is explicit (never inferred from hostname/pid) to avoid
    # silent cross-talk between concurrent sessions.
    class BusParticipant < Sequel::Model(Zdots.db[:bus_participants])
      def self.resolve(name)
        find_or_create(name: name) { |p| p.kind = "agent" }
      end

      def touch_seen!
        update(last_seen_at: Time.now)
      end
    end
  end
end
