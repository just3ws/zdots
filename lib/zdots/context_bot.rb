# frozen_string_literal: true

require_relative "bus"
require_relative "models/media_source"
require_relative "models/pipeline_run"
require_relative "bounded_run"

module Zdots
  # A bus participant that speaks for the context-engine: watches channels
  # live (same Bus.subscribe mechanism bus-watch uses) and answers questions
  # addressed to it, grounded only in already-vetted pipeline data —
  # media_source title/tags/primer_text and pipeline_runs stage/status, the
  # same fields IngestMedia's own #narrate treats as PHI-safe (see Z-163) —
  # plus the channel's own bus history. Never reaches past that.
  module ContextBot
    DEFAULT_NAME    = "context-engine"
    DEFAULT_TRIGGER = "@context-engine"
    HISTORY_LIMIT   = 30
    AI_QUERY_TIMEOUT = 120

    INFORMATIVE_PROMPT =
      "You are an informative background coordinator for the message bus. " \
      "Your role is strictly informative, NEVER performative: you report status, explain context, " \
      "and answer questions using ONLY the verified context below. You do not execute commands, " \
      "alter code, deploy services, or claim to take actions you cannot take. " \
      "If a request asks you to perform an action or run a task, clarify your role as an informative status agent. " \
      "Be brief (1-4 sentences), factual, and grounded. If the context doesn't contain the answer, " \
      "state that plainly rather than guessing."

    class << self
      def bot_name
        ENV.fetch("ZDOTS_BUS_BOT_NAME", DEFAULT_NAME)
      end

      def bot_trigger
        ENV.fetch("ZDOTS_BUS_BOT_TRIGGER", "@#{bot_name}")
      end

      def answer_task
        ENV.fetch("ZDOTS_BUS_BOT_PROMPT", INFORMATIVE_PROMPT)
      end

      # patterns: channel names, "*" glob-matched against the channels that
      # exist right now. Resolved once at startup — a channel created after
      # that point isn't picked up until the bot is restarted (v1 limitation,
      # see docs/message-bus.md).
      def run(patterns = nil)
        patterns ||= ENV["ZDOTS_BUS_BOT_CHANNELS"]&.split(/[,\s]+/) || ["general", "ingest-*"]
        name = bot_name
        Bus.register_participant(name, kind: "bot")
        channels = matching_channels(patterns)
        if channels.empty?
          warn "context-bot: no channels matched #{patterns.inspect}"
          return
        end

        warn "context-bot (#{name}): watching #{channels.join(', ')} (trigger: #{bot_trigger})"
        channels.map { |ch| Thread.new { watch(ch) } }.each(&:join)
      end

      private

      def matching_channels(patterns)
        globs = patterns.map { |p| glob_to_regex(p) }
        Bus.channels.map(&:name).select { |n| globs.any? { |g| g.match?(n) } }
      end

      def glob_to_regex(pattern)
        parts = pattern.split("*", -1).map { |s| Regexp.escape(s) }
        Regexp.new("\\A#{parts.join('.*')}\\z")
      end

      # One thread per channel; a dead subscriber (Redis hiccup, etc.) just
      # warns and lets the other channels' watchers keep running.
      def watch(channel)
        Bus.subscribe(channel) { |msg| handle(channel, msg) }
      rescue StandardError => e
        warn "context-bot: watcher for #{channel} died (#{e.class}: #{e.message})"
      end

      def handle(channel, msg)
        name = bot_name
        return if msg[:participant] == name # never reply to itself

        body = msg[:body].to_s
        trigger = bot_trigger
        return unless body.start_with?(trigger)

        question = body.sub(trigger, "").strip
        reply = answer(channel, question)
        Bus.post(channel, name, reply, thread: msg[:id])
      rescue StandardError => e
        warn "context-bot: reply failed (#{e.class}: #{e.message})"
        begin
          Bus.post(channel, bot_name, "#{bot_name}: couldn't answer right now", thread: msg[:id])
        rescue StandardError
          nil
        end
      end

      def answer(channel, question)
        ai_query(answer_task, "#{gather_context(channel)}\n\nQuestion: #{question}")
      end

      def gather_context(channel)
        [history(channel), source_summary_for(channel)].compact.join("\n\n")
      end

      def history(channel)
        msgs = Bus.read(channel, limit: HISTORY_LIMIT)
        return "(no prior messages)" if msgs.empty?

        msgs.map { |m| "#{Bus.participant_name(m.participant_id)}: #{m.body}" }.join("\n")
      end

      # ingest-<source_id> channels get their media_source/pipeline_runs state
      # folded in — "remembering key data points from the transcription
      # pipeline" without re-deriving anything IngestMedia hasn't already
      # vetted as safe to surface.
      def source_summary_for(channel)
        return nil unless channel.start_with?("ingest-")

        src = media_source_for(channel.sub(/\Aingest-/, ""))
        return nil unless src

        runs = Models::PipelineRun.where(media_source_id: src.id).order(:created_at).all
        stages = runs.map { |r| "#{r.stage}=#{r.status}" }.join(", ")
        [
          "Source: #{src.title}",
          (Array(src.tags).empty? ? nil : "Tags: #{Array(src.tags).join(', ')}"),
          (src.primer_text.to_s.strip.empty? ? nil : "Primer: #{src.primer_text}"),
          (stages.empty? ? nil : "Stages: #{stages}")
        ].compact.join("\n")
      end

      def media_source_for(source_id)
        Models::MediaSource.first(source_id: source_id) || safe_lookup_by_id(source_id)
      end

      # The channel suffix is usually a source_id, but IngestMedia falls back
      # to the media_source_id (uuid) when source_id is blank — try that too,
      # tolerating a non-uuid string.
      def safe_lookup_by_id(id)
        Models::MediaSource[id]
      rescue Sequel::DatabaseError
        nil
      end

      # Same subprocess pattern as IngestMedia#distill_call: bounded, and the
      # output is retagged UTF-8 because launchd has no LANG (defaults to
      # US-ASCII), while the model emits UTF-8.
      def ai_query(task, input)
        bin = File.join(Zdots::ZDOTDIR, "bin", "ai-query")
        out, status = Zdots.run_bounded(bin, "--timeout", AI_QUERY_TIMEOUT.to_s, task,
                                        stdin_data: input, timeout: AI_QUERY_TIMEOUT)
        raise "ai-query failed (exit #{status.exitstatus})" unless status.success?

        out.force_encoding(Encoding::UTF_8).strip
      end
    end
  end
end
