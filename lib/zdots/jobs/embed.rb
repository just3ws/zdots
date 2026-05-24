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

        case Zdots::AI::Pipeline.embed(text)
        in Success[vector]
          Zdots.db[table.to_sym].where(id: id).update(embedding: Sequel.pg_array(vector))
        in Failure[reason, msg]
          raise "Embed pipeline failed (#{reason}): #{msg}"
        end

        true
      end
    end
  end
end
