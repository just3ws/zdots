# frozen_string_literal: true

require "spec_helper"
require "zdots/crypto/key_store"
require "zdots/models/encrypted_content"

# These tests require a running PostgreSQL with pgcrypto installed in the `my`
# database. They are tagged :integration and skipped unless DB_URL is set or
# the `my` DB is available via peer auth.
#
# Run with: bundle exec rspec spec/zdots/models/encrypted_content_spec.rb
#           DATABASE_URL=postgresql:///my bundle exec rspec --tag integration
RSpec.describe Zdots::Models::EncryptedContent, :integration do
  before(:all) do
    require "sequel"
    # DDL requires superuser; use ZDOTS_MIGRATION_URL (peer auth as OS user)
    url = ENV.fetch("DATABASE_URL") { ENV.fetch("ZDOTS_MIGRATION_URL", "postgresql:///my") }
    @db = Sequel.connect(url)
    @db.extension :pg_array
  rescue Sequel::DatabaseConnectionError => e
    skip "PostgreSQL unavailable (#{e.message}) — run with a live DB to enable integration tests"
  end

  # Build a minimal in-test table that exercises EncryptedContent
  before(:all) do
    begin
      @db.run("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    rescue StandardError
      nil
    end
    @db.create_table!(:_enc_test) do
      primary_key :id
      column :data_enc, :bytea
    end

    # Assign a top-level constant so Sequel::Model's internal class name lookup works
    Object.const_set(:EncTest, Class.new(Sequel::Model(@db[:_enc_test])) do
      include Zdots::Models::EncryptedContent

      encrypted_attribute :data
    end)
  end

  after(:all) do
    @db.drop_table?(:_enc_test)
    @db.disconnect
    Object.send(:remove_const, :EncTest) if Object.const_defined?(:EncTest)
  end

  around do |example|
    saved_key = ENV.fetch("ZDOTS_DB_ENCRYPTION_KEY", nil)
    ENV["ZDOTS_DB_ENCRYPTION_KEY"] = "test-key-for-rspec-only"
    example.run
    saved_key ? ENV["ZDOTS_DB_ENCRYPTION_KEY"] = saved_key : ENV.delete("ZDOTS_DB_ENCRYPTION_KEY")
  end

  it "round-trips plaintext through encrypt/decrypt" do
    record = EncTest.create
    record.data = "hello world"
    record.save
    record.reload
    expect(record.data).to eq("hello world")
  end

  it "stores ciphertext in the column (not plaintext)" do
    record = EncTest.create
    record.data = "sensitive value"
    record.save
    raw = @db[:_enc_test].where(id: record.id).get(:data_enc)
    expect(raw.to_s).not_to include("sensitive value")
  end

  it "round-trips unicode content" do
    record = EncTest.create
    record.data = "日本語テスト 🔐"
    record.save
    record.reload
    expect(record.data).to eq("日本語テスト 🔐")
  end

  it "stores nil as nil (no encryption of nulls)" do
    record = EncTest.create
    record.data = nil
    record.save
    record.reload
    expect(record.data).to be_nil
  end

  it "raises KeyError when encryption key is missing" do
    ENV.delete("ZDOTS_DB_ENCRYPTION_KEY")
    record = EncTest.create
    expect { record.data = "value" }.to raise_error(KeyError, /ZDOTS_DB_ENCRYPTION_KEY/)
  end

  it "raises (does not silently fail) when decrypting with wrong key" do
    record = EncTest.create
    record.data = "original"
    record.save

    ENV["ZDOTS_DB_ENCRYPTION_KEY"] = "wrong-key"
    record.reload
    expect { record.data }.to raise_error(Sequel::DatabaseError)
  end
end
