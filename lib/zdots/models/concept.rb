# frozen_string_literal: true

require_relative "../db"

module Zdots
  module Models
    class Concept < Sequel::Model(Zdots.db[:concept])
      plugin :timestamps, update_on_create: true
      one_to_many :aliases, class: :"Zdots::Models::ConceptAlias", key: :concept_id
      one_to_many :from_links, class: :"Zdots::Models::ConceptLink", key: :from_concept_id
      one_to_many :to_links, class: :"Zdots::Models::ConceptLink", key: :to_concept_id
      one_to_many :tags, class: :"Zdots::Models::ConceptTag", key: :concept_id

      # Resolve a word to a Concept — exact slug match first, then case-insensitive alias.
      def self.resolve(word)
        normalized = word.downcase.tr(" ", "-")
        find(slug: normalized) ||
          where(Sequel.function(:lower, :term) => word.downcase).first ||
          Zdots.db[:concept_alias]
               .where(Sequel.function(:lower, :alias) => [word.downcase, normalized])
               .first
               .then { |row| find(id: row[:concept_id]) if row }
      end

      def self.add(slug:, term:, definition: nil, source_ref: nil)
        create(slug: slug, term: term, definition: definition, source_ref: source_ref)
      end

      def self.add_alias(alias_text, slug, disallowed: false)
        c = find(slug: slug) or raise ArgumentError, "concept not found: #{slug}"
        ConceptAlias.create(alias: alias_text, concept_id: c.id, disallowed: disallowed)
      end

      def self.link(from_slug, relation, to_slug)
        from = find(slug: from_slug) or raise ArgumentError, "concept not found: #{from_slug}"
        to   = find(slug: to_slug)   or raise ArgumentError, "concept not found: #{to_slug}"
        ConceptLink.create(from_concept_id: from.id, to_concept_id: to.id, relation: relation)
      rescue Sequel::UniqueConstraintViolation
        nil # idempotent
      end

      def self.tag(slug, target_kind, target_id)
        c = find(slug: slug) or raise ArgumentError, "concept not found: #{slug}"
        ConceptTag.create(concept_id: c.id, target_kind: target_kind, target_id: target_id)
      rescue Sequel::UniqueConstraintViolation
        nil # idempotent
      end

      def to_h
        {
          id: id, slug: slug, term: term,
          definition: definition, source_ref: source_ref,
          aliases: aliases.map { |a| { alias: a[:alias], disallowed: a.disallowed } }
        }
      end

      CANON = [
        { slug: "platform-service",        term: "Platform Service",        source_ref: "AGENTS.md §9",
          definition: "A service with a specific lifecycle model: start/stop/restart with health probes.",
          disallowed: %w[service microservice daemon] },
        { slug: "seam",                    term: "Seam",                    source_ref: "AGENTS.md §9",
          definition: "The place where behavior changes without editing in place.",
          disallowed: %w[boundary interface api facade] },
        { slug: "knowledge-layer",         term: "Knowledge Layer",         source_ref: "AGENTS.md §9",
          definition: "The AI/ML layer of the platform. Exact name; not interchangeable.",
          disallowed: ["intelligence-suite", "ml-layer", "ai-layer"] },
        { slug: "session-residue",         term: "Session Residue",         source_ref: "AGENTS.md §9",
          definition: "Raw distillation of a session with intent/result/summary.",
          disallowed: %w[capture transcript session-log record] },
        { slug: "lesson",                  term: "Lesson",                  source_ref: "AGENTS.md §9",
          definition: "Curated, atomic, tagged knowledge unit.",
          disallowed: %w[note doc article knowledge-unit] },
        { slug: "methodology",             term: "Methodology",             source_ref: "AGENTS.md §9",
          definition: "Synthesized from multiple Lessons.",
          disallowed: ["best-practice", "pattern", "principle"] },
        { slug: "message-hygiene-pipeline", term: "Message Hygiene Pipeline", source_ref: "AGENTS.md §9",
          definition: "Specific stages: normalize, then PHI scrub (order matters).",
          disallowed: ["sanitizer", "scrubber-pipeline", "cleaning"] },
        { slug: "phi-scrubber",            term: "PHI Scrubber",            source_ref: "AGENTS.md §9",
          definition: "The component that redacts PHI. Noun, not the verb 'scrubbing'.",
          disallowed: ["phi-scrubbing", "redactor", "scrubber"] },
        { slug: "virtuous-loop",           term: "Virtuous Loop",           source_ref: "AGENTS.md §9",
          definition: "Work → Capture → Curate → Infer → Repeat.",
          disallowed: ["feedback-loop", "cycle", "learning-loop"] },
        { slug: "workflow",                term: "Workflow",                source_ref: "AGENTS.md §9",
          definition: "Declarative, composable, observable — not an imperative shell script.",
          disallowed: %w[pipeline job script task] },
        { slug: "alert",                   term: "Alert",                   source_ref: "AGENTS.md §9",
          definition: "Condition-based, with actions and thresholds.",
          disallowed: ["alert-rule", "notification", "trigger"] },
        { slug: "actor",                   term: "Actor",                   source_ref: "AGENTS.md §9",
          definition: "In access control context; includes humans, agents, services.",
          disallowed: %w[user agent principal client] },
        { slug: "access-control",          term: "Access Control",          source_ref: "AGENTS.md §9",
          definition: "Specific system: roles + actor + allow/deny rules.",
          disallowed: %w[permissions acl auth rbac] },
        { slug: "capability",              term: "Capability",              source_ref: "AGENTS.md §9",
          definition: "Discoverable, attestable facility (e.g. does-ai-inference).",
          disallowed: %w[feature function operation] }  # "service" → platform-service; not a dup
      ].freeze

      def self.seed_canon!
        seeded = 0
        CANON.each do |c|
          next if find(slug: c[:slug]) # idempotent

          concept = add(slug: c[:slug], term: c[:term],
                        definition: c[:definition], source_ref: c[:source_ref])
          c[:disallowed].each do |a|
            ConceptAlias.create(alias: a, concept_id: concept.id, disallowed: true)
          rescue Sequel::UniqueConstraintViolation
            nil # alias already registered under another concept
          end
          seeded += 1
        end
        seeded
      end
    end

    class ConceptAlias < Sequel::Model(Zdots.db[:concept_alias])
      many_to_one :concept, class: :"Zdots::Models::Concept", key: :concept_id
    end

    class ConceptLink < Sequel::Model(Zdots.db[:concept_link])
      many_to_one :from_concept, class: :"Zdots::Models::Concept", key: :from_concept_id
      many_to_one :to_concept,   class: :"Zdots::Models::Concept", key: :to_concept_id
    end

    class ConceptTag < Sequel::Model(Zdots.db[:concept_tag])
      many_to_one :concept, class: :"Zdots::Models::Concept", key: :concept_id
    end
  end
end
