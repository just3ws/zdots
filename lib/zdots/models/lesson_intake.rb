# frozen_string_literal: true

module Zdots
  module Models
    # LessonIntake — the single path through which all Lessons enter the Knowledge Base.
    #
    # Callers declare *intent* (source_type); this module owns how source_type is set
    # and how source_trace_id is derived from the intent. No caller constructs
    # source_trace_id directly — that rule lives here.
    #
    # source_type values (mirrors the CONTEXT.md term):
    #   "user"    — authored directly by the operator via CLI (add-lesson)
    #   "capture" — AI-distilled from a Session Residue (save-capture); trace_id = bare session trace_id
    #   "ingest"  — ingested from the Knowledge Vault (ingest); trace_id = "ingest:<slug>"
    #   "distill" — AI-distilled from an external source (YouTube distill job); trace_id = job trace_id
    module LessonIntake
      SOURCE_TYPES = %w[user capture ingest distill].freeze

      # Create a Lesson with provenance owned by this module.
      #
      # @param content   [String]        lesson text (required)
      # @param source_type [String]      one of SOURCE_TYPES (required)
      # @param context   [String, nil]   human-readable origin (optional)
      # @param tags      [Array<String>] tag list (optional)
      # @param trace_id  [String, nil]   raw caller trace — interpreted per source_type
      # @param slug      [String, nil]   vault slug — required when source_type == "ingest"
      #
      # @return [Zdots::Models::Lesson]
      def self.create(content:, source_type:, context: nil, tags: [], trace_id: nil, slug: nil)
        unless SOURCE_TYPES.include?(source_type)
          raise ArgumentError, "LessonIntake: unknown source_type #{source_type.inspect} " \
                               "(valid: #{SOURCE_TYPES.join(', ')})"
        end

        derived_trace_id = derive_trace_id(source_type: source_type, trace_id: trace_id, slug: slug)

        Lesson.create(
          content: content,
          context: context,
          tags: Sequel.pg_array(tags),
          source_trace_id: derived_trace_id,
          source_type: source_type
        )
      end

      # Look up an existing ingest Lesson by slug (used by ingest update path).
      # Returns nil when not found.
      def self.find_ingested(slug)
        Lesson.where(source_trace_id: "ingest:#{slug}").first
      end

      private_class_method def self.derive_trace_id(source_type:, trace_id:, slug:)
        case source_type
        when "user"
          # User-authored Lessons carry no system trace — provenance is the actor, not a session.
          nil
        when "capture"
          # Bare session trace_id from zdots-ctx capture pipeline.
          trace_id
        when "ingest"
          # Stable upsert key for vault files; slug is the stable identifier.
          raise ArgumentError, "LessonIntake: slug required for source_type 'ingest'" if slug.nil? || slug.empty?

          "ingest:#{slug}"
        when "distill"
          # Job trace_id from the async Worker; carries the distill job's OTel context.
          trace_id
        end
      end
    end
  end
end
