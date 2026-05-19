# frozen_string_literal: true

require "sequel"
require "dotenv"

# Load environment variables if not already loaded
Dotenv.load(File.expand_path("../../.env.shared", __dir__))

module Zdots
  module DB
    class << self
      def connect
        @connect ||= begin
          db = Sequel.connect(ENV.fetch("DATABASE_URL", "postgresql:///zdots"))
          db.extension :pg_array, :pg_json
          db
        end
      end

      def logger=(logger)
        connect.loggers << logger
      end
    end
  end
end
