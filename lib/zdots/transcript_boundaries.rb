# frozen_string_literal: true

require "yaml"
require "json"

module Zdots
  # Detect the real interview span by finding theme-song intro/outro blocks in a
  # timestamped transcript. NON-DESTRUCTIVE: it only annotates boundaries — the
  # recording (and its jingle) stays intact so intro/outro can be handled for
  # editing/display and timestamps still map to the full audio.
  #
  # Shared by two callers (per ADR: one logic, two entry points):
  #   - the ingest_media `boundaries` pipeline stage (future ingests)
  #   - a thin backfill pass over existing whisper JSONs (no re-transcription)
  module TranscriptBoundaries
    module_function

    DEFAULT_JINGLES = File.expand_path("../../etc/theme-songs.yml", __dir__)
    # How far from each edge a jingle may reach. Intros/outros are short; this
    # bounds false positives from an interview merely mentioning a phrase midway.
    EDGE_WINDOW_SEC = 120.0

    def load_jingles(path = DEFAULT_JINGLES)
      return [] unless File.exist?(path)
      Array(YAML.safe_load(File.read(path))).map do |j|
        {
          id:        j["id"],
          has_lyrics: j.fetch("has_lyrics", false),
          phrases:   Array(j["detect_phrases"]).map { |p| norm(p) },
          end_anchor: j["end_anchor"] && norm(j["end_anchor"])
        }
      end
    end

    # whisper.cpp JSON → [{ from: sec, to: sec, text: }] sorted by start.
    def segments_from_whisper(json_path)
      doc  = JSON.parse(File.read(json_path))
      segs = doc["transcription"] || doc["segments"] || []
      segs.map { |s|
        off = s["offsets"] || {}
        { from: (s["start"] || off["from"] || 0).to_f / 1000.0,
          to:   (s["end"]   || off["to"]   || 0).to_f / 1000.0,
          text: s["text"].to_s }
      }.sort_by { |s| s[:from] }
    end

    # Returns the `recording` metadata hash. duration_sec falls back to the last
    # segment's end when unknown.
    def detect(segments, duration_sec, jingles)
      dur = (duration_sec && duration_sec > 0 ? duration_sec.to_f : (segments.last&.fetch(:to) || 0.0))
      return no_jingle(segments, dur) if segments.empty? || jingles.empty?

      intro = detect_intro(segments, jingles)
      outro = detect_outro(segments, dur, jingles)

      rec = {
        "duration_sec"        => round(dur),
        "interview_start_sec" => round(intro ? intro["end_sec"]   : (segments.first[:from])),
        "interview_end_sec"   => round(outro ? outro["start_sec"] : dur),
        "has_lyrics"          => [intro, outro].compact.any? { |b| b["has_lyrics"] }
      }
      rec["intro"] = intro if intro
      rec["outro"] = outro if outro
      rec
    end

    # ---- internals -------------------------------------------------------------

    def detect_intro(segments, jingles)
      # Walk forward while segments (within the opening window) belong to a jingle.
      last = -1
      hit_lyrics = false
      segments.each_with_index do |s, i|
        break if s[:from] > EDGE_WINDOW_SEC
        j = match(s, jingles)
        if j
          last = i
          hit_lyrics ||= j[:has_lyrics]
        elsif last >= 0 && !between_jingle?(s, jingles)
          # first real-speech segment after the jingle run → intro ends
          break
        end
      end
      return nil if last < 0
      { "start_sec" => round(segments.first[:from]), "end_sec" => round(segments[last][:to]),
        "kind" => "theme_song", "has_lyrics" => hit_lyrics }
    end

    def detect_outro(segments, dur, jingles)
      last = -1
      hit_lyrics = false
      segments.each_index.reverse_each do |i|
        s = segments[i]
        break if s[:to] < dur - EDGE_WINDOW_SEC
        j = match(s, jingles)
        if j
          last = i
          hit_lyrics ||= j[:has_lyrics]
        elsif last >= 0 && !between_jingle?(s, jingles)
          break
        end
      end
      return nil if last < 0
      { "start_sec" => round(segments[last][:from]), "end_sec" => round(dur),
        "kind" => "theme_song", "has_lyrics" => hit_lyrics }
    end

    def no_jingle(segments, dur)
      { "duration_sec" => round(dur),
        "interview_start_sec" => round(segments.first&.fetch(:from) || 0.0),
        "interview_end_sec" => round(dur),
        "has_lyrics" => false }
    end

    # A segment matches a jingle if its text contains a distinctive phrase or the
    # closing anchor.
    def match(seg, jingles)
      t = norm(seg[:text])
      jingles.find { |j| j[:phrases].any? { |p| t.include?(p) } || (j[:end_anchor] && t.include?(j[:end_anchor])) }
    end

    # Short bridging segment ([Music], a stray token) allowed inside a jingle run.
    def between_jingle?(seg, _jingles)
      t = norm(seg[:text])
      t.empty? || t.include?("music") || t.length < 4
    end

    def norm(str)
      str.to_s.downcase.gsub(/[^a-z0-9. ]/, " ").squeeze(" ").strip
    end

    def round(x)
      (x.to_f * 10).round / 10.0
    end
  end
end

# --- self-check: ruby lib/zdots/transcript_boundaries.rb --------------------
if __FILE__ == $PROGRAM_NAME
  include Zdots
  jingles = [{ id: "ug", has_lyrics: true,
               phrases: ["plethora of information", "user groups with lots to say"],
               end_anchor: "ugtastic.com" }]

  # jingle intro, no outro
  segs = [
    { from: 0.0,  to: 4.4,  text: " User groups with lots to say, interviews and more" },
    { from: 4.4,  to: 9.0,  text: " Sharing great ideas, a plethora of information" },
    { from: 13.0, to: 16.0, text: " find out for yourself today at ugtastic.com." },
    { from: 16.0, to: 20.9, text: " Hi, it's Mike with UGtastic, here at RailsConf" },
    { from: 20.9, to: 25.0, text: " standing with DHH." }
  ]
  r = TranscriptBoundaries.detect(segs, 942.0, jingles)
  raise "intro end #{r['interview_start_sec']}" unless r["interview_start_sec"] == 16.0
  raise "has_lyrics" unless r["has_lyrics"] == true
  raise "intro block" unless r["intro"] && r["intro"]["end_sec"] == 16.0
  raise "no outro expected" if r["outro"]

  # no jingle at all
  plain = [{ from: 0.0, to: 5.0, text: " Welcome everyone to this talk about databases." },
           { from: 5.0, to: 9.0, text: " Today we cover indexing." }]
  r2 = TranscriptBoundaries.detect(plain, 300.0, jingles)
  raise "no-jingle start" unless r2["interview_start_sec"] == 0.0
  raise "no-jingle has_lyrics" unless r2["has_lyrics"] == false
  raise "no-jingle must have no intro" if r2["intro"]

  # intro + outro
  book = segs + [
    { from: 900.0, to: 905.0, text: " thanks for watching" },
    { from: 905.0, to: 909.0, text: " user groups with lots to say, interviews and more" },
    { from: 909.0, to: 942.0, text: " a plethora of information at ugtastic.com" }
  ]
  r3 = TranscriptBoundaries.detect(book, 942.0, jingles)
  raise "outro missing" unless r3["outro"]
  raise "interview_end #{r3['interview_end_sec']}" unless r3["interview_end_sec"] == 905.0

  puts "transcript_boundaries self-check OK"
end
