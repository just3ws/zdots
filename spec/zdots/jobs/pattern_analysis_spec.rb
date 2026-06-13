# frozen_string_literal: true

require "spec_helper"
require "sequel"
require "zdots"
require "zdots/jobs/base"
require "zdots/jobs/pattern_analysis"
require "zdots/models/operational_feedback"
require "zdots/models/recommendation"

RSpec.describe Zdots::Jobs::PatternAnalysis, :integration do
  before(:all) do
    @db = Zdots.db
  rescue Sequel::DatabaseConnectionError => e
    skip "PostgreSQL unavailable (#{e.message})"
  end

  around do |example|
    # Clear tables before/after each test
    begin
      Zdots.db[:recommendations].delete
      Zdots.db[:operational_feedback].delete
      example.run
      Zdots.db[:recommendations].delete
      Zdots.db[:operational_feedback].delete
    rescue StandardError
      example.run
    end
  end

  let(:job) { double("job", id: SecureRandom.uuid, payload: {}) }
  let(:pattern_job) { described_class.new(job) }

  describe "#run" do
    it "detects error clustering" do
      # Create 3+ similar errors within 7 days
      3.times do |i|
        Zdots::Models::OperationalFeedback.create(
          report_type: "error",
          severity: "high",
          title: "PHI scrubber timeout on large inputs",
          description: "Hangs when processing >10MB",
          reporter: "agent-#{i}",
          status: "open",
          created_at: Time.now - (i * 86400)  # Spread across days
        )
      end

      result = pattern_job.run

      expect(result).to include(status: "ok")

      # Check that recommendation was created
      recs = Zdots::Models::Recommendation.where(category: "error_cluster")
      expect(recs.count).to be >= 1

      rec = recs.first
      expect(rec.frequency).to eq(3)
      expect(rec.severity).to eq("high")
    end

    it "detects feature request aggregation" do
      # Create 2+ feature requests
      2.times do |i|
        Zdots::Models::OperationalFeedback.create(
          report_type: "request",
          title: "Export lessons to Markdown",
          description: "Would be useful for documentation",
          reporter: "user-#{i}",
          status: "open"
        )
      end

      pattern_job.run

      recs = Zdots::Models::Recommendation.where(category: "feature_request")
      expect(recs.count).to be >= 1

      rec = recs.first
      expect(rec.frequency).to eq(2)
      expect(rec.action).to eq("add_to_backlog")
    end

    it "detects friction patterns" do
      # Create 2+ friction reports
      2.times do |i|
        Zdots::Models::OperationalFeedback.create(
          report_type: "friction",
          title: "Alert system confusing",
          description: "Hard to understand how to silence",
          reporter: "user-#{i}",
          status: "open"
        )
      end

      pattern_job.run

      recs = Zdots::Models::Recommendation.where(category: "friction")
      expect(recs.count).to be >= 1

      rec = recs.first
      expect(rec.action).to eq("improve_docs")
    end

    it "detects cascading failures" do
      # Create error A
      error_a = Zdots::Models::OperationalFeedback.create(
        report_type: "error",
        title: "Credential rotation fails",
        description: "Rotation hangs",
        reporter: "agent-1",
        status: "open"
      )

      # Create error B within 5 minutes
      error_b = Zdots::Models::OperationalFeedback.create(
        report_type: "error",
        title: "DB migration hangs",
        description: "Timeout during migration",
        reporter: "agent-1",
        status: "open",
        created_at: error_a.created_at + 120  # 2 minutes later
      )

      # Repeat pattern
      error_a2 = Zdots::Models::OperationalFeedback.create(
        report_type: "error",
        title: "Credential rotation fails",
        description: "Another rotation",
        reporter: "agent-2",
        status: "open"
      )

      error_b2 = Zdots::Models::OperationalFeedback.create(
        report_type: "error",
        title: "DB migration hangs",
        description: "Another migration timeout",
        reporter: "agent-2",
        status: "open",
        created_at: error_a2.created_at + 180  # 3 minutes later
      )

      pattern_job.run

      recs = Zdots::Models::Recommendation.where(category: "cascade")
      expect(recs.count).to be >= 1

      rec = recs.first
      expect(rec.severity).to eq("high")
      expect(rec.action).to eq("file_bug")
    end
  end

  describe "#normalize_title" do
    it "normalizes title for grouping" do
      title1 = "Error 12345 at 2026-06-12 10:30:00"
      title2 = "ERROR     AT 2026-06-13 09:00:00"

      norm1 = pattern_job.send(:normalize_title, title1)
      norm2 = pattern_job.send(:normalize_title, title2)

      expect(norm1).to eq(norm2)
    end

    it "handles long titles" do
      long_title = "x" * 200

      normalized = pattern_job.send(:normalize_title, long_title)

      expect(normalized.length).to be <= 100
    end
  end

  describe "#severity_rank" do
    it "ranks severities correctly" do
      expect(pattern_job.send(:severity_rank, "critical")).to eq(4)
      expect(pattern_job.send(:severity_rank, "high")).to eq(3)
      expect(pattern_job.send(:severity_rank, "medium")).to eq(2)
      expect(pattern_job.send(:severity_rank, "low")).to eq(1)
      expect(pattern_job.send(:severity_rank, nil)).to eq(0)
    end
  end
end
