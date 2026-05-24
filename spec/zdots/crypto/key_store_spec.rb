# frozen_string_literal: true

require "spec_helper"
require "zdots/crypto/key_store"

RSpec.describe Zdots::Crypto::KeyStore do
  around do |example|
    saved = {
      "ZDOTS_DB_ENCRYPTION_KEY" => ENV["ZDOTS_DB_ENCRYPTION_KEY"],
      "ZDOTS_DB_OLD_KEY"        => ENV["ZDOTS_DB_OLD_KEY"]
    }
    example.run
    saved.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
  end

  describe ".current_key" do
    it "returns the key when set" do
      ENV["ZDOTS_DB_ENCRYPTION_KEY"] = "abc123"
      expect(described_class.current_key).to eq("abc123")
    end

    it "raises KeyError when the variable is unset" do
      ENV.delete("ZDOTS_DB_ENCRYPTION_KEY")
      expect { described_class.current_key }.to raise_error(KeyError, /ZDOTS_DB_ENCRYPTION_KEY/)
    end

    it "raises KeyError when the variable is empty" do
      ENV["ZDOTS_DB_ENCRYPTION_KEY"] = ""
      expect { described_class.current_key }.to raise_error(KeyError, /ZDOTS_DB_ENCRYPTION_KEY/)
    end

    it "raises KeyError when the variable is whitespace only" do
      ENV["ZDOTS_DB_ENCRYPTION_KEY"] = "   "
      expect { described_class.current_key }.to raise_error(KeyError, /ZDOTS_DB_ENCRYPTION_KEY/)
    end
  end

  describe ".rotation_keys" do
    it "returns [old_key, new_key] when both are set and different" do
      ENV["ZDOTS_DB_OLD_KEY"]         = "old-hex-key"
      ENV["ZDOTS_DB_ENCRYPTION_KEY"]  = "new-hex-key"
      old_key, new_key = described_class.rotation_keys
      expect(old_key).to eq("old-hex-key")
      expect(new_key).to eq("new-hex-key")
    end

    it "raises KeyError when ZDOTS_DB_OLD_KEY is unset" do
      ENV.delete("ZDOTS_DB_OLD_KEY")
      ENV["ZDOTS_DB_ENCRYPTION_KEY"] = "new-hex-key"
      expect { described_class.rotation_keys }.to raise_error(KeyError, /ZDOTS_DB_OLD_KEY/)
    end

    it "raises KeyError when old and new keys are identical" do
      ENV["ZDOTS_DB_OLD_KEY"]        = "same-key"
      ENV["ZDOTS_DB_ENCRYPTION_KEY"] = "same-key"
      expect { described_class.rotation_keys }.to raise_error(KeyError, /identical/)
    end

    it "includes remediation hint in the missing-old-key error" do
      ENV.delete("ZDOTS_DB_OLD_KEY")
      ENV["ZDOTS_DB_ENCRYPTION_KEY"] = "new-hex-key"
      expect { described_class.rotation_keys }.to raise_error(KeyError, /ZDOTS_DB_OLD_KEY.*zdots-brain rekey/m)
    end
  end
end
