# frozen_string_literal: true

module Zdots
  module Models
    # Shared search interface for models with encrypted content and pgvector embeddings.
    #
    # Including classes must extend this module (ClassMethods) and implement
    # .text_match?(record, term) — which fields to scan in the text path.
    #
    # Text search decrypts all rows and filters in Ruby (acceptable at current
    # dataset sizes; see comment in Lesson/Methodology if revisiting).
    #
    # Semantic search assembles the embedding vector here so callers only supply
    # a plain-text term. Requires the embed service to be running.
    module Searchable
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Text search: decrypt-all scan filtered in Ruby.
        def search(term)
          order(Sequel.desc(:created_at)).all.select { |r| text_match?(r, term) }
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

        # Models define which fields to include in text search.
        def text_match?(_record, _term)
          raise NotImplementedError, "#{self}.text_match? not implemented"
        end
      end
    end
  end
end
