# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "base"
require_relative "../models/media_source"

module Zdots
  module Jobs
    class ExtractMoment < Base
      Jobs.register "extract_moment", self

      RETENTION_ROOT = File.expand_path(
        ENV["ZDOTS_INGEST_SOURCES_DIR"] || "~/.local/state/zdots/ingest-sources"
      )

      def run
        media_source_id = payload["media_source_id"]
        start_sec = payload["start_sec"]
        end_sec = payload["end_sec"]
        kind = payload["kind"]
        
        return true if kind == "excerpt"

        source = Zdots::Models::MediaSource[media_source_id]
        raise "media_source not found: #{media_source_id}" unless source

        out_dir = File.join(RETENTION_ROOT, media_source_id.to_s, "extracts")
        FileUtils.mkdir_p(out_dir)

        Dir.mktmpdir do |dir|
          tmp_video = File.join(dir, "slice.mp4")

          yt_dlp_cmd = [
            "yt-dlp",
            "--download-sections", "*#{start_sec}-#{end_sec}",
            "-o", tmp_video,
            source.source_uri
          ]
          
          puts "  --> Running yt-dlp: #{yt_dlp_cmd.join(' ')}"
          system(*yt_dlp_cmd) or raise "yt-dlp failed"

          if kind == "clip"
            out_file = File.join(out_dir, "clip_#{start_sec}_#{end_sec}.mp4")
            ffmpeg_cmd = ["ffmpeg", "-y", "-i", tmp_video, "-c", "copy", out_file]
            puts "  --> Running ffmpeg: #{ffmpeg_cmd.join(' ')}"
            system(*ffmpeg_cmd) or raise "ffmpeg clip failed"
          elsif kind == "screenshot"
            out_file = File.join(out_dir, "screenshot_#{start_sec}_#{end_sec}.jpg")
            mid = (end_sec.to_f - start_sec.to_f) / 2.0
            ffmpeg_cmd = ["ffmpeg", "-y", "-ss", mid.to_s, "-i", tmp_video, "-vframes", "1", "-q:v", "2", out_file]
            puts "  --> Running ffmpeg: #{ffmpeg_cmd.join(' ')}"
            system(*ffmpeg_cmd) or raise "ffmpeg screenshot failed"
          end
        end

        true
      end
    end
  end
end
