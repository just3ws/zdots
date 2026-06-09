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
      # mean-pooled into one normalized vector, so long lessons/methodologies
      # are represented in full rather than failing or being truncated.
      #
      # MAX_CHARS is a *performance hint*, not a correctness boundary. The
      # chars/token ratio is content-dependent: prose runs ~3.1 chars/token
      # (1200 chars ~= 390 tokens) but dense markdown tables / numeric forensics
      # run ~2.3 (1200 chars ~= 515 tokens, over the 512 limit). Rather than
      # chase a magic number that the next denser document breaks, the embed
      # path is self-healing: a chunk the server rejects for exceeding context
      # is split and re-embedded (see #embed_chunk). So no document can silently
      # drop out of the index, regardless of how it tokenizes.
      MAX_CHARS = 1200

      # A chunk this short can never exceed a 512-token context, so an overflow
      # at this size signals a different problem; stop recursing and surface it.
      MIN_SPLIT_CHARS = 64

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
        mean_pool(chunk(text).flat_map { |part| embed_chunk(part) })
      end

      # Embed one chunk, returning its vector(s). Self-healing on context
      # overflow: if the server rejects the chunk for exceeding its context
      # window (dense content tokenizing past MAX_CHARS' assumed budget), split
      # it and embed each half, so the document is still represented in full.
      # Any other failure (PHI-suppressed, locality, server down) is fatal and
      # re-raised, preserving the job's retry/dead-letter policy.
      def embed_chunk(part)
        result = Zdots::AI::Pipeline.embed(part)
        return [result.value!] if result.success?

        unless context_overflow?(result.failure) && part.length > MIN_SPLIT_CHARS
          raise "Embed pipeline failed: #{result.failure}"
        end

        mid = split_point(part)
        embed_chunk(part[0...mid]) + embed_chunk(part[mid..])
      end

      # True when a Pipeline failure is the embed server refusing an over-long
      # input; the one failure mode that splitting can recover from.
      def context_overflow?(failure)
        reason, message = failure
        reason == :embed_error &&
          message.to_s.match?(/exceed_context_size_error|larger than the max context size/i)
      end

      # Midpoint split, nudged to the next whitespace boundary so words aren't
      # cut, falling back to the hard midpoint when none is near.
      def split_point(part)
        mid = part.length / 2
        ws  = part.index(/\s/, mid)
        ws && ws < part.length - 1 ? ws + 1 : mid
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
