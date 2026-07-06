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
      # upgrade: add a stale-"running" reaper if strands stop being rare.
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

      # Normalize a word for seam comparison: casing and surrounding punctuation
      # diverge between independently-decoded windows, so strip both.
      def self.norm(w)
        w.downcase.gsub(/[^a-z0-9']/, "")
      end

      # Fuzzy word-overlap splice: drop B's leading words that duplicate A's
      # trailing words at the window seam, so it reads once. Windows now decode
      # independently (--max-context 0), so the shared ~15s overlap can diverge on
      # punctuation/casing/filler — compare NORMALIZED tokens and accept the
      # largest overlap that mismatches at most ~1 word per 10. Bias conservative:
      # a missed overlap duplicates the seam (safe, visible); an over-eager match
      # DROPS real words (data loss). Keeps A's casing.
      def self.splice(a, b, max_words: 256)
        aw = a.split
        bw = b.split
        an = aw.map { |w| norm(w) }
        bn = bw.map { |w| norm(w) }
        k_max = [aw.size, bw.size, max_words].min
        best = 0
        (1..k_max).each do |k|
          matches = an.last(k).zip(bn.first(k)).count { |x, y| x == y && !x.empty? }
          best = k if matches >= k - (k / 10)
        end
        warn "splice: no overlap found at a long #{aw.size}+#{bw.size}-word seam" if best.zero? && aw.size > max_words && bw.size > max_words
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
        out, status = Zdots.run_bounded(*cmd, timeout: IngestMedia::RECIPE_TIMEOUT, merge_err: true)
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
  # punctuation diverges across the seam but the word is the same -> still merges
  raise "punct"       unless s.splice("keep a b c,", "c d e") == "keep a b c, d e"
  # one divergent word inside a long overlap (fife vs five) -> one seam, keep A's
  raise "fuzzy-long"  unless s.splice(
    "intro one two three four five six seven eight nine ten eleven",
    "one two three four fife six seven eight nine ten eleven post"
  ) == "intro one two three four five six seven eight nine ten eleven post"
  # unrelated windows must NOT over-merge (no words dropped)
  raise "no-merge"    unless s.splice("the quick brown fox", "lazy dog runs fast") == "the quick brown fox lazy dog runs fast"
  puts "transcribe_chunk splice: OK"
end
