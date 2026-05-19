# frozen_string_literal: true

require_relative "base"
require "ruby_llm"

module Zdots
  module Jobs
    class Embed < Base
      def run
        table = payload["table"]
        id = payload["id"]
        text = payload["text"]

        if table.nil? || id.nil? || text.nil?
          raise "Missing table, id, or text in payload"
        end

        puts "  --> Generating embedding for #{table}:#{id} using RubyLLM..."

        config = RubyLLM::Configuration.new
        config.openai_api_key = "local"
        config.openai_api_base = ENV.fetch("ZDOTS_AI_ENDPOINT", "http://127.0.0.1:8080/v1")

        llm = RubyLLM::Providers::OpenAI.new(config)

        response = llm.embed(
          text,
          model: "local",
          dimensions: 3584
        )

        embedding = response.vectors
        
        if embedding.nil? || embedding.empty?
          raise "Failed to generate or parse embedding from AI server"
        end

        # Update the target table via Sequel
        Zdots.db[table.to_sym].where(id: id).update(embedding: Sequel.pg_array(embedding))
        
        true
      end
    end
  end
end
