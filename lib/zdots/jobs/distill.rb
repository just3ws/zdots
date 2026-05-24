# frozen_string_literal: true

require_relative "base"

module Zdots
  module Jobs
    class Distill < Base
      Jobs.register "distill", self

      def run
        url = payload["url"]
        raise "Missing URL in payload" if url.nil? || url.empty?

        vid = extract_video_id(url)
        transcript_path = File.join(ENV["HOME"], "Downloads", "transcripts", vid, "#{vid}.txt")

        unless File.exist?(transcript_path)
          raise "Transcript file not found: #{transcript_path}"
        end

        content = File.read(transcript_path)
        puts "  --> Distilling transcript for #{vid} using RubyLLM..."

        llm = Zdots::AI.client
        prompt = load_prompt("distill", url: url, content: content)

        response = llm.chat(
          model: "local",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.2
        )

        summary = response.content
        
        if summary.include?("No technical lessons identified")
          puts "  --> Skipping: no technical lessons identified."
        else
          puts "  --> Saving distilled lesson..."
          # We use the model directly to save the lesson
          Zdots::Models::Lesson.create(
            content: summary,
            context: "YouTube: #{url}",
            tags: ["video-distillation"],
            source_trace_id: job.trace_id
          )
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
