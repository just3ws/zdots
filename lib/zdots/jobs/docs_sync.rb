# frozen_string_literal: true

require_relative "base"

module Zdots
  module Jobs
    class DocsSync < Base
      Jobs.register "docs_sync", self

      DOCS_TO_MAINTAIN = [
        "README.md",
        "docs/architecture.md",
        "AGENTS.md",
        "GEMINI.md"
      ].freeze

      def run
        trace_id = payload["trace_id"]

        residue = Zdots.db[:session_residue].where(trace_id: trace_id).first
        raise "Residue not found for trace: #{trace_id}" unless residue

        puts "  --> Syncing documentation with residue from session: #{trace_id[0..7]}..."

        llm = Zdots::AI.client

        DOCS_TO_MAINTAIN.each do |doc_rel_path|
          full_path = File.join(Zdots::ZDOTDIR, doc_rel_path)
          next unless File.exist?(full_path)

          puts "      - Processing #{doc_rel_path}..."
          current_content = File.read(full_path)

          prompt = load_prompt("docs_sync",
            doc_path: doc_rel_path,
            summary: residue[:summary].to_s,
            result: residue[:result].to_s,
            current_content: current_content
          )

          response = llm.chat(
            model: "local",
            messages: [{ role: "user", content: prompt }],
            temperature: 0.1
          )

          new_content = response.content.strip
          
          if new_content == "NO_CHANGES_REQUIRED"
            puts "        (no changes needed)"
          else
            # Save the updated document
            File.write(full_path, new_content)
            puts "        (updated successfully)"
          end
        end

        # 3. Mark as processed
        Zdots.db[:session_residue].where(trace_id: trace_id).update(processed_into_docs_at: Sequel::CURRENT_TIMESTAMP)
        
        true
      end
    end
  end
end
