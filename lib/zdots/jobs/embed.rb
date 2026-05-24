# frozen_string_literal: true

require_relative "base"

module Zdots
  module Jobs
    class Embed < Base
      Jobs.register "embed", self

      def run
        table = payload["table"]
        id = payload["id"]
        text = payload["text"]

        if table.nil? || id.nil? || text.nil?
          raise "Missing table, id, or text in payload"
        end

        puts "  --> Generating embedding for #{table}:#{id} using RubyLLM..."

        llm = Zdots::AI.client

        embedding = llm.embed(model: "local", input: text).embedding
        
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
