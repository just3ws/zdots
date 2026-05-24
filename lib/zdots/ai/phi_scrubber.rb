# frozen_string_literal: true

module Zdots
  module AI
    # Ruby port of lib/message_hygiene.bash PHI scrub patterns.
    # Single responsibility: redact known PHI and secret patterns from text.
    module PhiScrubber
      PATTERNS = [
        [/(-p|--password|--api-key|--token|--secret|--auth|--authorization)\s+\S+/, '\1 [REDACTED]'],
        [/\d{3}-\d{2}-\d{4}/,                                                        '[REDACTED-SSN]'],
        [/MRN\s*:?\s*\d+/,                                                           '[REDACTED-MRN]'],
        [/(DOB|[Dd]ate\s+[Oo]f\s+[Bb]irth)\s*:?\s*\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/, '[REDACTED-DOB]'],
        [%r{(postgresql|mysql|redis)://[^@\s]+@\S*},                                 '[REDACTED-CONN]'],
      ].freeze

      def self.call(text)
        PATTERNS.reduce(text.to_s) { |t, (pat, rep)| t.gsub(pat, rep) }
      end
    end
  end
end
