# frozen_string_literal: true
module Zdots
  module Models
    class SourceDocument < Sequel::Model(:source_document)
      plugin :timestamps, update_on_create: true
      include EncryptedContent

      encrypted_attribute :body_md

      def self.upsert_by_uri(uri:, source_type:, title: nil, body_md: nil,
                              checksum: nil, provenance: {}, fetched_at: nil)
        existing = where(uri: uri).first
        if existing
          existing.update(title: title, body_md: body_md, checksum: checksum,
                          provenance: Sequel.pg_jsonb(provenance),
                          fetched_at: fetched_at, ingested_at: Time.now)
          existing
        else
          create(uri: uri, source_type: source_type, title: title, body_md: body_md,
                 checksum: checksum, provenance: Sequel.pg_jsonb(provenance),
                 fetched_at: fetched_at, ingested_at: Time.now)
        end
      end
    end
  end
end
