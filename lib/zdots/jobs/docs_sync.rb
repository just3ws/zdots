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

        # Residue text can carry arbitrary bytes; under launchd the default
        # external encoding is US-ASCII, which made downstream string ops die
        # with "invalid byte sequence" (Z-225). Normalize at the boundary.
        summary = utf8(residue.summary.to_s)
        result  = utf8(residue.result.to_s)

        # Two-phase apply: generate everything first, write only if the whole
        # batch succeeded. A mid-list failure used to leave earlier docs
        # already rewritten, and the retry regenerated them again (Z-228).
        updates = {}
        DOCS_TO_MAINTAIN.each do |doc_rel_path|
          full_path = File.join(Zdots::ZDOTDIR, doc_rel_path)
          next unless File.exist?(full_path)

          puts "      - Processing #{doc_rel_path}..."
          current = utf8(File.read(full_path, encoding: "UTF-8"))
          updated = sync_document(doc_rel_path, current, summary, result)
          next puts "        (no changes needed)" if updated.nil?

          fictional = fictional_paths(current, updated)
          if fictional.any?
            # The model invented repo artifacts (Z-228: an SSH contract citing a
            # tests/ssh.bats that never existed). Never write fiction; skip.
            puts "        (REJECTED: references nonexistent #{fictional.join(', ')})"
            next
          end
          updates[full_path] = updated
        end

        updates.each do |full_path, content|
          File.write(full_path, content)
          puts "      - wrote #{full_path.delete_prefix("#{Zdots::ZDOTDIR}/")}"
        end

        residue.update(processed_into_docs_at: Sequel::CURRENT_TIMESTAMP)

        true
      end

      private

      def utf8(str)
        str.encode("UTF-8", invalid: :replace, undef: :replace)
      end

      # Repo-relative path-like tokens the model ADDED that do not exist on
      # disk — the cheapest reliable hallucination signal for generated docs.
      # (?<![/\w]) keeps absolute paths like /usr/bin/env from matching as "bin/env".
      PATHY = %r{(?<![/\w])(?:bin|lib|conf\.d|etc|docs|tests|sbin|man)/[A-Za-z0-9_./-]+}
      def fictional_paths(old_content, new_content)
        added = new_content.scan(PATHY) - old_content.scan(PATHY)
        added.uniq.reject do |rel|
          File.exist?(File.join(Zdots::ZDOTDIR, rel.chomp(".")))
        end
      end

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
        in Failure[:phi_suppressed, msg]
          # Deterministic: the same input suppresses on every retry (Z-242
          # burned 5 attempts this way). Skip this doc, keep the job alive.
          puts "        (skipped: input is PHI-suppressed — #{msg})"
          nil
        in Failure[reason, msg]
          raise "AI pipeline failed (#{reason}): #{msg}"
        end
      end
    end
  end
end
