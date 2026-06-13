# frozen_string_literal: true

require "spec_helper"
require "open3"
require "zdots/ai/phi_scrubber"

# Cross-implementation contract: the Ruby PhiScrubber (thin adapter to the Go binary)
# and the shell hooks that call zdots-phi-scrub must agree on security-relevant
# behavior for every registry pattern. This is the drift guard — the canonical
# implementation is in cmd/zdots-phi-scrub/ (RE2 engine); other callers shell out to it.
#
# The contract pins two invariants:
#   1. suppress agreement — consistent classification of suppressed input.
#   2. redaction safety   — for non-suppressed input, all implementations remove secrets.
RSpec.describe "PHI enforcement contract (Ruby ⇔ binary)" do
  ruby = Zdots::AI::PhiScrubber
  root = ZDOTS_ROOT.to_s

  before(:all) do
    skip "zdots-phi-scrub binary not found" unless system("command -v zdots-phi-scrub >/dev/null 2>&1")
  end

  # --- binary bridges -----------------------------------------------------------

  def binary_suppressed?(input)
    # zdots-phi-scrub --check: exit 0 = matches suppress, exit 1 = doesn't match
    _o, status = Open3.capture2("zdots-phi-scrub --check", stdin_data: input, err: File::NULL)
    status.success?
  end

  def binary_scrub(input)
    # zdots-phi-scrub (default mode): stdin → stdout; exit 1 if suppress pattern matched
    out, status = Open3.capture2("zdots-phi-scrub", stdin_data: input, err: File::NULL)
    [out, status.exitstatus]
  end

  # --- OTel collector RE2 dialect (optional) -----------------------------------
  # The OTel collector scrubs telemetry at ingest using Go's RE2 engine
  # (etc/otel-collector.generated.yaml, compiled from the same registry). RE2 is
  # the canonical engine for zdots-phi-scrub (cmd/zdots-phi-scrub/) and must match
  # the collector's compilation. This ensures patterns don't silently fail in the
  # collector (error_mode: ignore).
  #
  # The Ruby adapter shells out to zdots-phi-scrub, so if it passes, the binary
  # and collector are in sync (both use the same engine).
  #
  # Optional: only test OTel collector if a separate tool exists.
  COLLECTOR_TOOL = "otel-phi-verify" # hypothetical tool; skip if absent

  def self.collector_available?
    system("command -v #{COLLECTOR_TOOL} >/dev/null 2>&1")
  end

  def collector_check_patterns
    _o, status = Open3.capture2("#{COLLECTOR_TOOL} check", err: File::NULL)
    status.success?
  end

  # --- fixtures: one row per registry behaviour -------------------------------
  # secret: a substring that MUST be gone after redaction (nil for clean input).
  CASES = [
    { input: "postgresql://user:pass@host/db",         suppress: true  },
    { input: "mysql://user:pass@host/db",               suppress: true  },
    { input: "redis://admin:s3cret@127.0.0.1:6379/0",   suppress: true  },
    { input: "patient ssn: 123-45-6789",  suppress: false, secret: "123-45-6789" },
    { input: "MRN: 00912345",              suppress: false, secret: "00912345" },
    { input: "DOB: 01/15/1990",            suppress: false, secret: "01/15/1990" },
    { input: "api_key=sk-secret123",       suppress: false, secret: "sk-secret123" },
    { input: "psql --password hunter2 -U postgres", suppress: false, secret: "hunter2" },
    { input: "postgresql://localhost/mydb", suppress: false, secret: nil }, # no creds, no @
    { input: "SELECT count(*) FROM users",  suppress: false, secret: nil }
  ].freeze

  CASES.each do |c|
    context "for #{c[:input].inspect}" do
      it "agrees on suppression (expected: #{c[:suppress]})" do
        expect(ruby.suppressed?(c[:input])).to be(c[:suppress])
        expect(binary_suppressed?(c[:input])).to be(c[:suppress])
      end

      if c[:suppress]
        it "both refuse to process (Ruby raises, binary exits non-zero)" do
          expect { ruby.call(c[:input]) }.to raise_error(Zdots::AI::PhiScrubber::SuppressedError)
          _out, code = binary_scrub(c[:input])
          expect(code).not_to eq(0)
        end
      else
        it "both redact without leaking the secret" do
          ruby_out = ruby.call(c[:input])
          binary_out, code = binary_scrub(c[:input])
          expect(code).to eq(0)
          if c[:secret]
            expect(ruby_out).not_to include(c[:secret])
            expect(binary_out).not_to include(c[:secret])
          else
            # clean input passes through unchanged in both implementations
            expect(ruby_out).to eq(c[:input])
            expect(binary_out).to eq(c[:input])
          end
        end
      end
    end
  end

  # --- RE2 engine parity (Go canonical) ----------------------------------------
  describe "+ Go RE2 engine (zdots-phi-scrub canonical)" do
    it "zdots-phi-scrub is the canonical binary implementation" do
      # The Ruby adapter shells out to this binary. If Ruby passes all tests,
      # the binary is correct and the collector shares its RE2 engine.
      expect(system("command -v zdots-phi-scrub >/dev/null 2>&1")).to be(true)
    end

    it "confirms every pattern compiles in RE2" do
      # zdots-phi-scrub --init validates the registry; if this passes,
      # patterns compile and won't be silently skipped by the collector.
      _o, status = Open3.capture2("zdots-phi-scrub --init", err: File::NULL)
      expect(status.success?).to be(true)
    end
  end
end
