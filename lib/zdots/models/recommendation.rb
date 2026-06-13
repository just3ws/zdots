# frozen_string_literal: true

module Zdots
  module Models
    class Recommendation < Sequel::Model(Zdots.db[:recommendations])
      plugin :timestamps, update_on_create: true

      VALID_CATEGORIES = %w[error_cluster feature_request cascade friction performance].freeze
      VALID_ACTIONS = %w[file_bug add_to_backlog improve_docs dismiss watch].freeze

      def self.valid_category?(category)
        VALID_CATEGORIES.include?(category)
      end

      def self.valid_action?(action)
        VALID_ACTIONS.include?(action)
      end

      # Find recommendations by score descending, optionally filtered
      def self.top_recommendations(limit = 10, filters = {})
        ds = self
        ds = ds.where(severity: filters[:severity]) if filters[:severity]
        ds = ds.where(category: filters[:category]) if filters[:category]
        ds = ds.where(acted_on: false) if filters[:unacted]
        ds = ds.where(Sequel.lit("generated_at > ?", Time.now - (filters[:days].to_i * 86400))) if filters[:days]

        ds.order(Sequel.desc(:score)).limit(limit).all
      end

      # Mark this recommendation as acted on
      def mark_acted_on!(related_backlog_id = nil)
        update(acted_on: true, updated_at: Time.now)
      end

      # Calculate score for a pattern: (frequency × severity_weight × affected_count) / days_since_first
      def self.calculate_score(frequency:, severity:, affected_count:, days_since_first: 1)
        severity_weight = {
          "critical" => 4.0,
          "high" => 3.0,
          "medium" => 2.0,
          "low" => 1.0,
          nil => 0.5
        }
        weight = severity_weight[severity] || 0.5
        score = (frequency * weight * affected_count) / [days_since_first, 1].max.to_f
        [score, 10.0].min  # Cap at 10.0 for practical use
      end
    end
  end
end
