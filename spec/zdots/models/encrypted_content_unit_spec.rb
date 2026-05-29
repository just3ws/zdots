# frozen_string_literal: true

require "spec_helper"
require "sequel"
require "zdots/crypto/key_store"
require "zdots/models/encrypted_content"

RSpec.describe Zdots::Models::EncryptedContent do
  let(:db) { instance_double("DB") }

  before do
    stub_const("EncryptedContentUnitModel", Class.new do
      include Zdots::Models::EncryptedContent

      encrypted_attribute :data

      class << self
        attr_writer :db
      end

      class << self
        attr_reader :db
      end

      def initialize
        @values = {}
      end

      def [](key)
        @values[key]
      end

      def []=(key, value)
        @values[key] = value
      end

      def db
        self.class.db
      end
    end)

    EncryptedContentUnitModel.db = db
    allow(Zdots::Crypto::KeyStore).to receive(:current_key).and_return("unit-test-key")
  end

  it "returns nil without decrypting when the encrypted column is nil" do
    record = EncryptedContentUnitModel.new

    expect(db).not_to receive(:get)
    expect(record.data).to be_nil
  end

  it "decrypts the encrypted column through pgcrypto" do
    record = EncryptedContentUnitModel.new
    record[:data_enc] = "ciphertext"

    expect(db).to receive(:get) do |function|
      expect(function).to be_a(Sequel::SQL::Function)
      expect(function.name).to eq(:pgp_sym_decrypt)
      "plaintext"
    end

    expect(record.data).to eq("plaintext")
  end

  it "stores nil without encrypting" do
    record = EncryptedContentUnitModel.new

    expect(db).not_to receive(:get)
    record.data = nil

    expect(record[:data_enc]).to be_nil
  end

  it "encrypts assigned values through pgcrypto" do
    record = EncryptedContentUnitModel.new

    expect(db).to receive(:get) do |function|
      expect(function).to be_a(Sequel::SQL::Function)
      expect(function.name).to eq(:pgp_sym_encrypt)
      "encrypted-by-db"
    end

    record.data = "sensitive"

    expect(record[:data_enc]).to eq("encrypted-by-db")
  end
end
