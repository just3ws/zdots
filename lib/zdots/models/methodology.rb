# frozen_string_literal: true

require_relative "../../zdots"

module Zdots
  module Models
    class Methodology < Sequel::Model(Zdots.db[:methodologies])
      plugin :timestamps, update_on_create: true
      
      def self.search(term, semantic: false)
        if semantic
          order(Sequel.lit("embedding <=> ?", term))
        else
          full_text_search = Sequel.lit("to_tsvector('english', title || ' ' || content) @@ plainto_tsquery('english', ?)", term)
          where(full_text_search).or(Sequel.ilike(:title, "%#{term}%")).or(Sequel.ilike(:content, "%#{term}%"))
        end
      end
    end
  end
end
