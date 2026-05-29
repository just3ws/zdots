# frozen_string_literal: true

require "dry/monads"
require_relative "phi_scrubber"

module Zdots
  module AI
    # Functional AI pipeline: gate → scrub → infer.
    # Returns Success(text) or Failure[:reason, message] — never raises.
    # Callers pattern-match on the result; adapters (jobs) decide how to handle failure.
    module Pipeline
      class << self
        include Dry::Monads[:result]

        # Inference pipeline.
        # Returns Success(response_text) or Failure[:reason, message].
        def call(prompt, model: "local", temperature: 0.1, system: nil)
          gate
            .bind { scrub(prompt) }
            .bind { |clean| infer(clean, model: model, temperature: temperature, system: system) }
        end

        # Embedding pipeline.
        # Returns Success(vector) or Failure[:reason, message].
        def embed(text, model: "local")
          gate
            .bind { scrub(text) }
            .bind { |clean| vectorize(clean, model: model) }
        end

        private

        def gate
          Zdots::AI.assert_local!
          Success(nil)
        rescue Zdots::AI::LocalityError => e
          Failure[:locality, e.message]
        end

        def scrub(text)
          Success(PhiScrubber.call(text))
        end

        def infer(prompt, model:, temperature:, system:)
          msgs = []
          msgs << { role: "system", content: system } if system
          msgs << { role: "user", content: prompt }
          response = Zdots::AI.client.chat(model: model, messages: msgs, temperature: temperature)
          Success(response.content)
        rescue StandardError => e
          Failure[:inference_error, e.message]
        end

        def vectorize(text, model:)
          result = Zdots::AI.embed_client.embed(model: "embed", input: text)
          vector = result.vectors
          return Failure[:embed_error, "empty embedding returned"] if vector.nil? || vector.empty?

          Success(vector)
        rescue StandardError => e
          Failure[:embed_error, e.message]
        end
      end
    end
  end
end
