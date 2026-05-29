# frozen_string_literal: true

require_relative "base"
require "open3"

module Zdots
  module Jobs
    class Transcription < Base
      Jobs.register "transcription", self

      def run
        url = payload["url"]
        raise "Missing URL in payload" if url.nil? || url.empty?

        recipe_path = File.join(Zdots::ZDOTDIR, "recipes", "yt-transcribe")

        # 1-hour timeout safety (3600 seconds)
        # We wrap it in a timeout command for extra OS-level safety
        timeout_bin = `which gtimeout`.strip
        timeout_bin = `which timeout`.strip if timeout_bin.empty?

        cmd = if timeout_bin.empty?
                "#{recipe_path} '#{url}' --profile standard --summarize"
              else
                "#{timeout_bin} 3600 #{recipe_path} '#{url}' --profile standard --summarize"
              end

        puts "  --> Executing: #{cmd}"

        # Streaming output to the terminal (so the user sees progress)
        Open3.popen2e(cmd) do |_stdin, stdout_err, wait_thr|
          stdout_err.each do |line|
            puts line
          end

          exit_status = wait_thr.value
          raise "yt-transcribe failed with exit code #{exit_status.exitstatus}" unless exit_status.success?
        end

        true
      end
    end
  end
end
