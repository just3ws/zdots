# frozen_string_literal: true

module Zdots
  module Models
    class Methodology < Sequel::Model(Zdots.db[:methodologies])
      plugin :timestamps, update_on_create: true
      include EncryptedContent
      include Searchable

      encrypted_attribute :content

      def self.text_match?(record, term)
        record.content.to_s.downcase.include?(term.downcase) ||
          record[:title].to_s.downcase.include?(term.downcase)
      end
    end
  end
end
