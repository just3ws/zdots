# frozen_string_literal: true

require "json"
require "fileutils"

module Zdots
  # Z-247: append-only, schema-validated pipeline event stream — one JSONL line
  # per job lifecycle event (started / succeeded / failed).
  #
  # Fields are structural only (ids, enums, counts) — never free-text content —
  # so the stream is PHI-safe by construction and needs no scrubbing. The
  # contract is etc/pipeline-events.schema.json (Draft 7), enforced by
  # tests/pipeline_events.bats.
  #
  # Per-job view (derived, not stored):
  #   jq -c 'select(.job_id=="<uuid>")' ~/.local/state/zdots/pipeline-events.jsonl
  module PipelineEvents
    EVENTS = %w[started succeeded failed].freeze

    class Record < Data.define(:ts, :job_id, :job_type, :event, :attempt, :media_source_id, :error_class)
      def initialize(ts:, job_id:, job_type:, event:, attempt: nil, media_source_id: nil, error_class: nil)
        event_s = event.to_s
        raise ArgumentError, "invalid pipeline event: #{event_s}" unless EVENTS.include?(event_s)

        jid = job_id.to_s
        raise ArgumentError, "job_id is required" if jid.empty?

        jtype = job_type.to_s
        raise ArgumentError, "job_type is required" if jtype.empty?

        super(
          ts: ts.to_s,
          job_id: jid,
          job_type: jtype,
          event: event_s,
          attempt: attempt,
          media_source_id: media_source_id,
          error_class: error_class
        )
      end

      def to_payload
        {
          "ts" => ts,
          "job_id" => job_id,
          "job_type" => job_type,
          "event" => event,
          "attempt" => attempt,
          "media_source_id" => media_source_id,
          "error_class" => error_class
        }.compact
      end
    end

    def self.path
      ENV["ZDOTS_PIPELINE_EVENTS_FILE"] ||
        File.join(ENV.fetch("XDG_STATE_HOME", File.expand_path("~/.local/state")),
                  "zdots", "pipeline-events.jsonl")
    end

    def self.build_record(event, job, error: nil, now: Time.now.utc)
      attempt = job.attempts.to_i if job.respond_to?(:attempts) && job.attempts
      msid = job.payload["media_source_id"] if job.respond_to?(:payload) && job.payload.is_a?(Hash)
      Record.new(
        ts: now.strftime("%Y-%m-%dT%H:%M:%S.%3NZ"),
        job_id: job.id.to_s,
        job_type: job.type.to_s,
        event: event.to_s,
        attempt: attempt,
        media_source_id: msid,
        error_class: error&.class&.name
      )
    end

    # Emission must never take a job down — any failure degrades to one warn line.
    def self.emit(event, job, error: nil)
      rec = build_record(event, job, error: error)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "a") { |f| f.write(JSON.generate(rec.to_payload) << "\n") }
    rescue StandardError => e
      warn "zdots-brain: pipeline-event emit failed (#{e.class}): #{e.message}"
    end
  end
end
