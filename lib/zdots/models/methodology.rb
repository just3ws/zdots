# frozen_string_literal: true

module Zdots
  module Models
    class Methodology < Sequel::Model(Zdots.db[:methodologies])
      plugin :timestamps, update_on_create: true

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
          all.select { |r| r.content.to_s.downcase.include?(term.downcase) || r[:title].to_s.downcase.include?(term.downcase) }
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
