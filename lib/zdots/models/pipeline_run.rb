# frozen_string_literal: true

require_relative "../db"

module Zdots
  module Models
    # One row per stage execution for a media source (raw, cleaned, distilled,
    # …). The per-stage ledger the dashboard reads; outlives the transient job.
    class PipelineRun < Sequel::Model(Zdots.db[:pipeline_runs])
      plugin :timestamps, update_on_create: true
    end
  end
end
