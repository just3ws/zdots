# frozen_string_literal: true

module Zdots
  module Models
    # Shared search interface for models with encrypted content and pgvector embeddings.
    #
    # Including classes must extend this module (ClassMethods) and implement
    # .search_fields(record) — an array of [text, weight] pairs to scan.
    #
    # Text search decrypts all rows and filters in Ruby (acceptable at current
    # dataset sizes — a real index needs plaintext, which conflicts with
    # encryption at rest; see Lesson/Methodology if dataset size changes that
    # tradeoff). Within that constraint: every whitespace-separated word in the
    # query must appear somewhere in the record (AND, not one exact phrase —
    # "disruption assumptions" now matches a doc containing both words anywhere,
    # not just that literal contiguous phrase), and results rank by a simple
    # term-frequency score instead of just recency.
    #
    # Semantic search assembles the embedding vector here so callers only supply
    # a plain-text term. Requires the embed service to be running.
    module Searchable
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Text search: decrypt-all scan, AND-match on words, rank by score desc.
        def search(term)
          words = term.to_s.downcase.split(/\s+/).reject(&:empty?)
          return [] if words.empty?

          all.filter_map { |r| [r, text_score(r, words)] }
             .select { |_, score| score.positive? }
             .sort_by { |_, score| -score }
             .map(&:first)
        end

        # Semantic search: assembles the embedding vector and returns a Sequel
        # dataset ordered by cosine distance. Callers supply a plain-text term;
        # embedding assembly is owned here, not by the caller.
        def semantic_search(term)
          embedding = Zdots::AI.embed_client.embed(model: "embed", input: term).vectors
          vec_literal = "[#{embedding.join(',')}]"
          exclude(embedding: nil).order(Sequel.lit("embedding <=> ?::vector", vec_literal))
        rescue Errno::ECONNREFUSED
          warn "zdots-brain: embed service unavailable (127.0.0.1:11501) — start with: zsvc start embed"
          where(false)
        end

        # Models define which fields to scan and how much each counts toward
        # ranking — e.g. a title/slug match should outrank a body match.
        # Returns an array of [text, weight] pairs.
        def search_fields(_record)
          raise NotImplementedError, "#{self}.search_fields not implemented"
        end

        # AND-match: every query word must appear in at least one field.
        # Score: word occurrences summed across fields, weighted per field.
        def text_score(record, words)
          fields = search_fields(record).map { |text, weight| [text.to_s.downcase, weight] }
          return 0 unless words.all? { |w| fields.any? { |text, _| text.include?(w) } }

          words.sum { |w| fields.sum { |text, weight| text.scan(w).size * weight } }
        end

        # Backward-compatible boolean gate (Z-232: zdots-ctx query tooling:<name>
        # must hit on slug — see spec/zdots/models/methodology_search_spec.rb).
        def text_match?(record, term)
          words = term.to_s.downcase.split(/\s+/).reject(&:empty?)
          return false if words.empty?

          fields = search_fields(record).map { |text, _| text.to_s.downcase }
          words.all? { |w| fields.any? { |text| text.include?(w) } }
        end
      end
    end
  end
end
