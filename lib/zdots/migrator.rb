# frozen_string_literal: true

require_relative "../zdots"
require "sequel"

Sequel.extension :migration

module Zdots
  module Migrator
    def self.run
      Zdots.init_otel("zdots-migrator")
      db = Zdots.db
      
      migrations_path = File.expand_path("../../db/migrations", __dir__)
      
      puts "zdots-migrator: applying migrations from #{migrations_path}..."
      
      Sequel::Migrator.run(db, migrations_path, table: :zdots_schema_migrations, use_transactions: true)
      
      puts "zdots-migrator: [ok] all migrations up to date."
    rescue => e
      puts "zdots-migrator: [!!] migration failed: #{e.message}"
      puts e.backtrace.first(10)
      exit 1
    end
  end
end

if __FILE__ == $0
  Zdots::Migrator.run
end
