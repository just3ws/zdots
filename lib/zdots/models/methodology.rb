# frozen_string_literal: true

module Zdots
  module Models
    class Methodology < Sequel::Model(Zdots.db[:methodologies])
      plugin :timestamps, update_on_create: true
      include EncryptedContent
      encrypted_attribute :content

      def self.search(term, semantic: false)
        if semantic
          order(Sequel.lit("embedding <=> ?", term))
        else
          all.select { |r| r.content.to_s.downcase.include?(term.downcase) || r[:title].to_s.downcase.include?(term.downcase) }
        end
      end
    end
  end
end
