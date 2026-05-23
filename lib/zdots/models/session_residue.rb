# frozen_string_literal: true

module Zdots
  module Models
    class SessionResidue < Sequel::Model(Zdots.db[:session_residue])
      # Transparent encryption/decryption for summary_enc, intent_enc, result_enc.

      %i[summary intent result].each do |field|
        enc_col = :"#{field}_enc"

        define_method(field) do
          raw = self[enc_col]
          return nil if raw.nil?
          db.get(Sequel.function(:pgp_sym_decrypt, Sequel.blob(raw.to_s), _enc_key))
        rescue Sequel::DatabaseError
          nil
        end

        define_method(:"#{field}=") do |value|
          if value.nil?
            self[enc_col] = nil
          else
            self[enc_col] = db.get(Sequel.function(:pgp_sym_encrypt, value.to_s, _enc_key))
          end
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
