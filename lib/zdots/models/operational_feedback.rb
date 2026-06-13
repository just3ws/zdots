# frozen_string_literal: true

module Zdots
  module Models
    class OperationalFeedback < Sequel::Model(Zdots.db[:operational_feedback])
      plugin :timestamps, update_on_create: true

      VALID_TYPES = %w[error request friction].freeze
      VALID_SEVERITIES = %w[low medium high critical].freeze
      VALID_STATUSES = %w[open wontfix fixed duplicate].freeze

      def self.valid_type?(type)
        VALID_TYPES.include?(type)
      end

      def self.valid_severity?(severity)
        VALID_SEVERITIES.include?(severity)
      end

      def self.valid_status?(status)
        VALID_STATUSES.include?(status)
      end

      # Find or create a feedback, deduplicating if similar issue exists within time window
      def self.create_or_deduplicate(attrs, dedup_window_minutes = 5)
        # Normalize title for comparison
        normalized_title = attrs[:title].to_s.downcase.strip

        # Look for similar issues within dedup window
        recent = where(
          report_type: attrs[:report_type],
          created_at: (Time.now - (dedup_window_minutes * 60))..Time.now
        ).all

        existing = recent.find { |f| f.title.downcase.strip == normalized_title }
        if existing
          # Increment a dedup counter in metadata or create a duplicate link
          return existing
        end

        create(attrs)
      end

      # Score this feedback for prioritization (urgency)
      def priority_score
        severity_weight = {
          "critical" => 4.0,
          "high" => 3.0,
          "medium" => 2.0,
          "low" => 1.0,
          nil => 0.5
        }
        severity_weight[severity] || 0.5
      end
    end
  end
end
