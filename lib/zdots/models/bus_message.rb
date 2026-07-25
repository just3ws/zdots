# frozen_string_literal: true

require_relative "../db"

module Zdots
  module Models
    # A message in a bus channel. parent_id null = thread root; set = reply.
    class BusMessage < Sequel::Model(Zdots.db[:bus_messages])
      def thread_root?
        parent_id.nil?
      end
    end
  end
end
