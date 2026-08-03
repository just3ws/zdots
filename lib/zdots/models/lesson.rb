# frozen_string_literal: true

module Zdots
  module Models
    class Lesson < Sequel::Model(Zdots.db[:lessons])
      plugin :timestamps, update_on_create: true
      include EncryptedContent
      include Searchable

      encrypted_attribute :content
      encrypted_attribute :context

      # FTS index removed after encryption — filter in app after decrypting.
      # Revisit if row counts grow significantly.
      def self.search_fields(record)
        [[record.content.to_s, 1]]
      end
    end
  end
end
