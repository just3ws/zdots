# frozen_string_literal: true

module Zdots
  module Models
    class Lesson < Sequel::Model(Zdots.db[:lessons])
      plugin :timestamps, update_on_create: true
      include EncryptedContent
      include Searchable
      encrypted_attribute :content

      # FTS index removed after encryption — filter in app after decrypting.
      # Revisit if row counts grow significantly.
      def self.text_match?(record, term)
        record.content.to_s.downcase.include?(term.downcase)
      end
    end
  end
end
