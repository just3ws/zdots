# frozen_string_literal: true

require "shellwords"
require "open3"

module Zdots
  module AI
    # Thin adapter that shells out to the canonical zdots-phi-scrub Go binary.
    #
    # The binary (cmd/zdots-phi-scrub/) provides the single source of truth for
    # PHI/credential pattern matching (RE2 engine, single registry). This module
    # maintains the public interface but delegates all scrubbing logic.
    #
    # Patterns are loaded from etc/phi-patterns.yaml — the single registry for
    # the entire zdots stack. To add a pattern, edit the registry; never here.
    #
    # Mirrors lib/phi_scrubber.bash contract:
    #   - call(text) → redacted text, or raise SuppressedError if text matches suppress pattern
    #   - suppressed?(text) → true if text matches a suppress-flagged pattern
    module PhiScrubber
      # Raised when input matches a suppress-flagged pattern (e.g. a connection
      # string with credentials). The bash twin returns non-zero with no stdout;
      # here we raise so callers fail the operation instead of silently redacting.
      # Pipeline maps this to Failure[:phi_suppressed].
      class SuppressedError < StandardError; end

      # True if text matches any suppress-flagged pattern (fast check).
      # Mirrors lib/phi_scrubber.bash::phi_should_suppress predicate.
      # Shells out to `zdots-phi-scrub --check` — exit 0 if matched, 1 if not.
      def self.suppressed?(text)
        str = text.to_s
        _check_suppress(str)
      end

      # Redact PHI/credentials from text. Raises SuppressedError if the input
      # matches a suppress-flagged pattern — suppressed input is never returned
      # partially redacted. nil/empty are treated as empty string.
      # Shells out to `zdots-phi-scrub` (default redact mode).
      def self.call(text)
        str = text.to_s
        raise SuppressedError, "input matches a suppress-flagged pattern" if _check_suppress(str)

        _scrub(str)
      end

      private

      # _check_suppress — invoke zdots-phi-scrub --check on input.
      # Returns true if input matches a suppress pattern, false otherwise.
      # Exit code: 0 → match (return true); 1 → no match (return false).
      def self._check_suppress(text)
        output, status = Open3.capture2("zdots-phi-scrub --check", stdin_data: text)
        status.success? # exit 0 = success = match = true
      rescue StandardError => e
        raise SuppressedError, "failed to check suppress pattern: #{e.message}"
      end

      # _scrub — invoke zdots-phi-scrub (default redact mode) on input.
      # Returns redacted text, or raises SuppressedError if process exits non-zero
      # (which indicates a suppress-flagged pattern was matched).
      def self._scrub(text)
        output, status = Open3.capture2("zdots-phi-scrub", stdin_data: text)
        unless status.success?
          raise SuppressedError, "input matches a suppress-flagged pattern"
        end
        output
      rescue StandardError => e
        raise SuppressedError, "failed to scrub: #{e.message}"
      end
    end
  end
end
