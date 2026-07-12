# frozen_string_literal: true

require "open3"
require "json"

module Zdots
  module AI
    class Publisher
      def initialize(source_id)
        @source_id = source_id
        @source_dir = File.join(ENV["HOME"], ".local/state/zdots/ingest-sources", @source_id)
      end

      # Burns subtitles into a video clip for a given segment.
      # Requires the original video file (e.g. .mp4 or .webm) and a VTT subtitle file.
      def extract_and_burn(start_sec, end_sec, out_path, title: "clip")
        video_file = find_video_file
        vtt_file = find_vtt_file

        unless video_file && vtt_file
          return [false, "Missing video or VTT file for source #{@source_id}"]
        end

        duration = end_sec - start_sec

        # FFmpeg command to extract and burn subtitles
        # We use a complex filter to burn the subtitles. 
        # Note: the subtitles filter requires the path to be escaped properly if it contains colons, etc.
        vtt_escaped = vtt_file.gsub("'", "\\'").gsub(":", "\\:")
        
        cmd = [
          "ffmpeg", "-y",
          "-ss", start_sec.to_s,
          "-i", video_file,
          "-t", duration.to_s,
          "-vf", "subtitles='#{vtt_escaped}':force_style='FontSize=24,PrimaryColour=&H00FFFF,BorderStyle=3,Outline=1,Shadow=1'",
          "-c:v", "libx264",
          "-preset", "fast",
          "-c:a", "aac",
          out_path
        ]

        stdout, stderr, status = Open3.capture3(*cmd)
        
        if status.success?
          [true, out_path]
        else
          [false, "FFmpeg failed: #{stderr}"]
        end
      end

      # Mock YouTube / social API push
      def push_to_social(video_path, title, description)
        # In a real implementation this would use the YouTube Data API v3
        puts "==> Mock pushing video to YouTube/Social"
        puts "    File: #{video_path}"
        puts "    Title: #{title}"
        puts "    Description: #{description}"
        [true, "https://youtube.com/watch?v=mock_id"]
      end

      private

      def find_video_file
        Dir.glob(File.join(@source_dir, "*/*.{mp4,webm,mkv}")).first
      end

      def find_vtt_file
        Dir.glob(File.join(@source_dir, "*/*.vtt")).first
      end
    end
  end
end
