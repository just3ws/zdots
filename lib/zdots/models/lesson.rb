# frozen_string_literal: true

module Zdots
  module Models
    class Lesson < Sequel::Model(Zdots.db[:lessons])
      plugin :timestamps, update_on_create: true

      # Transparent encryption/decryption for content_enc column.
      # Key source: ZDOTS_DB_ENCRYPTION_KEY (from Keychain via .zdots.secrets).
      def content
        raw = self[:content_enc]
        return nil if raw.nil?
        db.get(Sequel.function(:pgp_sym_decrypt, Sequel.blob(raw.to_s), _enc_key))
      rescue Sequel::DatabaseError
        nil
      end

      def content=(value)
        if value.nil?
          self[:content_enc] = nil
        else
          self[:content_enc] = db.get(Sequel.function(:pgp_sym_encrypt, value.to_s, _enc_key))
        end
      end

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

      private

      def _enc_key
        key = ENV["ZDOTS_DB_ENCRYPTION_KEY"]
        raise "ZDOTS_DB_ENCRYPTION_KEY is not set" if key.nil? || key.strip.empty?
        key
      end
    end
  end
end
