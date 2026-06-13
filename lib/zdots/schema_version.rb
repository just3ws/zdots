# frozen_string_literal: true

require "yaml"
require "pathname"
require "time"
require "fileutils"

module Zdots
  class SchemaVersion
    SCHEMA_VERSION_PATH = Pathname.new("~/.zdots/schema-version.yaml").expand_path
    MIGRATIONS_PATH = Pathname.new(__dir__).parent.parent / "db" / "migrations"

    def initialize(path: SCHEMA_VERSION_PATH)
      @path = Pathname.new(path)
      load_version_file
    end

    # Get the current schema version
    def current_version
      @version_data["current_version"] || "2026-06-01"
    end

    # Get all applied migrations
    def migrations_applied
      @version_data["migrations_applied"] || []
    end

    # Get list of pending migrations
    def pending_migrations
      applied_versions = Set.new(migrations_applied.map { |m| m["version"] })

      available_migrations.reject do |migration|
        applied_versions.include?(migration.version)
      end
    end

    # Get all available migrations from disk
    def available_migrations
      return [] unless MIGRATIONS_PATH.exist?

      Dir.glob("#{MIGRATIONS_PATH}/202601*.yaml").sort.map do |path|
        MigrationFile.new(path)
      end
    end

    # Mark a migration as applied
    def mark_applied!(version, description: "", status: "success")
      @version_data["current_version"] = version
      @version_data["migrations_applied"] ||= []

      @version_data["migrations_applied"] << {
        "version" => version,
        "description" => description,
        "applied_at" => Time.now.iso8601,
        "applied_by" => ENV.fetch("USER", "system"),
        "status" => status
      }

      save!
    end

    # Save version file to disk
    def save!
      FileUtils.mkdir_p(@path.parent) unless @path.parent.exist?
      File.write(@path, YAML.dump(@version_data))
    end

    # Get migration history as text
    def history
      migrations_applied.map do |migration|
        "#{migration['version']} — #{migration['description']} (#{migration['status']}) by #{migration['applied_by']} at #{migration['applied_at']}"
      end.join("\n")
    end

    private

    def load_version_file
      if @path.exist?
        @version_data = YAML.safe_load(File.read(@path), permitted_classes: [Symbol]) || {}
      else
        @version_data = {
          "current_version" => "2026-06-01",
          "migrations_applied" => []
        }
      end
    end

    # Helper class to parse migration files
    class MigrationFile
      attr_reader :path

      def initialize(path)
        @path = Pathname.new(path)
        @data = YAML.safe_load(File.read(path), permitted_classes: [Symbol]) || {}
      end

      def version
        @data.dig("metadata", "version") || File.basename(@path, ".yaml").split("_").first
      end

      def description
        @data.dig("metadata", "description") || ""
      end

      def database_changes
        @data.dig("spec", "database") || []
      end

      def config_changes
        @data.dig("spec", "config", "changes") || []
      end

      def requires_services
        @data.dig("spec", "requires") || []
      end

      def post_migration_steps
        @data.dig("spec", "post_migration") || []
      end

      def validation_checks
        @data.dig("spec", "validation", "checks") || []
      end

      def validation_timeout
        @data.dig("spec", "validation", "timeout_seconds") || 300
      end

      def rollback_instructions
        @data.dig("spec", "rollback", "instructions") || ""
      end

      def breaking_changes
        @data.dig("spec", "breaking_changes") || []
      end

      def raw_data
        @data
      end
    end
  end
end
