# frozen_string_literal: true

module Zdots
  module Models
    module EncryptedContent
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def encrypted_attribute(name, column: :"#{name}_enc")
          define_method(name) do
            raw = self[column]
            return nil if raw.nil?

            db.get(Sequel.function(:pgp_sym_decrypt, Sequel.blob(raw.to_s), Zdots::Crypto::KeyStore.current_key))
          end

          define_method(:"#{name}=") do |value|
            self[column] = if value.nil?
                             nil
                           else
                             db.get(Sequel.function(:pgp_sym_encrypt, value.to_s, Zdots::Crypto::KeyStore.current_key))
                           end
          end
        end
      end
    end
  end
end
