# frozen_string_literal: true

require_relative "../../zdots" # boot Zdots.db (idempotent; lets the self-check run standalone)
require_relative "base"
require_relative "ingest_media"
require_relative "../models/media_source"
require_relative "../models/pipeline_run"
require_relative "../models/job"
require "open3"
require "digest"
require "fileutils"

module Zdots
  module Jobs
    # Z-169: transcribe one audio window of a long source. Each window is its own
    # queue job, so the queue's attempts/fail machinery gives checkpoint + resume
    # for free — a killed worker only re-runs the un-done windows. The window that
    # finishes last wins the unique-index race for the whole-stage summary row,
    # stitches the windows (overlap-deduped), and re-enqueues ingest_media to run
    # cleaned/distilled.
    class TranscribeChunk < Base
      Jobs.register "transcribe_chunk", self

      def run
        @mid = payload.fetch("media_source_id")
        i    = payload.fetch("chunk_index")
        n    = payload.fetch("n")
        @src = Models::MediaSource[@mid] or raise "media_source not found: #{@mid}"

        pr = chunk_run(i)
        return true if pr.status == "done" # idempotent re-delivery

        pr.update(status: "running", started_at: Sequel::CURRENT_TIMESTAMP)
        out = transcribe_window(i, payload)
        pr.update(status: "done", artifact_path: out,
                  content_hash: Digest::SHA256.hexdigest(File.read(out)),
                  finished_at: Sequel::CURRENT_TIMESTAMP)

        self.class.reduce_if_complete(@mid, n, payload["profile"])
        true
      rescue StandardError => e
        pr&.update(status: "failed", error_message: e.message, finished_at: Sequel::CURRENT_TIMESTAMP) if defined?(pr)
        raise e
      end

      # Fan-in: once every window is done, atomically claim the reduce by
      # creating the whole-stage summary row (unique index → exactly one winner),
      # stitch, then re-enqueue ingest_media to finish the pipeline.
      # ponytail: a crash after claiming strands the summary in "running"; rare
      # and stitch is cheap+deterministic — re-run the source if it happens.
      def self.reduce_if_complete(mid, n, profile)
        done = Models::PipelineRun.where(media_source_id: mid, stage: "raw")
                                  .exclude(chunk_index: nil).where(status: "done").count
        return if done < n

        begin
          summary = Models::PipelineRun.create(
            media_source_id: mid, stage: "raw", chunk_index: nil,
            status: "running", started_at: Sequel::CURRENT_TIMESTAMP
          )
        rescue Sequel::UniqueConstraintViolation
          return # another window already claimed the reduce
        end

        raw_path = stitch(mid)
        summary.update(status: "done", artifact_path: raw_path,
                       content_hash: Digest::SHA256.hexdigest(File.read(raw_path)),
                       finished_at: Sequel::CURRENT_TIMESTAMP)

        Models::Job.dataset.insert_conflict(target: :fingerprint).insert(
          type: "ingest_media",
          payload: Sequel.pg_jsonb({ "media_source_id" => mid, "profile" => profile }),
          priority: 10, fingerprint: Digest::MD5.hexdigest("ingest_media-resume-#{mid}")
        )
      end

      # Stitch the window transcripts in order, overlap-deduped, into one file.
      def self.stitch(mid)
        src  = Models::MediaSource[mid]
        rows = Models::PipelineRun.where(media_source_id: mid, stage: "raw")
                                  .exclude(chunk_index: nil).order(:chunk_index).all
        merged = rows.map { |r| File.read(r.artifact_path).strip }
                     .reduce("") { |acc, t| acc.empty? ? t : splice(acc, t) }
        out = File.join(IngestMedia::RETENTION_ROOT, mid.to_s, "#{src.source_id}.stitched.txt")
        FileUtils.mkdir_p(File.dirname(out))
        File.write(out, merged)
        out
      end

      # Greedy word-overlap splice: drop B's leading words that duplicate A's
      # trailing words (consecutive whisper windows overlap), so the seam reads
      # once. Case-insensitive match; keeps A's casing.
      def self.splice(a, b, max_words: 80)
        aw = a.split
        bw = b.split
        k_max = [aw.size, bw.size, max_words].min
        best = 0
        (1..k_max).each { |k| best = k if aw.last(k).map(&:downcase) == bw.first(k).map(&:downcase) }
        (aw + bw.drop(best)).join(" ")
      end

      private

      def chunk_run(i)
        Models::PipelineRun.first(media_source_id: @mid, stage: "raw", chunk_index: i) ||
          Models::PipelineRun.create(media_source_id: @mid, stage: "raw", chunk_index: i, status: "pending")
      end

      def transcribe_window(i, p)
        base   = File.join(IngestMedia::RETENTION_ROOT, @mid.to_s, "chunks", format("chunk_%03d", i))
        recipe = File.join(Zdots::ZDOTDIR, "recipes", "yt-transcribe")
        cmd = [recipe, "--from-wav", p.fetch("wav"),
               "--offset-sec", p.fetch("offset_sec").to_s,
               "--window-sec", p.fetch("window_sec").to_s,
               "--output-base", base, "--profile", (p["profile"] || "standard")]
        vocab = IngestMedia.known_vocabulary
        cmd += ["--prompt", vocab] unless vocab.empty?
        puts "  --> chunk #{i}: #{cmd.join(' ')}"
        out, status = Open3.capture2e(*cmd)
        raise "chunk #{i} failed: #{out}" unless status.success?
        txt = "#{base}.txt"
        raise "chunk #{i} produced no transcript at #{txt}" unless File.file?(txt)
        txt
      end
    end
  end
end

# ponytail: self-check the overlap-dedup seam — the one branch that drops or
# duplicates words if wrong. Run: ruby lib/zdots/jobs/transcribe_chunk.rb
if __FILE__ == $PROGRAM_NAME
  s = Zdots::Jobs::TranscribeChunk
  raise "overlap"     unless s.splice("a b c d", "c d e f") == "a b c d e f"
  raise "no overlap"  unless s.splice("a b c", "d e f")     == "a b c d e f"
  raise "full dup"    unless s.splice("a b c", "a b c")     == "a b c"
  raise "case-insens" unless s.splice("Foo Bar", "bar Baz") == "Foo Bar Baz"
  puts "transcribe_chunk splice: OK"
end
