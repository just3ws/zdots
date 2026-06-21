# frozen_string_literal: true

require_relative "base"
require_relative "../models/media_source"
require_relative "../models/pipeline_run"
require "open3"
require "digest"
require "fileutils"

module Zdots
  module Jobs
    # Runs the RAW transcription stage for an ingested source and records it in
    # pipeline_runs. Reuses recipes/yt-transcribe (--json-full for the doubt
    # loop's token confidence, --out-dir to land in the retention store, not
    # ~/Downloads). Later slices add cleaned/distilled stages.
    class IngestMedia < Base
      Jobs.register "ingest_media", self

      RETENTION_ROOT = File.expand_path(
        ENV["ZDOTS_INGEST_SOURCES_DIR"] || "~/.local/state/zdots/ingest-sources"
      )

      def run
        mid     = payload.fetch("media_source_id")
        profile = payload["profile"] || "standard"
        src     = Models::MediaSource[mid] or raise "media_source not found: #{mid}"

        src.update(ingest_status: "running")
        raw = upsert_run(mid, "raw")
        raw.update(status: "running", started_at: Sequel::CURRENT_TIMESTAMP,
                   run_params: Sequel.pg_jsonb({ "profile" => profile }))

        out_base = File.join(RETENTION_ROOT, mid.to_s)
        FileUtils.mkdir_p(out_base)
        txt = transcribe_raw(src, profile, out_base)

        raw.update(status: "done", finished_at: Sequel::CURRENT_TIMESTAMP,
                   artifact_path: txt,
                   content_hash: Digest::SHA256.hexdigest(File.read(txt)))
        src.update(ingest_status: "done")
        true
      rescue StandardError => e
        raw.update(status: "failed", error_message: e.message,
                   finished_at: Sequel::CURRENT_TIMESTAMP) if defined?(raw) && raw
        Models::MediaSource[mid]&.update(ingest_status: "failed") if defined?(mid)
        raise e
      end

      private

      def upsert_run(mid, stage)
        Models::PipelineRun.first(media_source_id: mid, stage: stage) ||
          Models::PipelineRun.create(media_source_id: mid, stage: stage, status: "pending")
      end

      # YouTube/Vimeo only for now: re-fetch + whisper into the retention store.
      # Local sources don't store their path (PHI policy Z-163), so their raw
      # stage needs a retention-store copy made at ingest — a later slice.
      def transcribe_raw(src, profile, out_base)
        unless %w[youtube vimeo].include?(src.source_type)
          raise "raw stage for source_type=#{src.source_type} not yet supported " \
                "(local needs a retention-store copy at ingest time)"
        end
        recipe = File.join(Zdots::ZDOTDIR, "recipes", "yt-transcribe")
        cmd = [recipe, src.source_uri, "--profile", profile, "--json-full", "--out-dir", out_base]
        puts "  --> #{cmd.join(' ')}"
        Open3.popen2e(*cmd) do |_in, out, wait|
          out.each { |line| puts line }
          status = wait.value
          raise "yt-transcribe failed (exit #{status.exitstatus})" unless status.success?
        end
        txt = Dir.glob(File.join(out_base, "*", "*.txt")).max_by { |f| File.size(f) }
        raise "no transcript produced in #{out_base}" unless txt
        txt
      end
    end
  end
end
