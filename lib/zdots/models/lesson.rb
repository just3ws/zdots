# frozen_string_literal: true

module Zdots
  module Models
    class Lesson < Sequel::Model(Zdots.db[:lessons])
      plugin :timestamps, update_on_create: true
      include EncryptedContent
      encrypted_attribute :content

      def self.search(term, semantic: false)
        if semantic
          order(Sequel.lit("embedding <=> ?", term))
        else
          # FTS index removed after encryption — filter in app after decrypting.
          # For datasets with thousands of rows this is acceptable; revisit if
          # row counts grow significantly.
          all.select { |r| r.content.to_s.downcase.include?(term.downcase) }
        end
      end
    end
  end
end
