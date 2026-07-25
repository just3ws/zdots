# frozen_string_literal: true

require_relative "../db"

module Zdots
  module Models
    # A named topic in the message bus. No timestamps plugin — created_at
    # has a DB-side default and there is no updated_at column to touch.
    class BusChannel < Sequel::Model(Zdots.db[:bus_channels])
      class NotFound < StandardError; end

      def self.resolve(name)
        self[name: name] or raise NotFound, "no such bus channel: #{name.inspect} (create it with: zdots-ctx bus-create-channel #{name})"
      end
    end
  end
end
