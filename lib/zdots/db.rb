# frozen_string_literal: true

require "sequel"
require "dotenv"
require_relative "db_url"

# Z-280: model classes bind their tables at require time
# (Sequel::Model(Zdots.db[:t]) issues a probe SELECT when the class is
# defined). With this true (the default), code shipped ahead of its migration
# crash-loops every consumer at BOOT — pre-telemetry, visible only to launchd
# (the 2026-07-28 worker storm). False defers the failure to first USE, inside
# the worker's per-job rescue. The cmd_worker boot guard names the pending
# migration explicitly.
Sequel::Model.require_valid_table = false

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
