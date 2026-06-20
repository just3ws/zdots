# frozen_string_literal: true

require_relative "../db"

module Zdots
  module Models
    # A source ingested into the transcription pipeline. Stable identity +
    # write-once non-PHI snapshot (Z-163 policy). The transient `jobs` row drives
    # execution; this row is the durable ledger the dashboard reads.
    class MediaSource < Sequel::Model(Zdots.db[:media_sources])
      plugin :timestamps, update_on_create: true
    end
  end
end
