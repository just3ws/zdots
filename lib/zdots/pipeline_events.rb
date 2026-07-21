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

    def self.path
      ENV["ZDOTS_PIPELINE_EVENTS_FILE"] ||
        File.join(ENV.fetch("XDG_STATE_HOME", File.expand_path("~/.local/state")),
                  "zdots", "pipeline-events.jsonl")
    end

    # Emission must never take a job down — any failure degrades to one warn line.
    def self.emit(event, job, error: nil)
      record = {
        "ts" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%3NZ"),
        "job_id" => job.id.to_s,
        "job_type" => job.type.to_s,
        "event" => event.to_s,
        "attempt" => (job.attempts.to_i if job.respond_to?(:attempts) && job.attempts),
        "media_source_id" => (job.payload["media_source_id"] if job.respond_to?(:payload) && job.payload.is_a?(Hash)),
        "error_class" => error&.class&.name
      }.compact
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "a") { |f| f.write(JSON.generate(record) << "\n") }
    rescue StandardError => e
      warn "zdots-brain: pipeline-event emit failed (#{e.class}): #{e.message}"
    end
  end
end
