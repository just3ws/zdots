# frozen_string_literal: true

require "dry/monads"
require_relative "base"
require_relative "../ai/pipeline"

module Zdots
  module Jobs
    class Distill < Base
      include Dry::Monads[:result]

      Jobs.register "distill", self

      def run
        url = payload["url"]
        raise "Missing URL in payload" if url.nil? || url.empty?

        vid = extract_video_id(url)
        transcript_path = File.join(ENV["HOME"], "Downloads", "transcripts", vid, "#{vid}.txt")
        raise "Transcript file not found: #{transcript_path}" unless File.exist?(transcript_path)

        prompt = load_prompt("distill", url: url, content: File.read(transcript_path))
        puts "  --> Distilling transcript for #{vid}..."

        case Zdots::AI::Pipeline.call(prompt, temperature: 0.2)
        in Success[summary]
          if summary.include?("No technical lessons identified")
            puts "  --> Skipping: no technical lessons identified."
          else
            puts "  --> Saving distilled lesson..."
            Zdots::Models::Lesson.create(
              content: summary,
              context: "YouTube: #{url}",
              tags: ["video-distillation"],
              source_trace_id: job.trace_id
            )
          end
        in Failure[reason, msg]
          raise "AI pipeline failed (#{reason}): #{msg}"
        end

        true
      end

      private

      def extract_video_id(url)
        if url =~ /v=([^&]*)/
          $1
        elsif url =~ /\/([^\?\/]*)$/
          $1
        else
          "unknown_#{Time.now.to_i}"
        end
      end
    end
  end
end
