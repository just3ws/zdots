# frozen_string_literal: true

require "dry/monads"
require_relative "base"
require_relative "../ai/pipeline"

module Zdots
  module Jobs
    class Embed < Base
      include Dry::Monads[:result]

      Jobs.register "embed", self

      # The embedding model (Nomic v2) has a 512-token context. Content longer
      # than that is split into character-budgeted chunks, each embedded, then
      # mean-pooled into one normalized vector — so long lessons/methodologies
      # are represented in full rather than failing or being truncated.
      # Budget is conservative: dense markdown/code measured ~3.1 chars/token,
      # so 1200 chars ≈ 390 tokens — comfortable margin under 512. Short content
      # yields a single chunk and behaves exactly as before.
      MAX_CHARS = 1200

      def run
        table = payload["table"]
        id    = payload["id"]
        text  = payload["text"]
        raise "Missing table, id, or text in payload" if [table, id, text].any?(&:nil?)

        puts "  --> Generating embedding for #{table}:#{id}..."

        vector = embed_document(text)
        # pgvector requires a vector literal — Sequel.pg_array produces numeric[]
        # which the <=> operator does not accept. Cast explicitly via string literal.
        vec_literal = "[#{vector.join(',')}]"
        Zdots.db[table.to_sym].where(id: id).update(
          embedding: Sequel.lit("?::vector", vec_literal)
        )

        true
      end

      private

      # Embed possibly-long text by chunking under the model context and
      # mean-pooling the per-chunk vectors into a single document vector.
      def embed_document(text)
        vectors = chunk(text).map do |part|
          result = Zdots::AI::Pipeline.embed(part)
          raise "Embed pipeline failed: #{result.failure}" unless result.success?

          result.value!
        end
        mean_pool(vectors)
      end

      # Split text into chunks of at most MAX_CHARS, preferring whitespace
      # boundaries. A single token longer than MAX_CHARS is hard-split.
      def chunk(text)
        return [text] if text.length <= MAX_CHARS

        chunks = []
        current = +""
        text.split(/(\s+)/).each do |token|
          next if token.empty?

          if token.length > MAX_CHARS
            chunks << current.strip unless current.strip.empty?
            current = +""
            token.scan(/.{1,#{MAX_CHARS}}/m).each { |piece| chunks << piece }
          elsif current.length + token.length > MAX_CHARS
            chunks << current.strip unless current.strip.empty?
            current = token
          else
            current << token
          end
        end
        chunks << current.strip unless current.strip.empty?
        chunks.reject(&:empty?)
      end

      # Component-wise mean of the chunk vectors, L2-normalized. A single chunk
      # passes through unchanged (no pooling).
      def mean_pool(vectors)
        return vectors.first if vectors.size == 1

        dim  = vectors.first.size
        sums = Array.new(dim, 0.0)
        vectors.each { |v| v.each_with_index { |x, i| sums[i] += x } }
        mean = sums.map { |s| s / vectors.size }
        norm = Math.sqrt(mean.sum { |x| x * x })
        norm.zero? ? mean : mean.map { |x| x / norm }
      end
    end
  end
end
