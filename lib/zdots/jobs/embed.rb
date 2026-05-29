# frozen_string_literal: true

require "dry/monads"
require_relative "base"
require_relative "../ai/pipeline"

module Zdots
  module Jobs
    class Embed < Base
      include Dry::Monads[:result]

      Jobs.register "embed", self

      def run
        table = payload["table"]
        id    = payload["id"]
        text  = payload["text"]
        raise "Missing table, id, or text in payload" if [table, id, text].any?(&:nil?)

        puts "  --> Generating embedding for #{table}:#{id}..."

        result = Zdots::AI::Pipeline.embed(text)
        if result.success?
          vector = result.value!
          # pgvector requires a vector literal — Sequel.pg_array produces numeric[]
          # which the <=> operator does not accept. Cast explicitly via string literal.
          vec_literal = "[#{vector.join(",")}]"
          Zdots.db[table.to_sym].where(id: id).update(
            embedding: Sequel.lit("?::vector", vec_literal)
          )
        else
          raise "Embed pipeline failed: #{result.failure}"
        end

        true
      end
    end
  end
end
