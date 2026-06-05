# frozen_string_literal: true

require "dry/monads"
require_relative "base"
require_relative "../ai/pipeline"

module Zdots
  module Jobs
    class DocsSync < Base
      include Dry::Monads[:result]

      Jobs.register "docs_sync", self

      # AGENTS.md is intentionally excluded: it is the canonical AI agent context
      # file and must only be updated by the operator, not by an async job.
      DOCS_TO_MAINTAIN = [
        "README.md",
        "docs/architecture.md",
        "GEMINI.md"
      ].freeze

      # Sentinel the model returns when a document needs no change.
      NO_CHANGES = "NO_CHANGES_REQUIRED"

      def run
        trace_id = payload["trace_id"]

        # Read through the model so summary/result are decrypted via
        # EncryptedContent — never raw bytea columns from the dataset.
        residue = Zdots::Models::SessionResidue.where(trace_id: trace_id).first
        raise "Residue not found for trace: #{trace_id}" unless residue

        puts "  --> Syncing documentation with residue from session: #{trace_id[0..7]}..."

        summary = residue.summary.to_s
        result  = residue.result.to_s

        DOCS_TO_MAINTAIN.each do |doc_rel_path|
          full_path = File.join(Zdots::ZDOTDIR, doc_rel_path)
          next unless File.exist?(full_path)

          puts "      - Processing #{doc_rel_path}..."
          updated = sync_document(doc_rel_path, File.read(full_path), summary, result)

          if updated.nil?
            puts "        (no changes needed)"
          else
            File.write(full_path, updated)
            puts "        (updated successfully)"
          end
        end

        residue.update(processed_into_docs_at: Sequel::CURRENT_TIMESTAMP)

        true
      end

      private

      # Ask the model whether a document needs updating given the session
      # residue. Returns the new content, or nil when no change is required.
      #
      # Inference goes through Pipeline (gate → PHI scrub → infer) — the single
      # seam to the model. A pipeline failure (e.g. a PHI-suppressed input or an
      # unreachable endpoint) raises, so the job is retried rather than silently
      # writing a doc from a half-failed call.
      def sync_document(doc_rel_path, current_content, summary, result)
        prompt = load_prompt("docs_sync",
                             doc_path: doc_rel_path,
                             summary: summary,
                             result: result,
                             current_content: current_content)

        case Zdots::AI::Pipeline.call(prompt, temperature: 0.1)
        in Success[response]
          text = response.strip
          text == NO_CHANGES ? nil : text
        in Failure[reason, msg]
          raise "AI pipeline failed (#{reason}): #{msg}"
        end
      end
    end
  end
end
