# frozen_string_literal: true

module Zdots
  module Models
    # Shared search interface for models with encrypted content and pgvector embeddings.
    #
    # Including classes must extend this module (ClassMethods) and implement
    # .text_match?(record, term) — which fields to scan in the non-semantic path.
    #
    # Semantic search returns a Sequel dataset ordered by embedding distance.
    # Non-semantic search decrypts all rows and filters in Ruby (acceptable at
    # current dataset sizes; see comment in Lesson/Methodology if revisiting).
    module Searchable
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def search(term, semantic: false)
          if semantic
            order(Sequel.lit("embedding <=> ?", term))
          else
            order(Sequel.desc(:created_at)).all.select { |r| text_match?(r, term) }
          end
        end

        # Models define which fields to include in non-semantic search.
        def text_match?(_record, _term)
          raise NotImplementedError, "#{self}.text_match? not implemented"
        end
      end
    end
  end
end
