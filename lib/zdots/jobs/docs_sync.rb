# frozen_string_literal: true

require_relative "base"
require "ruby_llm"

module Zdots
  module Jobs
    class DocsSync < Base
      DOCS_TO_MAINTAIN = [
        "README.md",
        "docs/architecture.md",
        "AGENTS.md"
      ].freeze

      def run
        trace_id = payload["trace_id"]
        
        # 1. Fetch the residue to process
        residue = Zdots.db[:session_residue].where(trace_id: trace_id).first
        raise "Residue not found for trace: #{trace_id}" unless residue

        puts "  --> Syncing documentation with residue from session: #{trace_id[0..7]}..."

        # 2. Configure LLM
        llm = RubyLLM::Provider::OpenAI.new(
          api_key: "local",
          base_url: ENV.fetch("ZDOTS_AI_ENDPOINT", "http://127.0.0.1:8080/v1")
        )

        DOCS_TO_MAINTAIN.each do |doc_rel_path|
          full_path = File.join(Zdots::ZDOTDIR, doc_rel_path)
          next unless File.exist?(full_path)

          puts "      - Processing #{doc_rel_path}..."
          current_content = File.read(full_path)

          prompt = <<~PROMPT
            You are the Documentation Architect for the Sentient Workbench.
            Your task is to update the following document to reflect new technical capabilities or architectural changes identified in a recent session.

            DOCUMENT_PATH: #{doc_rel_path}
            RECENT_SESSION_SUMMARY: #{residue[:summary]}
            RECENT_SESSION_RESULT: #{residue[:result]}

            CURRENT_CONTENT:
            ---
            #{current_content}
            ---

            INSTRUCTIONS:
            1. Analyze if the session residue contains new information that SHOULD be in this document.
            2. If yes, update the document content.
            3. PAY SPECIAL ATTENTION TO MERMAID DIAGRAMS. If a new service flow or component is mentioned, update the Mermaid code.
            4. Maintain the existing tone, formatting, and W3C OTel standards.
            5. If no changes are needed, output "NO_CHANGES_REQUIRED".
            6. Otherwise, output the FULL updated document content. Do not include preambles or wrap in markdown blocks.
          PROMPT

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
