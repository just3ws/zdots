# frozen_string_literal: true

module Zdots
  module Models
    class Methodology < Sequel::Model(Zdots.db[:methodologies])
      plugin :timestamps, update_on_create: true
      include EncryptedContent
      include Searchable

      encrypted_attribute :content

      # title/slug carry identity (Z-232: tooling:<name> lookups key on slug) —
      # weighted higher so an identity match outranks an incidental body match.
      def self.search_fields(record)
        [
          [record.content.to_s, 1],
          [record[:title].to_s, 3],
          [record[:slug].to_s, 3]
        ]
      end
    end
  end
end
