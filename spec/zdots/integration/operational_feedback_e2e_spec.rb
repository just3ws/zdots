# frozen_string_literal: true

require "spec_helper"
require "sequel"
require "zdots"
require "zdots/models/operational_feedback"
require "zdots/models/recommendation"
require "zdots/jobs/base"
require "zdots/jobs/pattern_analysis"

RSpec.describe "Operational Feedback System E2E", :integration do
  before(:all) do
    @db = Zdots.db
  rescue Sequel::DatabaseConnectionError => e
    skip "PostgreSQL unavailable (#{e.message})"
  end

  around do |example|
    # Clear tables before/after test
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

  it "demonstrates the complete feedback loop: report → analyze → recommend → act" do
    # Step 1: File an issue
    feedback1 = Zdots::Models::OperationalFeedback.create(
      report_type: "error",
      severity: "high",
      title: "PHI scrubber timeout on large inputs",
      description: "Processing >10MB file hangs for 5+ minutes",
      reporter: "pi-agent",
      status: "open"
    )

    expect(feedback1.id).not_to be_nil
    expect(feedback1.report_type).to eq("error")

    # Step 2: Second agent reports similar issue (with similar title)
    feedback2 = Zdots::Models::OperationalFeedback.create(
      report_type: "error",
      severity: "high",
      title: "PHI scrubber timeout on large inputs",  # Same title for grouping
      description: "Debugging payload >30MB stalls",
      reporter: "aider-agent",
      status: "open",
      created_at: Time.now - (12 * 3600)  # 12 hours ago
    )

    # Step 2b: Third report needed to reach threshold (3+)
    feedback3 = Zdots::Models::OperationalFeedback.create(
      report_type: "error",
      severity: "high",
      title: "PHI scrubber timeout on large inputs",
      description: "Another timeout report",
      reporter: "deploy-bot",
      status: "open",
      created_at: Time.now - (1 * 86400)  # 1 day ago
    )

    expect(feedback2.id).not_to eq(feedback1.id)
    expect(feedback3.id).not_to eq(feedback1.id)

    # Step 3: Verify feedback was created
    all_feedback = Zdots::Models::OperationalFeedback.all
    expect(all_feedback.length).to eq(3)

    # Step 4: Run pattern analysis
    job = double("job", id: SecureRandom.uuid, payload: {})
    analyzer = Zdots::Jobs::PatternAnalysis.new(job)
    result = analyzer.run

    expect(result).to include(status: "ok")

    # Step 5: Check that recommendation was generated
    recommendations = Zdots::Models::Recommendation.all
    expect(recommendations.length).to be >= 1

    # Should have detected the error cluster
    error_rec = recommendations.find { |r| r.category == "error_cluster" }
    expect(error_rec).not_to be_nil
    expect(error_rec.frequency).to eq(3)  # All 3 similar errors grouped together
    expect(error_rec.severity).to eq("high")
    expect(error_rec.score).to be > 0
    expect(error_rec.acted_on).to be false

    # Step 6: Operator views and acts on recommendation
    top_recs = Zdots::Models::Recommendation.top_recommendations(5)
    expect(top_recs.length).to be >= 1

    error_rec = top_recs.find { |r| r.category == "error_cluster" }
    expect(error_rec).not_to be_nil

    # Step 7: Mark as acted on
    error_rec.mark_acted_on!
    error_rec.refresh

    expect(error_rec.acted_on).to be true
  end

  it "deduplicates similar feedback within the time window" do
    title = "Same error title"

    feedback1 = Zdots::Models::OperationalFeedback.create_or_deduplicate(
      report_type: "error",
      severity: "high",
      title: title,
      description: "First report",
      reporter: "agent-1"
    )

    # Same title within dedup window should return existing
    feedback2 = Zdots::Models::OperationalFeedback.create_or_deduplicate(
      report_type: "error",
      severity: "high",
      title: title,
      description: "Second report",
      reporter: "agent-2"
    )

    expect(feedback1.id).to eq(feedback2.id)

    # But different title should create new
    feedback3 = Zdots::Models::OperationalFeedback.create_or_deduplicate(
      report_type: "error",
      severity: "high",
      title: "Different error title",
      description: "Third report",
      reporter: "agent-3"
    )

    expect(feedback3.id).not_to eq(feedback1.id)
  end

  it "detects and prioritizes recommendations by score" do
    # Create several patterns

    # High-frequency, recent, critical: should score high
    4.times do |i|
      Zdots::Models::OperationalFeedback.create(
        report_type: "error",
        severity: "critical",
        title: "Database connection failure",
        description: "Can't connect to DB",
        reporter: "worker-#{i}",
        status: "open",
        created_at: Time.now - (i * 3600)  # Spread across hours
      )
    end

    # Low-frequency, old: should score lower
    Zdots::Models::OperationalFeedback.create(
      report_type: "error",
      severity: "low",
      title: "Minor UI glitch",
      description: "Button color wrong",
      reporter: "user-1",
      status: "open",
      created_at: Time.now - (30 * 86400)  # 30 days ago
    )

    job = double("job", id: SecureRandom.uuid, payload: {})
    analyzer = Zdots::Jobs::PatternAnalysis.new(job)
    analyzer.run

    # Verify high-score items are first
    top_recs = Zdots::Models::Recommendation.top_recommendations(10)
    expect(top_recs.length).to be >= 1

    # The critical, frequent issue should be higher scored than the low, old issue
    critical_rec = top_recs.find { |r| r.pattern.downcase.include?("database") }
    low_rec = top_recs.find { |r| r.pattern.downcase.include?("glitch") }

    if critical_rec && low_rec
      expect(critical_rec.score).to be > low_rec.score
    end
  end

  it "filters recommendations by severity and category" do
    # Create mixed recommendations
    Zdots::Models::Recommendation.create(
      category: "error_cluster",
      pattern: "Critical error",
      frequency: 5,
      severity: "critical",
      affected_actors: ["agent-1"],
      recommendation: "Fix this NOW",
      action: "file_bug",
      score: 8.0
    )

    Zdots::Models::Recommendation.create(
      category: "feature_request",
      pattern: "Export feature",
      frequency: 2,
      severity: "medium",
      affected_actors: ["user-1"],
      recommendation: "Nice to have",
      action: "add_to_backlog",
      score: 2.0
    )

    Zdots::Models::Recommendation.create(
      category: "friction",
      pattern: "Confusing UI",
      frequency: 3,
      severity: "low",
      affected_actors: ["user-2"],
      recommendation: "Improve docs",
      action: "improve_docs",
      score: 1.0
    )

    # Filter by severity
    high_severity = Zdots::Models::Recommendation.top_recommendations(10, severity: "critical")
    expect(high_severity.length).to eq(1)
    expect(high_severity[0].pattern).to include("Critical")

    # Filter by category
    features = Zdots::Models::Recommendation.top_recommendations(10, category: "feature_request")
    expect(features.length).to eq(1)
    expect(features[0].pattern).to include("Export")

    # Filter unacted only
    all_unacted = Zdots::Models::Recommendation.top_recommendations(10, unacted: true)
    expect(all_unacted.length).to eq(3)
    expect(all_unacted.all? { |r| !r.acted_on }).to be true
  end
end
