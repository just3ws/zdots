# frozen_string_literal: true

require "spec_helper"
require "open3"
require "zdots/ai/phi_scrubber"

# Cross-implementation contract: the Ruby PhiScrubber and the bash
# lib/phi_scrubber.bash both compile etc/phi-patterns.yaml and MUST agree on the
# security-relevant behaviour for every registry pattern. This is the drift
# guard — it exists because the two enforcement implementations once disagreed
# on suppress semantics (Ruby redacted connection strings; bash failed hard).
#
# The contract pins two invariants, not byte-identical output:
#   1. suppress agreement — both classify each input as suppressed or not.
#   2. redaction safety   — for non-suppressed input both remove the secret.
RSpec.describe "PHI enforcement contract (Ruby ⇔ bash)" do
  ruby = Zdots::AI::PhiScrubber
  root = ZDOTS_ROOT.to_s

  before(:all) do
    skip "yq not installed — bash scrubber unavailable" unless system("command -v yq >/dev/null 2>&1")
  end

  # --- bash bridges -----------------------------------------------------------

  def bash_suppressed?(root, input)
    env = { "ZDOTDIR" => root, "PHI_IN" => input }
    _o, status = Open3.capture2(
      env, "bash", "-c",
      'source "$ZDOTDIR/lib/phi_scrubber.bash"; phi_should_suppress "$PHI_IN"',
      err: File::NULL
    )
    status.success? # phi_should_suppress exits 0 when the input is suppressed
  end

  def bash_scrub(root, input)
    env = { "ZDOTDIR" => root }
    out, status = Open3.capture2(
      env, "bash", "-c",
      'source "$ZDOTDIR/lib/phi_scrubber.bash"; phi_scrub',
      stdin_data: input, err: File::NULL
    )
    [out, status.exitstatus]
  end

  # --- Go (RE2) bridge --------------------------------------------------------
  # The OTel collector scrubs telemetry at ingest using Go's RE2 engine
  # (etc/otel-collector.generated.yaml, compiled from the same registry). RE2 is
  # a THIRD dialect alongside sed-ERE (bash) and Onigmo (ruby): a pattern can
  # work in those two yet fail to compile in RE2, which the collector would then
  # silently skip (error_mode: ignore). The zdots-phi tool shares the collector's
  # engine, so pinning it here makes that drift fail the test instead of leaking.
  GO_DIR = File.expand_path("../../../analysis-assets/zdots-phi-go", __dir__)
  GO_BIN = File.join(GO_DIR, "zdots-phi")

  def self.go_available?
    return true if File.executable?(GO_BIN)
    return false unless system("command -v go >/dev/null 2>&1")

    system("go", "build", "-o", "zdots-phi", ".", chdir: GO_DIR, out: File::NULL, err: File::NULL)
  end

  def go_suppressed?(root, input)
    _o, status = Open3.capture2({ "ZDOTDIR" => root }, GO_BIN, "suppressed?", stdin_data: input, err: File::NULL)
    status.success? # exits 0 when suppressed
  end

  def go_scrub(root, input)
    out, status = Open3.capture2({ "ZDOTDIR" => root }, GO_BIN, "scrub", stdin_data: input, err: File::NULL)
    [out, status.exitstatus]
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
        expect(bash_suppressed?(root, c[:input])).to be(c[:suppress])
      end

      if c[:suppress]
        it "both refuse to process (Ruby raises, bash exits non-zero)" do
          expect { ruby.call(c[:input]) }.to raise_error(Zdots::AI::PhiScrubber::SuppressedError)
          _out, code = bash_scrub(root, c[:input])
          expect(code).not_to eq(0)
        end
      else
        it "both redact without leaking the secret" do
          ruby_out = ruby.call(c[:input])
          bash_out, code = bash_scrub(root, c[:input])
          expect(code).to eq(0)
          if c[:secret]
            expect(ruby_out).not_to include(c[:secret])
            expect(bash_out).not_to include(c[:secret])
          else
            # clean input passes through unchanged in both implementations
            expect(ruby_out).to eq(c[:input])
            expect(bash_out).to eq(c[:input])
          end
        end
      end
    end
  end

  # --- Go/RE2 engine parity (the collector's dialect) -------------------------
  describe "+ Go RE2 engine (zdots-phi)" do
    before(:all) do
      skip "go toolchain and prebuilt zdots-phi both unavailable" unless self.class.go_available?
    end

    it "every registry pattern compiles in RE2 (zdots-phi check)" do
      # Fails loud on a pattern the collector would silently ignore.
      _o, status = Open3.capture2({ "ZDOTDIR" => root }, GO_BIN, "check", err: File::NULL)
      expect(status.success?).to be(true)
    end

    CASES.each do |c|
      context "for #{c[:input].inspect}" do
        it "agrees with Ruby on suppression (expected: #{c[:suppress]})" do
          expect(go_suppressed?(root, c[:input])).to be(c[:suppress])
        end

        if c[:suppress]
          it "refuses to process (exits non-zero)" do
            _out, code = go_scrub(root, c[:input])
            expect(code).not_to eq(0)
          end
        else
          it "redacts without leaking the secret" do
            out, code = go_scrub(root, c[:input])
            expect(code).to eq(0)
            if c[:secret]
              expect(out).not_to include(c[:secret])
            else
              expect(out).to eq(c[:input]) # clean input passes through unchanged
            end
          end
        end
      end
    end
  end
end
