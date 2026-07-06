# frozen_string_literal: true

require_relative "base"
require_relative "../models/media_source"
require_relative "../models/pipeline_run"
require_relative "../models/job"
require_relative "../ai/phi_scrubber"
require_relative "../bounded_run"
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

      # Z-169 chunking knobs (env-overridable). Sources longer than the threshold
      # fan out into overlapping windows transcribed as separate queue jobs.
      CHUNK_THRESHOLD_SEC = (ENV["ZDOTS_CHUNK_THRESHOLD_SEC"] || 1800).to_i
      CHUNK_WINDOW_SEC    = (ENV["ZDOTS_CHUNK_WINDOW_SEC"]    || 600).to_i
      CHUNK_OVERLAP_SEC   = (ENV["ZDOTS_CHUNK_OVERLAP_SEC"]   || 15).to_i

      # ── Declared pipeline (Z-188) ────────────────────────────────────────────
      # Single source of truth for the ingest process SHAPE. #run walks this list;
      # docs/generated/ingest-pipeline.mmd is a Mermaid projection of it, kept
      # honest by tests/ingest_pipeline_diagram.bats (drift fails the build). This
      # is "BPMN as description, code as execution": the code is authoritative, the
      # diagram is generated FROM it — never the reverse (no designer, no XML
      # runtime). Add a stage here → the executor (#run_stage) and the diagram both
      # follow; P2/P3 hooks (hint capture, diarization) attach as new stages/events
      # HERE, not as ad-hoc code in #run.
      PIPELINE = [
        { stage: "raw",       desc: "transcribe audio (whisper; chunk fan-out if long)" },
        { stage: "cleaned",   desc: "apply known_terms corrections" },
        { stage: "distilled", desc: "LLM knowledge briefing (local, or scoped cloud)" },
        { stage: "diarized",  desc: "acoustic speaker turns (pyannote; opt-in ZDOTS_DIARIZE)" }
      ].freeze

      def run
        @mid      = payload.fetch("media_source_id")
        @profile  = payload["profile"] || "standard"
        @src      = Models::MediaSource[@mid] or raise "media_source not found: #{@mid}"
        @out_base = File.join(RETENTION_ROOT, @mid.to_s)
        FileUtils.mkdir_p(@out_base)

        @src.update(ingest_status: "running")
        # Thin executor: walk the declared graph. The raw stage may fan out into
        # chunk jobs and defer (:pending) — stop; the fan-in re-enqueues this job
        # to finish the remaining stages.
        PIPELINE.each { |step| return true if run_stage(step[:stage]) == :pending }
        @src.update(ingest_status: "done")
        true
      rescue StandardError => e
        @src&.update(ingest_status: "failed")
        raise e
      end

      # Bind each declared stage to its implementation. A PIPELINE stage with no
      # binding here (or an orphan binding not in PIPELINE) is a bug — the former
      # raises loudly, the latter simply never runs.
      def run_stage(name)
        case name
        when "raw"       then @raw_txt = ensure_raw
        when "cleaned"   then stage("cleaned")   { clean_transcript(@raw_txt) }
        when "distilled" then stage("distilled") { distill(@raw_txt) }
        when "diarized"  then run_diarized
        else raise "unknown pipeline stage: #{name.inspect}"
        end
      end

      # Diarized is opt-in (ZDOTS_DIARIZE=1) and best-effort. It depends on an
      # unverified external toolchain (uv-resolved pyannote+torch, gated model), so
      # keeping it off by default AND rescuing here stops a dep/env failure from
      # dead-lettering the whole ingest — raw/cleaned/distilled already produced
      # their value, and this is the LAST stage. Off → returns nil (pipeline
      # continues). Mirrors the DISTILL_CLOUD opt-in + cloud_distill fallback idiom.
      def run_diarized
        return nil unless ENV["ZDOTS_DIARIZE"] == "1"
        stage("diarized") { diarize_audio }
      rescue StandardError => e
        warn "ingest_media: diarize stage failed (#{e.message}); continuing"
        nil
      end

      # Mermaid projection of PIPELINE — the process description, generated FROM
      # the executable. Regenerate the committed copy with:
      #   zdots-ruby -e 'require "./lib/zdots"; require "./lib/zdots/jobs/ingest_media"; \
      #     print Zdots::Jobs::IngestMedia.to_mermaid' > docs/generated/ingest-pipeline.mmd
      def self.to_mermaid
        lines = ["flowchart TD", "  queued([queued]) --> #{PIPELINE.first[:stage]}"]
        PIPELINE.each_with_index do |s, i|
          lines << %(  #{s[:stage]}["#{s[:stage]} — #{s[:desc]}"])
          nxt = PIPELINE[i + 1]
          lines << "  #{s[:stage]} --> #{nxt[:stage]}" if nxt
        end
        lines << "  #{PIPELINE.last[:stage]} --> done([done])"
        "#{lines.join("\n")}\n"
      end

      # The known-vocabulary priming prompt (the doubt loop's proactive half).
      # Class method so the per-chunk transcriber (Z-169) reuses it. Capped to
      # whisper's prompt budget.
      def self.known_vocabulary
        terms = Zdots.db[:known_terms].order(:canonical).limit(100).select_map(:canonical)
        terms.empty? ? "" : "Vocabulary: #{terms.join(', ')}."
      end

      private

      # Raw stage, chunk-aware + resumable. A done whole-stage summary row
      # short-circuits (resume). Short sources transcribe inline; long sources
      # (> CHUNK_THRESHOLD_SEC) fan out and return :pending — TranscribeChunk
      # stitches and re-enqueues this job to finish cleaned/distilled.
      def ensure_raw
        summary = Models::PipelineRun.first(media_source_id: @mid, stage: "raw", chunk_index: nil)
        return summary.artifact_path if summary&.status == "done"

        dur = @src.duration_sec.to_i
        return plan_chunks(dur) if dur > CHUNK_THRESHOLD_SEC

        stage("raw") { { path: transcribe_raw, params: { "profile" => @profile } } }
      end

      # Plan overlapping windows and enqueue a transcribe_chunk job per window
      # that isn't already done (idempotent → resume re-enqueues only the gaps).
      def plan_chunks(dur)
        wav  = prep_audio
        step = CHUNK_WINDOW_SEC - CHUNK_OVERLAP_SEC
        n    = [((dur - CHUNK_OVERLAP_SEC).to_f / step).ceil, 1].max
        pending = 0
        (0...n).each do |i|
          next if upsert_run(@mid, "raw", chunk_index: i).status == "done"
          enqueue_chunk(i, offset: i * step, n: n, wav: wav)
          pending += 1
        end
        puts "  --> #{n} chunks planned, #{pending} enqueued (window=#{CHUNK_WINDOW_SEC}s overlap=#{CHUNK_OVERLAP_SEC}s)"
        if pending.zero?
          # All chunks already done but no summary — drive the reduce directly
          # (covers a planning retry that lands after the last chunk finished).
          require_relative "transcribe_chunk"
          TranscribeChunk.reduce_if_complete(@mid, n, @profile)
        end
        :pending
      end

      # Download + convert to a 16k wav once, kept for the chunk jobs. Idempotent:
      # a prior run's wav is reused, so resume never re-downloads.
      def prep_audio
        require_fetchable!
        wav = Dir.glob(File.join(@out_base, "*", "*_16k.wav")).max_by { |f| File.size(f) }
        return wav if wav && File.file?(wav)

        recipe = File.join(Zdots::ZDOTDIR, "recipes", "yt-transcribe")
        out, status = Open3.capture2e(recipe, @src.source_uri, "--prep-only", "--out-dir", @out_base)
        raise "prep-only failed: #{out}" unless status.success?
        (out[/^WAV=(.+)$/, 1] || raise("prep-only did not report WAV path")).strip
      end

      def enqueue_chunk(i, offset:, n:, wav:)
        payload = { "media_source_id" => @mid, "chunk_index" => i, "offset_sec" => offset,
                    "window_sec" => CHUNK_WINDOW_SEC, "n" => n, "wav" => wav, "profile" => @profile }
        Models::Job.dataset.insert_conflict(target: :fingerprint).insert(
          type: "transcribe_chunk", payload: Sequel.pg_jsonb(payload), priority: 10,
          fingerprint: Digest::MD5.hexdigest("transcribe_chunk-#{@mid}-#{i}")
        )
      end

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

      def upsert_run(mid, stage, chunk_index: nil)
        Models::PipelineRun.first(media_source_id: mid, stage: stage, chunk_index: chunk_index) ||
          Models::PipelineRun.create(media_source_id: mid, stage: stage, chunk_index: chunk_index, status: "pending")
      end

      # Decouple downloader from processor: the recipe (yt-dlp) IS the fetcher and
      # handles any URL source it supports — youtube, vimeo, twitter, … — so the
      # processor doesn't gatekeep by platform. The one real exception is a
      # 'local' source, whose path isn't stored (PHI policy Z-163: source_uri is a
      # local:sha256 pseudo-URI, not re-fetchable); that still needs an
      # ingest-time retention copy — not yet implemented.
      def require_fetchable!
        return unless @src.source_type == "local"
        raise "local sources need a retention-store copy at ingest time (not yet implemented)"
      end

      # Re-fetch + whisper into the retention store.
      def transcribe_raw
        require_fetchable!
        recipe = File.join(Zdots::ZDOTDIR, "recipes", "yt-transcribe")
        cmd = [recipe, @src.source_uri, "--profile", @profile, "--json-full", "--out-dir", @out_base]
        vocab = self.class.known_vocabulary
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

      # Whole-file acoustic diarization over the retained 16k wav → a self-contained
      # diarization.json (pyannote turns; the site's TASK-247 binds M1/S1/S2 →
      # SPEAKER_xx from it). Independent of the text stages — consumes the audio,
      # not the transcript. prep_audio returns the retained wav (long/chunked path)
      # or re-preps it (short path deletes its wav after whisper). num_speakers is a
      # caller-passed hint (site: interviewees + 1) — tenant data, never computed here.
      def diarize_audio
        wav = prep_audio
        out = File.join(File.dirname(wav), "diarization.json")
        diarize = File.join(Zdots::ZDOTDIR, "bin", "diarize")
        cmd = [diarize, wav, "--sidecar", out]
        hint = payload["num_speakers"]
        cmd += ["--num-speakers", hint.to_s] if hint
        stdout_err, status = Open3.capture2e(*cmd)
        raise "diarize failed: #{stdout_err}" unless status.success?
        { path: out, params: { "engine" => "pyannote-3.1", "num_speakers" => hint } }
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
        briefing, model = distill_briefing(source)
        File.write(out, briefing)
        { path: out, params: { "model" => model, "input_chars" => source.length } }
      end

      # Scoped, opt-in cloud distill (ADR-0003). Default local. The cloud path is
      # taken ONLY when the flag is on, the source is public (YouTube/Vimeo —
      # hard-asserted), and the claude CLI is available; the PHI Scrubber still
      # runs first, and any failure falls back to local. ai-query's shared
      # default is never touched. Records which model produced the briefing.
      #
      # Egress goes through the `claude` CLI (Claude Code / zclaude auth) — this
      # machine has no Anthropic API key. See ADR-0003.
      DISTILL_CLOUD       = ENV["ZDOTS_DISTILL_CLOUD"] == "1"
      # .strip.empty? guard: the worker passthrough exports an empty string when
      # unset, and Ruby's `|| "haiku"` only catches nil — "" would win and send
      # `--model ""` (a 400 from the API).
      DISTILL_CLOUD_MODEL = ENV["ZDOTS_DISTILL_CLOUD_MODEL"].to_s.strip.then { |m| m.empty? ? "haiku" : m }
      # Wall-clock ceiling for the cloud call. "Inaccessible" isn't only an absent
      # binary (claude_available? covers that) — the binary can be present while
      # Anthropic is unreachable, hanging `claude -p` indefinitely. Bounded so the
      # ingest pipeline degrades to local instead of stalling. Env-overridable
      # because a long transcript → Haiku one-shot can legitimately run a while.
      DISTILL_CLOUD_TIMEOUT = (ENV["ZDOTS_DISTILL_CLOUD_TIMEOUT"] || 120).to_i

      def distill_briefing(source)
        if cloud_distill_eligible?
          begin
            briefing = cloud_distill(source)
            warn "ingest_media: distilled via cloud (#{DISTILL_CLOUD_MODEL}) source=#{@mid}"
            return [briefing, "cloud:#{DISTILL_CLOUD_MODEL}"]
          rescue StandardError => e
            warn "ingest_media: cloud distill failed (#{e.message}); falling back to local"
          end
        end
        [ai_distill(source), "local"]
      end

      # All three must hold to send a byte to the cloud.
      def cloud_distill_eligible?
        DISTILL_CLOUD && public_source? && claude_available?
      end

      # Hard public-content gate: a local-file (or any non-public) ingest can
      # NEVER take the cloud path, even with the flag on.
      def public_source?
        %w[youtube vimeo].include?(@src&.source_type.to_s.downcase)
      end

      # The claude CLI (Claude Code / zclaude auth) is the cloud egress — no API
      # key on this machine. Absent → not eligible → stays local.
      def claude_bin
        @claude_bin ||= (`command -v claude 2>/dev/null`.strip rescue "")
      end

      def claude_available?
        !claude_bin.empty?
      end

      # PHI Scrubber first (defense-in-depth even for public content; raises on a
      # suppress-flagged pattern → caller falls back to local), then one headless
      # `claude -p` call. The model (Haiku) has a large context, so the whole
      # transcript goes in one shot — no windowing. The task is the prompt arg;
      # the transcript is piped on stdin (the `cat file | claude -p` pattern).
      def cloud_distill(source)
        scrubbed = Zdots::AI::PhiScrubber.call(source)
        out, status = Zdots.run_bounded(
          claude_bin, "-p", "--model", DISTILL_CLOUD_MODEL,
          "--no-session-persistence", DISTILL_TASK,
          stdin_data: scrubbed, timeout: DISTILL_CLOUD_TIMEOUT
        )
        raise "claude CLI failed (exit #{status.exitstatus}): #{out.to_s[0, 200]}" unless status.success?

        briefing = out.strip
        raise "claude CLI returned no text" if briefing.empty?

        briefing
      end

      DISTILL_TASK =
        "Distill this transcript into a knowledge briefing. Each line is prefixed " \
        "with its [mm:ss] timestamp. Output markdown: a one-line summary, then 5-12 " \
        "key insights as bullets. Begin every bullet with the [mm:ss] of the moment " \
        "it draws from. Be faithful — invent nothing not in the transcript."

      DISTILL_MAP_TASK =
        "Distill this transcript SEGMENT into 3-8 key insight bullets. Lines may be " \
        "prefixed with an [mm:ss] timestamp; when present, begin the bullet with it. " \
        "Be faithful — invent nothing not in the segment."

      DISTILL_REDUCE_TASK =
        "Below are insight bullets distilled from consecutive segments of ONE " \
        "transcript. Merge them into a single knowledge briefing: a one-line summary, " \
        "then 5-12 deduplicated key insights as bullets in chronological order, each " \
        "beginning with its [mm:ss] when available. Invent nothing beyond the bullets."

      # ai-query enforces a hard input ceiling (AIQ_MAX_BYTES, ~32KB) sized to the
      # local model's context; a long transcript (a 3.5h video ≈ 220KB) blows past
      # it → exit 3. So distill map-reduces: distill each sub-ceiling window, then
      # synthesize the partials into one briefing (folding in rounds if the joined
      # partials themselves overflow — terminates because each round shrinks).
      DISTILL_CEILING = (ENV["AIQ_MAX_BYTES"] || "32768").to_i
      DISTILL_WINDOW  = (DISTILL_CEILING * 0.85).to_i # headroom for normalization

      def ai_distill(transcript)
        windows = split_for_distill(transcript)
        return distill_call(DISTILL_TASK, transcript) if windows.size <= 1

        partials = windows.map { |w| distill_call(DISTILL_MAP_TASK, w) }
        reduce_partials(partials.join("\n\n"))
      end

      def reduce_partials(text)
        windows = split_for_distill(text)
        return distill_call(DISTILL_REDUCE_TASK, text) if windows.size <= 1

        folded = windows.map { |w| distill_call(DISTILL_REDUCE_TASK, w) }
        reduce_partials(folded.join("\n\n"))
      end

      # Split into <DISTILL_WINDOW-byte windows on whole units — lines when the text
      # has them, else whitespace-delimited words (a stitched transcript is often one
      # giant line). Unit-wise concat keeps UTF-8 intact (no mid-char byteslicing).
      def split_for_distill(text)
        return [text] if text.bytesize <= DISTILL_WINDOW

        units = text.include?("\n") ? text.each_line.to_a : text.scan(/\S+\s*/)
        windows = []
        cur = +""
        units.each do |u|
          if !cur.empty? && cur.bytesize + u.bytesize > DISTILL_WINDOW
            windows << cur
            cur = +""
          end
          cur << u
        end
        windows << cur unless cur.empty?
        windows
      end

      def distill_call(task, input)
        ai_query = File.join(Zdots::ZDOTDIR, "bin", "ai-query")
        out, status = Open3.capture2(ai_query, task, stdin_data: input)
        raise "ai-query failed (exit #{status.exitstatus})" unless status.success?
        # Open3 tags subprocess output with the process default_external, which is
        # US-ASCII under launchd (no LANG); the model emits UTF-8 (em-dashes, smart
        # quotes) → strip/scan blow up. The bytes are UTF-8, so retag them.
        out.force_encoding(Encoding::UTF_8).strip
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
    end
  end
end
