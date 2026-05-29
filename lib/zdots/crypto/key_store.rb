# frozen_string_literal: true

module Zdots
  module Crypto
    module KeyStore
      def self.current_key
        key = ENV.fetch("ZDOTS_DB_ENCRYPTION_KEY", nil)
        raise KeyError, "ZDOTS_DB_ENCRYPTION_KEY is not set" if key.nil? || key.strip.empty?

        key
      end

      def self.rotation_keys
        old_key = ENV.fetch("ZDOTS_DB_OLD_KEY", nil)
        if old_key.nil? || old_key.strip.empty?
          raise KeyError,
                "ZDOTS_DB_OLD_KEY is not set — set it for this invocation only:\n  ZDOTS_DB_OLD_KEY=<burned_key> zdots-brain rekey [table]"
        end

        new_key = current_key
        if old_key == new_key
          raise KeyError, "ZDOTS_DB_OLD_KEY and ZDOTS_DB_ENCRYPTION_KEY are identical — nothing to do"
        end

        [old_key, new_key]
      end
    end
  end
end
