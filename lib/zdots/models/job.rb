# frozen_string_literal: true

module Zdots
  module Models
    class Job < Sequel::Model(Zdots.db[:jobs])
      plugin :timestamps, update_on_create: true

      # State transitions using stored procedures
      def self.claim(type = nil, trace_id = nil)
        # claim_next_job(p_worker_type, p_trace_id) returns TABLE(id, type, payload)
        row = Zdots.db.fetch("SELECT * FROM claim_next_job(?, ?);", type, trace_id).first
        return nil unless row

        call(row)
      end

      def fail!(error_message)
        Zdots.db.fetch("SELECT fail_job(?, ?);", id, error_message).all
        refresh
      end

      # result: optional Hash written to metadata (the generic tenant-fetchable
      # result slot — see `zdots-ctx result`). Non-hash returns from Jobs::Base#run
      # (e.g. `true`) are ignored so existing jobs are unaffected.
      def complete!(result = nil)
        update(metadata: Sequel.pg_jsonb(metadata.to_h.merge(result))) if result.is_a?(Hash)
        Zdots.db.fetch("SELECT complete_job(?);", id).all
        refresh
      end

      def self.pending_count(type = nil)
        ds = filter(status: "pending")
        ds = ds.filter(type: type) if type
        ds.count
      end

      def self.dead_count
        filter(status: "dead").count
      end
    end
  end
end
