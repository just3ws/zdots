# frozen_string_literal: true

require 'yaml'

module Zdots
  module AI
    # Redacts known PHI and credential patterns from text.
    # Patterns are loaded from etc/phi-patterns.yaml — the single registry for
    # both this module and lib/phi_scrubber.bash. Add patterns there; never here.
    module PhiScrubber
      PATTERNS = YAML
        .load_file(File.expand_path('../../../etc/phi-patterns.yaml', __dir__))
        .fetch('patterns')
        .map { |p| [Regexp.new(p.fetch('regex')), p.fetch('replace')] }
        .freeze

      def self.call(text)
        PATTERNS.reduce(text.to_s) { |t, (pat, rep)| t.gsub(pat, rep) }
      end
    end
  end
end
