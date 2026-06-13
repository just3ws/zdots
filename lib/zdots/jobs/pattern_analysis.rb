# frozen_string_literal: true

require "sequel"

module Zdots
  module Jobs
    class PatternAnalysis < Base
      # Analyze operational feedback for patterns and generate recommendations
      def run
        clear_old_recommendations
        detect_error_clustering
        detect_feature_requests
        detect_friction_patterns
        detect_cascading_failures
        detect_performance_regressions

        { status: "ok", patterns_found: payload["patterns_count"] || 0 }
      end

      private

      # Clear old, unacted-on recommendations (older than 30 days)
      def clear_old_recommendations
        cutoff = Time.now - (30 * 86400)
        Models::Recommendation.where(Sequel.lit("generated_at < ? AND acted_on = ?", cutoff, false)).delete
      end

      # Error Clustering: Same error N+ times in period T
      def detect_error_clustering
        # Group errors by title (approximate matching)
        cutoff = Time.now - (7 * 86400)
        errors = Models::OperationalFeedback.where(report_type: "error", status: "open")
                                            .where(Sequel.lit("created_at > ?", cutoff))
                                            .all  # Convert to array

        return if errors.empty?

        error_groups = errors.group_by { |e| normalize_title(e.title) }

        error_groups.each do |normalized, issues|
          next unless issues.length >= 3  # Threshold: 3+ occurrences

          severity = issues.map(&:severity).max_by { |s| severity_rank(s) }
          affected = issues.map(&:reporter).uniq.compact
          days_since_first = ((Time.now - issues.min_by(&:created_at).created_at) / 86400).ceil

          score = Models::Recommendation.calculate_score(
            frequency: issues.length,
            severity: severity,
            affected_count: affected.length,
            days_since_first: days_since_first
          )

          Models::Recommendation.create(
            category: "error_cluster",
            pattern: issues.first.title,
            frequency: issues.length,
            severity: severity || "medium",
            affected_actors: affected.to_a,
            recommendation: "Error appearing #{issues.length} times in #{days_since_first} days. Investigate root cause and optimize.",
            action: "file_bug",
            score: score,
            related_issue_id: issues.first.id
          )
        end
      end

      # Feature Request Aggregation: Same feature 2+ times
      def detect_feature_requests
        cutoff = Time.now - (30 * 86400)
        requests = Models::OperationalFeedback.where(report_type: "request", status: "open")
                                              .where(Sequel.lit("created_at > ?", cutoff))
                                              .all  # Convert to array

        return if requests.empty?

        request_groups = requests.group_by { |r| normalize_title(r.title) }

        request_groups.each do |normalized, issues|
          next unless issues.length >= 2  # Threshold: 2+ requests

          affected = issues.map(&:reporter).uniq.compact
          days_since_first = ((Time.now - issues.min_by(&:created_at).created_at) / 86400).ceil

          score = Models::Recommendation.calculate_score(
            frequency: issues.length,
            severity: "medium",
            affected_count: affected.length,
            days_since_first: days_since_first
          )

          Models::Recommendation.create(
            category: "feature_request",
            pattern: issues.first.title,
            frequency: issues.length,
            severity: "medium",
            affected_actors: affected.to_a,
            recommendation: "Feature requested #{issues.length} times. Has demand; estimate effort and prioritize.",
            action: "add_to_backlog",
            score: score,
            related_issue_id: issues.first.id
          )
        end
      end

      # Friction Pattern: User confusion (friction reports + help requests)
      def detect_friction_patterns
        cutoff = Time.now - (14 * 86400)
        friction = Models::OperationalFeedback.where(report_type: "friction", status: "open")
                                              .where(Sequel.lit("created_at > ?", cutoff))
                                              .all  # Convert to array

        return if friction.empty?

        friction_groups = friction.group_by { |f| normalize_title(f.title) }

        friction_groups.each do |normalized, issues|
          next unless issues.length >= 2  # Threshold: 2+ friction reports

          affected = issues.map(&:reporter).uniq.compact
          days_since_first = ((Time.now - issues.min_by(&:created_at).created_at) / 86400).ceil

          score = Models::Recommendation.calculate_score(
            frequency: issues.length,
            severity: "medium",
            affected_count: affected.length,
            days_since_first: days_since_first
          )

          Models::Recommendation.create(
            category: "friction",
            pattern: issues.first.title,
            frequency: issues.length,
            severity: "medium",
            affected_actors: affected.to_a,
            recommendation: "Repeated confusion detected. Consider UX improvement or documentation gap.",
            action: "improve_docs",
            score: score,
            related_issue_id: issues.first.id
          )
        end
      end

      # Cascading Failures: Error X → Error Y within 5 minutes
      def detect_cascading_failures
        cutoff = Time.now - (14 * 86400)
        errors = Models::OperationalFeedback.where(report_type: "error", status: "open")
                                            .where(Sequel.lit("created_at > ?", cutoff))
                                            .order(:created_at)
                                            .all  # Convert to array

        return if errors.length < 2

        cascades = {}
        errors.each_with_index do |issue_a, i|
          errors[(i + 1)..].each do |issue_b|
            # Check if issue_b happened within 5 min of issue_a
            time_diff = (issue_b.created_at - issue_a.created_at).abs
            next unless time_diff <= 300  # 5 minutes

            cascade_key = [normalize_title(issue_a.title), normalize_title(issue_b.title)].sort.join(" -> ")
            cascades[cascade_key] ||= []
            cascades[cascade_key] << [issue_a, issue_b]
          end
        end

        cascades.each do |pattern, pairs|
          next unless pairs.length >= 2  # Threshold: 2+ cascade sequences

          first_issues = pairs.map(&:first).uniq { |i| i.id }
          affected = first_issues.map(&:reporter).uniq.compact

          score = Models::Recommendation.calculate_score(
            frequency: pairs.length,
            severity: "high",
            affected_count: affected.length,
            days_since_first: 1
          )

          Models::Recommendation.create(
            category: "cascade",
            pattern: pattern,
            frequency: pairs.length,
            severity: "high",
            affected_actors: affected.to_a,
            recommendation: "Cascading failure detected. Root cause likely in shared component or initialization order.",
            action: "file_bug",
            score: score,
            related_issue_id: first_issues.first.id
          )
        end
      end

      # Performance Regression: Command latency increasing over time
      def detect_performance_regressions
        # Look for "performance" tagged issues with increasing frequency/severity
        cutoff = Time.now - (30 * 86400)
        perf_issues = Models::OperationalFeedback.where(Sequel.lit("tags @> ?", Sequel.lit("'{performance}'::text[]")))
                                                 .where(Sequel.lit("created_at > ?", cutoff))
                                                 .order(:created_at)
                                                 .all  # Convert to array

        return if perf_issues.length < 3

        # Group by normalized title
        perf_groups = perf_issues.group_by { |p| normalize_title(p.title) }

        perf_groups.each do |normalized, issues|
          # Check for increasing trend
          severity_scores = issues.map { |i| severity_rank(i.severity) }
          is_increasing = severity_scores.each_cons(2).all? { |a, b| b >= a }

          next unless is_increasing

          affected = issues.map(&:reporter).uniq.compact
          days_since_first = ((Time.now - issues.min_by(&:created_at).created_at) / 86400).ceil

          score = Models::Recommendation.calculate_score(
            issues.length,
            "high",
            affected.length,
            days_since_first
          )

          Models::Recommendation.create(
            category: "performance",
            pattern: issues.first.title,
            frequency: issues.length,
            severity: "high",
            affected_actors: affected.to_a,
            recommendation: "Performance degradation detected over #{days_since_first} days. Profile and optimize.",
            action: "file_bug",
            score: score,
            related_issue_id: issues.first.id
          )
        end
      end

      # Normalize title for grouping (remove numbers, timestamps, noise)
      def normalize_title(title)
        title.downcase
             .gsub(/\d+/, "")
             .gsub(/\s+/, " ")
             .strip
             .slice(0, 100)  # Limit length
      end

      # Rank severity for comparison
      def severity_rank(sev)
        { "critical" => 4, "high" => 3, "medium" => 2, "low" => 1, nil => 0 }[sev] || 0
      end
    end
  end
end

# Register the job
Zdots::Jobs.register("pattern_analysis", Zdots::Jobs::PatternAnalysis)
