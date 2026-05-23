# frozen_string_literal: true

module Zdots
  module Models
    class SessionResidue < Sequel::Model(Zdots.db[:session_residue])
      include EncryptedContent
      encrypted_attribute :summary
      encrypted_attribute :intent
      encrypted_attribute :result
    end
  end
end
