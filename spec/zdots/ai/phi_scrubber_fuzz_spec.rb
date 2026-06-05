# frozen_string_literal: true

require "spec_helper"
require "zdots/ai/phi_scrubber"

RSpec.describe Zdots::AI::PhiScrubber, "fuzz / property tests" do
  subject(:scrub) { described_class }

  # ---------------------------------------------------------------------------
  # SSN — format variants that MUST be redacted
  # ---------------------------------------------------------------------------

  describe "SSN variants that must be redacted" do
    [
      "000-00-0000",
      "999-99-9999",
      "123-45-6789",
      "Patient SSN is 123-45-6789 per record."
    ].each do |input|
      it "redacts: #{input.inspect[0..60]}" do
        result = scrub.call(input)
        expect(result).to include("[REDACTED-SSN]")
        expect(result).not_to match(/\d{3}-\d{2}-\d{4}/)
      end
    end

    it "redacts multiple SSNs in one string" do
      result = scrub.call("primary: 111-22-3333 spouse: 444-55-6666")
      expect(result).not_to include("111-22-3333")
      expect(result).not_to include("444-55-6666")
      expect(result).to include("[REDACTED-SSN]")
    end
  end

  # ---------------------------------------------------------------------------
  # SSN — near-misses that MUST NOT be redacted
  # ---------------------------------------------------------------------------

  describe "SSN near-misses that must not be redacted" do
    {
      "123-4567-89" => "wrong segmentation",
      "555-867-5309" => "phone number NNN-NNN-NNNN",
      "123456789" => "no dashes",
      "123.45.6789" => "dots not dashes",
      "123-45-678" => "suffix too short"
    }.each do |input, label|
      it "does not redact #{label}: #{input.inspect}" do
        expect(scrub.call(input)).to eq(input)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # MRN — format variants that MUST be redacted
  # ---------------------------------------------------------------------------

  describe "MRN variants that must be redacted" do
    [
      "MRN: 12345",
      "MRN:12345",
      "MRN 99887766",
      "MRN:  99887766",
      "chart lookup MRN: 12345 admitted"
    ].each do |input|
      it "redacts: #{input.inspect}" do
        result = scrub.call(input)
        expect(result).to include("[REDACTED-MRN]")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # MRN — near-misses that MUST NOT be redacted
  # ---------------------------------------------------------------------------

  describe "MRN near-misses that must not be redacted" do
    {
      "mrn: 12345" => "lowercase",
      "MRNX: 12345" => "wrong prefix",
      "MRN: abc" => "letters not digits"
    }.each do |input, label|
      it "does not redact #{label}: #{input.inspect}" do
        expect(scrub.call(input)).to eq(input)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DOB — format variants that MUST be redacted
  # ---------------------------------------------------------------------------

  describe "DOB variants that must be redacted" do
    [
      "DOB: 01/15/1980",
      "DOB: 01-15-1990",
      "DOB: 12/31/99",
      "Date of Birth: 3/7/85",
      "date of Birth: 3/7/85"
    ].each do |input|
      it "redacts: #{input.inspect}" do
        result = scrub.call(input)
        expect(result).to include("[REDACTED-DOB]")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DOB — near-misses that MUST NOT be redacted
  # ---------------------------------------------------------------------------

  describe "DOB near-misses that must not be redacted" do
    {
      "DOB: unknown" => "no date following",
      "dob: 01/01/2000" => "all lowercase"
    }.each do |input, label|
      it "does not redact #{label}: #{input.inspect}" do
        expect(scrub.call(input)).to eq(input)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Connection strings — suppress-flagged: both Ruby and bash fail hard (refuse)
  # rather than redact. Pinned across implementations by phi_contract_spec.rb.
  # ---------------------------------------------------------------------------

  describe "connection string variants that must be suppressed (raise)" do
    [
      "postgresql://user:pass@host/db",
      "mysql://user:pass@host/db",
      "redis://admin:s3cret@127.0.0.1:6379/0"
    ].each do |input|
      it "raises SuppressedError on: #{input.inspect}" do
        expect { scrub.call(input) }
          .to raise_error(Zdots::AI::PhiScrubber::SuppressedError)
        expect(scrub.suppressed?(input)).to be(true)
      end
    end
  end

  it "passes through conn string with no credentials (no @)" do
    input = "postgresql://localhost/mydb"
    expect(scrub.suppressed?(input)).to be(false)
    expect(scrub.call(input)).to eq(input)
  end

  # ---------------------------------------------------------------------------
  # Inline credentials — variants and near-misses
  # ---------------------------------------------------------------------------

  describe "inline credential variants that must be redacted" do
    {
      "api_key=sk-secret123" => "sk-secret123",
      "access_token=ghp_abc123" => "ghp_abc123",
      "access-token=ghp_abc123" => "ghp_abc123",
      "token=abc123secret" => "abc123secret",
      "password=hunter2" => "hunter2",
      "passwd=hunter2" => "hunter2",
      "secret=topsecret" => "topsecret"
    }.each do |input, secret|
      it "redacts inline cred: #{input.inspect}" do
        result = scrub.call(input)
        expect(result).to include("[REDACTED]")
        expect(result).not_to include(secret)
      end
    end
  end

  describe "inline credential near-misses that must not be redacted" do
    it "does not redact tokenizer=" do
      expect(scrub.call("tokenizer=tiktoken")).to eq("tokenizer=tiktoken")
    end

    it "does not redact token with spaces around equals" do
      expect(scrub.call("token = secret123")).to eq("token = secret123")
    end
  end

  # ---------------------------------------------------------------------------
  # CLI credential flags — additional variants
  # ---------------------------------------------------------------------------

  describe "CLI credential flag variants that must be redacted" do
    [
      ["psql --password hunter2 -U postgres", "hunter2"],
      ["curl --api-key sk-abc123 https://api.example.com", "sk-abc123"],
      ["myapp --secret topsecretval", "topsecretval"],
      ["curl --auth bearer:tok", "bearer:tok"],
      ["curl --authorization Bearer:abc123", "abc123"],
      ["mysql -p mypassword mydb", "mypassword"]
    ].each do |input, secret|
      it "redacts: #{input.inspect}" do
        result = scrub.call(input)
        expect(result).to include("[REDACTED]")
        expect(result).not_to include(secret)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------

  describe "edge cases" do
    it "returns empty string for nil" do
      expect(scrub.call(nil)).to eq("")
    end

    it "returns empty string for empty input" do
      expect(scrub.call("")).to eq("")
    end

    it "passes through whitespace-only input" do
      expect(scrub.call("   \t  ")).to eq("   \t  ")
    end

    it "passes through clean input unchanged" do
      clean = "SELECT count(*) FROM users WHERE active = true"
      expect(scrub.call(clean)).to eq(clean)
    end

    it "handles very long clean input (10 KB)" do
      long = "x" * 10_240
      expect(scrub.call(long)).to eq(long)
    end

    it "redacts all pattern types in one blob" do
      input = "SSN: 111-22-3333 MRN: 9876543 DOB: 06/15/1972 api_key=supersecret"
      result = scrub.call(input)
      expect(result).to include("[REDACTED-SSN]")
      expect(result).to include("[REDACTED-MRN]")
      expect(result).to include("[REDACTED-DOB]")
      expect(result).to include("[REDACTED]")
      expect(result).not_to include("111-22-3333")
      expect(result).not_to include("9876543")
      expect(result).not_to include("06/15/1972")
      expect(result).not_to include("supersecret")
    end

    it "replacement token is not re-matched by subsequent patterns" do
      result = scrub.call("123-45-6789")
      expect(result).to eq("[REDACTED-SSN]")
    end
  end
end
