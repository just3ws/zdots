# frozen_string_literal: true

require "spec_helper"
require "sequel"
require "zdots"
require "zdots/models/recommendation"

RSpec.describe Zdots::Models::Recommendation, :integration do
  before(:all) do
    # Connect to test database
    @db = Zdots.db
  rescue Sequel::DatabaseConnectionError => e
    skip "PostgreSQL unavailable (#{e.message})"
  end

  around do |example|
    # Clear tables before/after each test
    begin
      Zdots.db[:recommendations].delete
      example.run
      Zdots.db[:recommendations].delete
    rescue StandardError
      example.run
    end
  end

  describe ".calculate_score" do
    it "returns higher score for high frequency, severity, and affected count" do
      score_high = described_class.calculate_score(
        frequency: 5,
        severity: "high",
        affected_count: 3,
        days_since_first: 7
      )

      score_low = described_class.calculate_score(
        frequency: 1,
        severity: "low",
        affected_count: 1,
        days_since_first: 7
      )

      expect(score_high).to be > score_low
    end

    it "penalizes older issues (more days)" do
      score_recent = described_class.calculate_score(
        frequency: 3,
        severity: "high",
        affected_count: 2,
        days_since_first: 1
      )

      score_old = described_class.calculate_score(
        frequency: 3,
        severity: "high",
        affected_count: 2,
        days_since_first: 30
      )

      expect(score_recent).to be > score_old
    end

    it "caps score at 10.0" do
      score = described_class.calculate_score(
        frequency: 100,
        severity: "critical",
        affected_count: 100,
        days_since_first: 1
      )

      expect(score).to be <= 10.0
    end

    it "defaults days_since_first to 1 if 0" do
      score = described_class.calculate_score(
        frequency: 5,
        severity: "high",
        affected_count: 3,
        days_since_first: 0
      )

      expect(score).to be > 0
    end

    it "uses weight of 0.5 for nil severity" do
      score = described_class.calculate_score(
        frequency: 10,
        severity: nil,
        affected_count: 2,
        days_since_first: 5
      )

      # (10 * 0.5 * 2) / 5 = 2.0
      expect(score).to be_within(0.01).of(2.0)
    end
  end

  describe ".top_recommendations" do
    before do
      # Create test recommendations
      described_class.create(
        category: "error_cluster",
        pattern: "High priority error",
        frequency: 5,
        severity: "high",
        affected_actors: ["agent-1", "agent-2"],
        recommendation: "Fix this now",
        action: "file_bug",
        score: 8.0
      )

      described_class.create(
        category: "feature_request",
        pattern: "Export to CSV",
        frequency: 3,
        severity: "medium",
        affected_actors: ["user-1"],
        recommendation: "Nice to have",
        action: "add_to_backlog",
        score: 2.0
      )

      described_class.create(
        category: "error_cluster",
        pattern: "Low priority error",
        frequency: 1,
        severity: "low",
        affected_actors: ["agent-3"],
        recommendation: "Watch and wait",
        action: "watch",
        score: 0.5,
        acted_on: true
      )
    end

    it "returns recommendations sorted by score descending" do
      recs = described_class.top_recommendations(10)

      expect(recs.length).to eq(3)
      expect(recs[0].score).to eq(8.0)
      expect(recs[1].score).to eq(2.0)
      expect(recs[2].score).to eq(0.5)
    end

    it "filters by severity" do
      recs = described_class.top_recommendations(10, severity: "high")

      expect(recs.length).to eq(1)
      expect(recs[0].severity).to eq("high")
    end

    it "filters by category" do
      recs = described_class.top_recommendations(10, category: "feature_request")

      expect(recs.length).to eq(1)
      expect(recs[0].category).to eq("feature_request")
    end

    it "filters to unacted only when requested" do
      recs = described_class.top_recommendations(10, unacted: true)

      expect(recs.length).to eq(2)
      expect(recs.all? { |r| !r.acted_on }).to be true
    end

    it "respects limit parameter" do
      recs = described_class.top_recommendations(1)

      expect(recs.length).to eq(1)
    end
  end

  describe "#mark_acted_on!" do
    it "sets acted_on to true and updates timestamp" do
      rec = described_class.create(
        category: "error_cluster",
        pattern: "Test pattern",
        frequency: 1,
        severity: "low",
        affected_actors: [],
        recommendation: "Test",
        action: "dismiss",
        score: 1.0
      )

      old_updated_at = rec.updated_at
      sleep 0.1
      rec.mark_acted_on!

      expect(rec.acted_on).to be true
      expect(rec.updated_at).to be > old_updated_at
    end
  end

  describe ".valid_category?" do
    it "returns true for valid categories" do
      expect(described_class.valid_category?("error_cluster")).to be true
      expect(described_class.valid_category?("feature_request")).to be true
      expect(described_class.valid_category?("cascade")).to be true
      expect(described_class.valid_category?("friction")).to be true
      expect(described_class.valid_category?("performance")).to be true
    end

    it "returns false for invalid categories" do
      expect(described_class.valid_category?("invalid")).to be false
    end
  end
end
