# frozen_string_literal: true

require_relative "base"
require "ruby_llm"

module Zdots
  module Jobs
    class Distill < Base
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

        # Configure RubyLLM for local llama.cpp
        # Assuming OpenAI-compatible local server on port 8080
        llm = RubyLLM::Provider::OpenAI.new(
          api_key: "local",
          base_url: ENV.fetch("ZDOTS_AI_ENDPOINT", "http://127.0.0.1:8080/v1")
        )

        prompt = <<~PROMPT
          You are the Knowledge Distiller for the Sentient Workbench.
          The following is a transcript from a YouTube video. 
          Extract 1-2 core technical lessons or architectural methodologies described in this text.

          VIDEO_URL: #{url}

          TRANSCRIPT:
          #{content}

          INSTRUCTIONS:
          1. Be extremely concise.
          2. Output a single paragraph summarizing the key engineering insight.
          3. If the video is purely entertainment, output "No technical lessons identified."
        PROMPT

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
