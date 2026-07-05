# frozen_string_literal: true

require "dry/monads"
require_relative "base"
require_relative "../ai/pipeline"

module Zdots
  module Jobs
    # Z-199: generic tenant-consumable AI transform. Caller enqueues
    # {"text" => ..., "profile" => name}, fetches the structured result via
    # `zdots-ctx result <job_id>`. Profile selects the prompt (and thus the
    # output shape) from etc/prompts/jobs/transform/<profile>.txt — tenant-unique
    # logic (branding, speaker labels, etc.) does not belong in a profile here;
    # it stays in the tenant repo, which post-processes the raw output.
    class Transform < Base
      include Dry::Monads[:result]

      Jobs.register "transform", self

      def run
        text = payload["text"]
        profile = payload["profile"]
        raise "Missing text in payload" if text.nil? || text.empty?
        raise "Missing profile in payload" if profile.nil? || profile.empty?

        prompt = load_prompt(File.join("transform", profile), content: text)

        case Zdots::AI::Pipeline.call(prompt, temperature: 0.2)
        in Success[output]
          { "profile" => profile, "output" => output }
        in Failure[reason, msg]
          raise "AI pipeline failed (#{reason}): #{msg}"
        end
      end
    end
  end
end
