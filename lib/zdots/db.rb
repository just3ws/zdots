# frozen_string_literal: true

require "sequel"
require "dotenv"
require_relative "db_url"

# Load environment variables if not already loaded
Dotenv.load(File.expand_path("../../.env.shared", __dir__))

module Zdots
  module DB
    class << self
      def connect
        @connect ||= begin
          db = Sequel.connect(Zdots.database_url)
          db.extension :pg_array, :pg_json
          # pg_array_ops supplies Sequel.pg_array_op — the array-operator DSL
          # (.contains/.overlaps) that media_sources.tags filtering relies on in
          # ingest_media#known_vocabulary and zdots-brain reprocess-series.
          Sequel.extension :pg_array_ops
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
