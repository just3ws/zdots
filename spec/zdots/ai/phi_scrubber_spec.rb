# frozen_string_literal: true

require "spec_helper"
require "zdots/ai/phi_scrubber"

RSpec.describe Zdots::AI::PhiScrubber do
  describe ".call" do
    it "returns clean text unchanged" do
      expect(described_class.call("hello world")).to eq("hello world")
    end

    it "handles nil by treating it as empty string" do
      expect(described_class.call(nil)).to eq("")
    end

    it "redacts SSN pattern" do
      expect(described_class.call("ssn: 123-45-6789")).to include("[REDACTED-SSN]")
      expect(described_class.call("ssn: 123-45-6789")).not_to include("6789")
    end

    it "redacts MRN pattern" do
      expect(described_class.call("MRN: 00912345")).to include("[REDACTED-MRN]")
      expect(described_class.call("MRN:00912345")).to include("[REDACTED-MRN]")
    end

    it "redacts date of birth" do
      expect(described_class.call("DOB: 01/15/1990")).to include("[REDACTED-DOB]")
      expect(described_class.call("Date of Birth: 3-7-85")).to include("[REDACTED-DOB]")
    end

    it "redacts connection strings with credentials" do
      expect(described_class.call("postgresql://user:pass@host/db")).to include("[REDACTED-CONN]")
      expect(described_class.call("redis://admin:secret@127.0.0.1:6379")).to include("[REDACTED-CONN]")
    end

    it "redacts --password flag value" do
      result = described_class.call("psql --password hunter2 -U postgres")
      expect(result).to include("[REDACTED]")
      expect(result).not_to include("hunter2")
    end

    it "redacts --api-key flag value" do
      result = described_class.call("curl --api-key sk-abc123 https://api.example.com")
      expect(result).to include("[REDACTED]")
      expect(result).not_to include("sk-abc123")
    end

    it "applies all patterns in a single pass" do
      input = "ssn: 123-45-6789 and DOB: 01/01/2000"
      result = described_class.call(input)
      expect(result).to include("[REDACTED-SSN]")
      expect(result).to include("[REDACTED-DOB]")
    end
  end
end
