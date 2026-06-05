# frozen_string_literal: true

require "yaml"

module Zdots
  module AI
    # Redacts known PHI and credential patterns from text, and refuses
    # (fail-hard) on suppress-flagged patterns — matching lib/phi_scrubber.bash.
    #
    # Patterns are loaded from etc/phi-patterns.yaml — the single registry for
    # both this module and lib/phi_scrubber.bash. Add patterns there; never here.
    # The two implementations are pinned together by the cross-implementation
    # contract test (spec/zdots/ai/phi_contract_spec.rb) so they cannot drift.
    module PhiScrubber
      # Raised when input matches a suppress-flagged pattern (e.g. a connection
      # string with credentials). The bash twin (phi_scrub) returns non-zero
      # with no stdout; here we raise so callers fail the operation instead of
      # silently redacting and continuing. Pipeline maps this to
      # Failure[:phi_suppressed].
      class SuppressedError < StandardError; end

      _registry = YAML
                  .load_file(File.expand_path("../../../etc/phi-patterns.yaml", __dir__))
                  .fetch("patterns")

      # Redaction patterns: [Regexp, replacement]. Excludes suppress patterns —
      # their `replace` value is unused (the registry documents this).
      REDACT = _registry
               .reject { |p| p["suppress"] }
               .map { |p| [Regexp.new(p.fetch("regex")), p.fetch("replace")] }
               .freeze

      # Suppress patterns: matching input is refused, not redacted.
      SUPPRESS = _registry
                 .select { |p| p["suppress"] }
                 .map { |p| Regexp.new(p.fetch("regex")) }
                 .freeze

      # True if text matches any suppress-flagged pattern. Mirrors the bash
      # phi_should_suppress predicate; the no-fork pre-flight check.
      def self.suppressed?(text)
        str = text.to_s
        SUPPRESS.any? { |re| re.match?(str) }
      end

      # Redact PHI/credentials from text. Raises SuppressedError if the input
      # matches a suppress-flagged pattern — suppressed input is never returned
      # partially redacted. nil/empty are treated as empty string.
      def self.call(text)
        str = text.to_s
        raise SuppressedError, "input matches a suppress-flagged pattern" if suppressed?(str)

        REDACT.reduce(str) { |t, (pat, rep)| t.gsub(pat, rep) }
      end
    end
  end
end
