# frozen_string_literal: true

require_relative "base"
require_relative "../models/media_source"
require_relative "../models/pipeline_run"
require "open3"
require "digest"
require "fileutils"

module Zdots
  module Jobs
    # Runs the pipeline stages for an ingested source, recording each in
    # pipeline_runs. raw = whisper transcription (--json-full for the doubt
    # loop); cleaned = apply confirmed known_terms corrections to the raw text.
    # Later slices add distilled/landed/promoted. Stages chain through #stage.
    class IngestMedia < Base
      Jobs.register "ingest_media", self

      RETENTION_ROOT = File.expand_path(
        ENV["ZDOTS_INGEST_SOURCES_DIR"] || "~/.local/state/zdots/ingest-sources"
      )

      def run
        @mid      = payload.fetch("media_source_id")
        @profile  = payload["profile"] || "standard"
        @src      = Models::MediaSource[@mid] or raise "media_source not found: #{@mid}"
        @out_base = File.join(RETENTION_ROOT, @mid.to_s)
        FileUtils.mkdir_p(@out_base)

        @src.update(ingest_status: "running")
        raw_txt = stage("raw") { { path: transcribe_raw, params: { "profile" => @profile } } }
        stage("cleaned") { clean_transcript(raw_txt) }
        stage("distilled") { distill(raw_txt) }
        @src.update(ingest_status: "done")
        true
      rescue StandardError => e
        @src&.update(ingest_status: "failed")
        raise e
      end

      private

      # Generic stage runner: marks pipeline_runs running → done|failed and
      # records the artifact, its content hash, and run params. The block
      # returns { path:, params: }. Content-hashed → re-runs are idempotent.
      def stage(name)
        pr = upsert_run(@mid, name)
        pr.update(status: "running", started_at: Sequel::CURRENT_TIMESTAMP)
        result = yield
        pr.update(status: "done", finished_at: Sequel::CURRENT_TIMESTAMP,
                  artifact_path: result[:path],
                  content_hash: Digest::SHA256.hexdigest(File.read(result[:path])),
                  run_params: Sequel.pg_jsonb(result[:params] || {}))
        result[:path]
      rescue StandardError => e
        pr.update(status: "failed", error_message: e.message, finished_at: Sequel::CURRENT_TIMESTAMP) if defined?(pr) && pr
        raise e
      end

      def upsert_run(mid, stage)
        Models::PipelineRun.first(media_source_id: mid, stage: stage) ||
          Models::PipelineRun.create(media_source_id: mid, stage: stage, status: "pending")
      end

      # YouTube/Vimeo only for now: re-fetch + whisper into the retention store.
      # Local sources don't store their path (PHI policy Z-163), so their raw
      # stage needs a retention-store copy made at ingest — a later slice.
      def transcribe_raw
        unless %w[youtube vimeo].include?(@src.source_type)
          raise "raw stage for source_type=#{@src.source_type} not yet supported " \
                "(local needs a retention-store copy at ingest time)"
        end
        recipe = File.join(Zdots::ZDOTDIR, "recipes", "yt-transcribe")
        cmd = [recipe, @src.source_uri, "--profile", @profile, "--json-full", "--out-dir", @out_base]
        vocab = known_vocabulary
        cmd += ["--prompt", vocab] unless vocab.empty?
        puts "  --> #{cmd.join(' ')}"
        Open3.popen2e(*cmd) do |_in, out, wait|
          out.each { |line| puts line }
          status = wait.value
          raise "yt-transcribe failed (exit #{status.exitstatus})" unless status.success?
        end
        # raw whisper text — exclude the cleaned sibling we may have written before
        txt = Dir.glob(File.join(@out_base, "*", "*.txt")).reject { |f| f.end_with?(".cleaned.txt") }.max_by { |f| File.size(f) }
        raise "no transcript produced in #{@out_base}" unless txt
        txt
      end

      # Cleaned stage: deterministically apply confirmed known_terms corrections
      # (mis-hearing alias → canonical) to the raw transcript. The doubt loop's
      # payoff — your corrections actually fix the text. Records what changed.
      def clean_transcript(raw_path)
        text, corrections = apply_corrections(File.read(raw_path))
        out = raw_path.sub(/\.txt\z/, ".cleaned.txt")
        File.write(out, text)
        { path: out, params: { "corrections" => corrections } }
      end

      # Apply confirmed known_terms aliases (mis-hearing → canonical) to text.
      # Returns [corrected_text, corrections_list]. Shared by cleaned + distilled.
      def apply_corrections(text)
        corrections = []
        Zdots.db[:known_terms].select(:canonical, :aliases).each do |t|
          Array(t[:aliases]).each do |al|
            al = al.to_s.strip
            next if al.empty?
            n = text.scan(/\b#{Regexp.escape(al)}\b/i).size
            next if n.zero?
            text = text.gsub(/\b#{Regexp.escape(al)}\b/i, t[:canonical])
            corrections << { "from" => al, "to" => t[:canonical], "count" => n }
          end
        end
        [text, corrections]
      end

      # Distilled stage: the LLM step. Feed a [mm:ss]-tagged, corrected transcript
      # to the local model (ai-query, which PHI-scrubs first — Z-163) and persist
      # grounded insights. Output is editable in the UI (the Landed-Thoughts gate).
      def distill(raw_path)
        source = timestamped_transcript(raw_path)
        out = raw_path.sub(/\.txt\z/, ".distilled.md")
        File.write(out, ai_distill(source))
        { path: out, params: { "model" => "local", "input_chars" => source.length } }
      end

      DISTILL_TASK =
        "Distill this transcript into a knowledge briefing. Each line is prefixed " \
        "with its [mm:ss] timestamp. Output markdown: a one-line summary, then 5-12 " \
        "key insights as bullets. Begin every bullet with the [mm:ss] of the moment " \
        "it draws from. Be faithful — invent nothing not in the transcript."

      def ai_distill(transcript)
        ai_query = File.join(Zdots::ZDOTDIR, "bin", "ai-query")
        out, status = Open3.capture2(ai_query, DISTILL_TASK, stdin_data: transcript)
        raise "ai-query failed (exit #{status.exitstatus})" unless status.success?
        out.strip
      end

      # Build a [mm:ss]-tagged transcript from the whisper .vtt sibling, with
      # known_terms corrections applied. Grounds the LLM's insights to moments.
      # ponytail: whole transcript in one prompt; chunk long videos in Z-169.
      def timestamped_transcript(raw_path)
        vtt = raw_path.sub(/\.txt\z/, ".vtt")
        return apply_corrections(File.read(raw_path)).first unless File.file?(vtt)

        lines = []
        ts = nil
        File.foreach(vtt) do |ln|
          ln = ln.chomp
          if (m = ln.match(/\A(\d\d):(\d\d):(\d\d)\.\d+\s*-->/))
            ts = format("%02d:%02d", m[1].to_i * 60 + m[2].to_i, m[3].to_i)
          elsif ts && !ln.strip.empty?
            lines << "[#{ts}] #{ln.strip}"
            ts = nil # one tag per cue, on its first text line
          end
        end
        apply_corrections(lines.join("\n")).first
      end

      # The doubt loop's proactive half: bias whisper toward terms we already
      # know, so it spells them right before any review. Capped to keep the
      # prompt within whisper's context budget.
      def known_vocabulary
        terms = Zdots.db[:known_terms].order(:canonical).limit(100).select_map(:canonical)
        terms.empty? ? "" : "Vocabulary: #{terms.join(', ')}."
      end
    end
  end
end
