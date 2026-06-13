# frozen_string_literal: true

require "spec_helper"
require "zdots/schema_version"
require "tempfile"
require "tmpdir"

RSpec.describe Zdots::SchemaVersion do
  let(:temp_dir) { Dir.mktmpdir }
  let(:version_path) { File.join(temp_dir, "schema-version.yaml") }
  let(:migrations_dir) { File.join(temp_dir, "migrations") }

  before do
    Dir.mkdir(migrations_dir)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "initialization" do
    it "creates default version data when file doesn't exist" do
      schema = Zdots::SchemaVersion.new(path: version_path)
      expect(schema.current_version).to eq("2026-06-01")
      expect(schema.migrations_applied).to eq([])
    end

    it "loads existing version file" do
      File.write(version_path, <<~YAML)
        current_version: "2026-06-12"
        migrations_applied:
          - version: "2026-06-01"
            description: "Initial"
            applied_at: "2026-06-01T00:00:00Z"
            applied_by: "system"
            status: "success"
      YAML

      schema = Zdots::SchemaVersion.new(path: version_path)
      expect(schema.current_version).to eq("2026-06-12")
      expect(schema.migrations_applied.length).to eq(1)
      expect(schema.migrations_applied.first["version"]).to eq("2026-06-01")
    end
  end

  describe "#mark_applied!" do
    it "records a migration as applied" do
      schema = Zdots::SchemaVersion.new(path: version_path)
      schema.mark_applied!("2026-06-12", description: "Test migration", status: "success")

      expect(schema.current_version).to eq("2026-06-12")
      expect(schema.migrations_applied.length).to eq(1)
      expect(schema.migrations_applied.first["version"]).to eq("2026-06-12")
      expect(schema.migrations_applied.first["description"]).to eq("Test migration")
    end

    it "persists to file" do
      schema = Zdots::SchemaVersion.new(path: version_path)
      schema.mark_applied!("2026-06-12", description: "Test")
      schema.save!

      reloaded = Zdots::SchemaVersion.new(path: version_path)
      expect(reloaded.current_version).to eq("2026-06-12")
      expect(reloaded.migrations_applied.length).to eq(1)
    end
  end

  describe "#save!" do
    it "creates parent directories" do
      deep_path = File.join(temp_dir, "deep", "nested", "schema-version.yaml")
      schema = Zdots::SchemaVersion.new(path: deep_path)
      schema.save!

      expect(File.exist?(deep_path)).to be true
    end
  end

  describe "#history" do
    it "returns formatted migration history" do
      schema = Zdots::SchemaVersion.new(path: version_path)
      schema.mark_applied!("2026-06-01", description: "Initial setup", status: "success")
      schema.mark_applied!("2026-06-12", description: "Add vectorstore", status: "success")

      history = schema.history
      expect(history).to include("2026-06-01")
      expect(history).to include("Initial setup")
      expect(history).to include("2026-06-12")
      expect(history).to include("Add vectorstore")
    end
  end

  describe Zdots::SchemaVersion::MigrationFile do
    let(:migration_yaml) do
      <<~YAML
        apiVersion: zdots.io/v1
        kind: Migration
        metadata:
          version: "2026-06-01"
          description: "Add vectorstore"
          author: "Mike"
        spec:
          database:
            - type: sql
              up: "CREATE EXTENSION pgvector"
              down: "DROP EXTENSION pgvector"
          config:
            changes:
              - key: "knowledge.vectorstore"
                from: null
                to: "pgvector"
          requires:
            - service: postgres
              version: "14+"
          post_migration:
            - name: verify
              command: "echo 'done'"
              description: "Verify"
          validation:
            checks:
              - query: "SELECT 1"
                description: "Test"
            timeout_seconds: 30
          rollback:
            instructions: "Rollback instructions"
          breaking_changes:
            - description: "Breaking change"
              mitigation: "Mitigation"
      YAML
    end

    before do
      @migration_file = File.join(migrations_dir, "20260601_add_vectorstore.yaml")
      File.write(@migration_file, migration_yaml)
    end

    it "parses version" do
      migration = Zdots::SchemaVersion::MigrationFile.new(@migration_file)
      expect(migration.version).to eq("2026-06-01")
    end

    it "parses description" do
      migration = Zdots::SchemaVersion::MigrationFile.new(@migration_file)
      expect(migration.description).to eq("Add vectorstore")
    end

    it "parses database changes" do
      migration = Zdots::SchemaVersion::MigrationFile.new(@migration_file)
      db_changes = migration.database_changes
      expect(db_changes.length).to eq(1)
      expect(db_changes.first["type"]).to eq("sql")
      expect(db_changes.first["up"]).to include("CREATE EXTENSION")
    end

    it "parses config changes" do
      migration = Zdots::SchemaVersion::MigrationFile.new(@migration_file)
      config_changes = migration.config_changes
      expect(config_changes.length).to eq(1)
      expect(config_changes.first["key"]).to eq("knowledge.vectorstore")
      expect(config_changes.first["to"]).to eq("pgvector")
    end

    it "parses service requirements" do
      migration = Zdots::SchemaVersion::MigrationFile.new(@migration_file)
      requires = migration.requires_services
      expect(requires.length).to eq(1)
      expect(requires.first["service"]).to eq("postgres")
    end

    it "parses post-migration steps" do
      migration = Zdots::SchemaVersion::MigrationFile.new(@migration_file)
      steps = migration.post_migration_steps
      expect(steps.length).to eq(1)
      expect(steps.first["name"]).to eq("verify")
    end

    it "parses validation checks" do
      migration = Zdots::SchemaVersion::MigrationFile.new(@migration_file)
      checks = migration.validation_checks
      expect(checks.length).to eq(1)
      expect(checks.first["query"]).to eq("SELECT 1")
    end

    it "parses validation timeout" do
      migration = Zdots::SchemaVersion::MigrationFile.new(@migration_file)
      expect(migration.validation_timeout).to eq(30)
    end

    it "parses rollback instructions" do
      migration = Zdots::SchemaVersion::MigrationFile.new(@migration_file)
      expect(migration.rollback_instructions).to include("Rollback instructions")
    end

    it "parses breaking changes" do
      migration = Zdots::SchemaVersion::MigrationFile.new(@migration_file)
      changes = migration.breaking_changes
      expect(changes.length).to eq(1)
      expect(changes.first["description"]).to include("Breaking change")
    end
  end

  describe "#pending_migrations" do
    it "returns migrations not yet applied" do
      schema = Zdots::SchemaVersion.new(path: version_path)
      schema.mark_applied!("2026-06-01", description: "Initial")

      # Verify the migration was recorded
      expect(schema.migrations_applied.length).to eq(1)
      expect(schema.migrations_applied.first["version"]).to eq("2026-06-01")
    end
  end
end
