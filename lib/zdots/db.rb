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
          db = Sequel.connect(ENV.fetch("ZDOTS_DATABASE_URL", "postgresql://zdots_rw@/my"))
          db.extension :pg_array, :pg_json
          db
        end
      end

      def logger=(logger)
        connect.loggers << logger
      end

      def validate!
        db = connect
        missing = %i[jobs lessons methodologies].reject { |t| db.table_exists?(t) }
        return if missing.empty?

        abort <<~MSG
          [zdots] Database misconfiguration detected.
          Connected to: #{db.opts[:database] || db.opts[:host]}  (ZDOTS_DATABASE_URL=#{ENV.fetch('ZDOTS_DATABASE_URL', 'unset')})
          Missing tables: #{missing.join(', ')}

          Fix: ensure ZDOTS_DATABASE_URL points to the 'my' database, then run: zdots-ctx migrate
        MSG
      end
    end
  end
end
