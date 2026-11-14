# frozen_string_literal: true

module Zdots
  module Contracts
    class Error < StandardError; end

    # Immutable, validated contract for the cross-repo media ingestion seam
    # (media-pipeline / bin/zdots-ingest-media -> sbin/zdots-brain ingest-media).
    class IngestMediaPayload < Data.define(
      :source_uri,
      :source_type,
      :source_id,
      :title,
      :duration_sec,
      :profile,
      :force,
      :primer_text,
      :tags,
      :num_speakers,
      :transcript_text,
      :transcript_vtt,
      :source_snapshot,
      :panoramic_meta
    )
      PROFILES = %w[standard max-accuracy light].freeze
      PANORAMIC_KEYS = %w[
        panoramic_journey_id panoramic_run_id panoramic_correlation_id
        panoramic_workflow_id panoramic_flow_id panoramic_run_class
      ].freeze

      def self.from_hash(raw, env: ENV)
        raise Error, "ingest payload must be a Hash" unless raw.is_a?(Hash)

        uri = raw["source_uri"].to_s.strip
        raise Error, "source_uri is required" if uri.empty?

        profile = (raw["profile"] || "standard").to_s
        raise Error, "unsupported whisper profile: #{profile}" unless PROFILES.include?(profile)

        duration = raw["duration_sec"]
        if !duration.nil? && (!duration.is_a?(Integer) || duration.negative?)
          raise Error, "duration_sec must be a non-negative Integer"
        end

        num_speakers = raw["num_speakers"]
        if !num_speakers.nil? && (!num_speakers.is_a?(Integer) || num_speakers <= 0)
          raise Error, "num_speakers must be a positive Integer"
        end

        tags = Array(raw["tags"]).map { |t| t.to_s.strip }.reject(&:empty?).uniq.freeze
        primer = raw["primer_text"].to_s.strip
        primer_val = primer.empty? ? nil : primer

        t_txt = raw["transcript_text"].to_s
        txt_val = t_txt.strip.empty? ? nil : t_txt
        t_vtt = raw["transcript_vtt"].to_s
        vtt_val = t_vtt.strip.empty? ? nil : t_vtt

        snapshot = raw["source_snapshot"]
        raise Error, "source_snapshot must be a Hash" unless snapshot.nil? || snapshot.is_a?(Hash)

        traceparent = raw["traceparent"].to_s.strip
        traceparent = env["TRACEPARENT"].to_s.strip if traceparent.empty?
        trace_id = raw["trace_id"].to_s.strip
        trace_id = env["ZDOTS_TRACE_ID"].to_s.strip if trace_id.empty?
        parent_span_id = raw["parent_span_id"].to_s.strip
        parent_span_id = env["ZDOTS_PARENT_SPAN_ID"].to_s.strip if parent_span_id.empty?

        if trace_id.empty? && traceparent =~ /\A00-([0-9a-f]{32})-([0-9a-f]{16})-[0-9a-f]{2}\z/i
          trace_id = Regexp.last_match(1).downcase
          parent_span_id = Regexp.last_match(2).downcase if parent_span_id.empty?
        end

        p_meta = {}
        PANORAMIC_KEYS.each do |k|
          val = raw[k].to_s.strip
          p_meta[k] = val unless val.empty?
        end
        p_meta["traceparent"] = traceparent unless traceparent.empty?
        p_meta["trace_id"] = trace_id unless trace_id.empty?
        p_meta["parent_span_id"] = parent_span_id unless parent_span_id.empty?

        new(
          source_uri: uri,
          source_type: raw["source_type"]&.to_s,
          source_id: raw["source_id"]&.to_s,
          title: raw["title"]&.to_s,
          duration_sec: duration,
          profile: profile,
          force: raw["force"] == true,
          primer_text: primer_val,
          tags: tags,
          num_speakers: num_speakers,
          transcript_text: txt_val,
          transcript_vtt: vtt_val,
          source_snapshot: (snapshot || {}).freeze,
          panoramic_meta: p_meta.freeze
        )
      end

      def job_payload(media_source_id:)
        raise Error, "media_source_id must be a positive Integer" unless media_source_id.is_a?(Integer) && media_source_id.positive?

        out = { "media_source_id" => media_source_id, "profile" => profile }.merge(panoramic_meta)
        out["num_speakers"] = num_speakers if num_speakers
        out
      end
    end
  end
end
