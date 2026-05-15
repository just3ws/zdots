# frozen_string_literal: true

require_relative "../../zdots"

module Zdots
  module Models
    class Lesson < Sequel::Model(Zdots.db[:lessons])
      plugin :timestamps, update_on_create: true
      
      def self.search(term, semantic: false)
        if semantic
          # Convert term to vector first (this will be handled by a helper later)
          # For now, just placeholder for semantic search DSL
          order(Sequel.lit("embedding <=> ?", term))
        else
          full_text_search = Sequel.lit("to_tsvector('english', content || ' ' || coalesce(context, '')) @@ plainto_tsquery('english', ?)", term)
          where(full_text_search).or(Sequel.ilike(:content, "%#{term}%"))
        end
      end
    end
  end
end
