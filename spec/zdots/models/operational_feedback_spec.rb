# frozen_string_literal: true

require "spec_helper"
require "sequel"
require "zdots"
require "zdots/models/operational_feedback"

RSpec.describe Zdots::Models::OperationalFeedback, :integration do
  before(:all) do
    # Connect to test database
    @db = Zdots.db
  rescue Sequel::DatabaseConnectionError => e
    skip "PostgreSQL unavailable (#{e.message})"
  end

  around do |example|
    # Clear tables before/after each test
    begin
      Zdots.db[:operational_feedback].delete
      example.run
      Zdots.db[:operational_feedback].delete
    rescue StandardError
      example.run
    end
  end

  describe ".create_or_deduplicate" do
    it "creates a new feedback entry" do
      attrs = {
        report_type: "error",
        severity: "high",
        title: "PHI scrubber timeout",
        description: "Hangs on large payloads",
        reporter: "test-agent"
      }

      feedback = described_class.create_or_deduplicate(attrs)
      expect(feedback.id).not_to be_nil
      expect(feedback.title).to eq("PHI scrubber timeout")
      expect(feedback.severity).to eq("high")
    end

    it "returns existing feedback if title matches within dedup window" do
      attrs = {
        report_type: "error",
        severity: "high",
        title: "Same error title",
        description: "First report",
        reporter: "agent-1"
      }

      feedback1 = described_class.create_or_deduplicate(attrs)
      feedback2 = described_class.create_or_deduplicate(attrs)

      expect(feedback1.id).to eq(feedback2.id)
    end

    it "creates separate entries if title differs" do
      attrs1 = {
        report_type: "error",
        severity: "high",
        title: "Error A",
        description: "First error",
        reporter: "agent-1"
      }

      attrs2 = {
        report_type: "error",
        severity: "high",
        title: "Error B",
        description: "Second error",
        reporter: "agent-2"
      }

      feedback1 = described_class.create_or_deduplicate(attrs1)
      feedback2 = described_class.create_or_deduplicate(attrs2)

      expect(feedback1.id).not_to eq(feedback2.id)
    end

    it "ignores case when deduplicating" do
      attrs_lower = {
        report_type: "error",
        severity: "high",
        title: "error message",
        description: "First",
        reporter: "agent-1"
      }

      attrs_upper = {
        report_type: "error",
        severity: "high",
        title: "ERROR MESSAGE",
        description: "Second",
        reporter: "agent-2"
      }

      feedback1 = described_class.create_or_deduplicate(attrs_lower)
      feedback2 = described_class.create_or_deduplicate(attrs_upper)

      expect(feedback1.id).to eq(feedback2.id)
    end
  end

  describe "#priority_score" do
    it "returns higher score for critical severity" do
      critical = described_class.create(
        report_type: "error",
        severity: "critical",
        title: "Critical error",
        reporter: "test"
      )

      high = described_class.create(
        report_type: "error",
        severity: "high",
        title: "High error",
        reporter: "test"
      )

      expect(critical.priority_score).to be > high.priority_score
    end

    it "returns 0.5 for nil severity" do
      feedback = described_class.create(
        report_type: "error",
        title: "No severity",
        reporter: "test"
      )

      expect(feedback.priority_score).to eq(0.5)
    end
  end

  describe ".valid_type?" do
    it "returns true for valid types" do
      expect(described_class.valid_type?("error")).to be true
      expect(described_class.valid_type?("request")).to be true
      expect(described_class.valid_type?("friction")).to be true
    end

    it "returns false for invalid types" do
      expect(described_class.valid_type?("bug")).to be false
      expect(described_class.valid_type?("invalid")).to be false
    end
  end

  describe ".valid_severity?" do
    it "returns true for valid severities" do
      expect(described_class.valid_severity?("low")).to be true
      expect(described_class.valid_severity?("medium")).to be true
      expect(described_class.valid_severity?("high")).to be true
      expect(described_class.valid_severity?("critical")).to be true
    end

    it "returns false for invalid severities" do
      expect(described_class.valid_severity?("urgent")).to be false
      expect(described_class.valid_severity?("unknown")).to be false
    end
  end
end
