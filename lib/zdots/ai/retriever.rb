# frozen_string_literal: true

require "dry/monads"

module Zdots
  module AI
    class Retriever
      include Dry::Monads[:result]

      def search(query, limit: 15)
        vector_res = Pipeline.embed(query)
        return vector_res if vector_res.failure?

        vector = vector_res.value!
        vec_literal = "[#{vector.join(',')}]"

        # Semantic search against chunks
        chunks = Zdots.db[:knowledge_chunks]
          .join(:media_sources, id: :media_source_id)
          .select(
            Sequel[:knowledge_chunks][:content],
            Sequel[:knowledge_chunks][:start_sec],
            Sequel[:media_sources][:title],
            Sequel.lit("embedding <=> ?::vector AS distance", vec_literal)
          )
          .order(Sequel.lit("distance"))
          .limit(limit)
          .all

        Success(chunks)
      end

      # Formats the semantic chunks into a string suitable for an LLM prompt,
      # grouped by media source.
      def format_context(chunks)
        return "No relevant context found." if chunks.empty?

        grouped = chunks.group_by { |c| c[:title] }
        context_str = ""

        grouped.each do |title, source_chunks|
          context_str += "Source Video: #{title}\n"
          source_chunks.each do |c|
            ts = c[:start_sec] ? "[#{c[:start_sec]}s]" : "[unknown time]"
            context_str += "  - #{ts} #{c[:content]}\n"
          end
          context_str += "\n"
        end

        context_str
      end
    end
  end
end
