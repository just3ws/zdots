# ADR-0002: PHI Scrubber as canonical Go binary

**Status:** Accepted  
**Date:** 2026-06-12

## Context

Protected Health Information (PHI) scrubbing is a security-critical operation required before any text enters inference (`ai-query`, `zdots-ask`) or persistence (`zdots-ctx` DB writes). The current implementation spans three languages:

- **Bash** (`lib/phi_scrubber.bash`) — 200+ lines, compiled regex, provides `phi_scrub` and `phi_should_suppress`
- **Ruby** (`lib/zdots/ai/phi_scrubber.rb`) — wraps the bash impl, raises `SuppressedError` on suppress-flagged patterns
- **Go** — implied by planned analytics buffer refactor (would need PHI scrubbing for buffered commands)

The dual bash/Ruby implementations create maintenance friction: both must remain in sync on security semantics (suppress-flagged patterns fail hard; redaction is identical). The only enforcement is a cross-implementation contract test (`spec/zdots/ai/phi_contract_spec.rb`). If a maintainer edits `etc/phi-patterns.yaml` and forgets to run tests, the implementations silently diverge.

Additionally, PHI scrubbing is called from:
- **Precmd hook** (`conf.d/56-cmd-analytics.zsh`) — every command, high frequency
- **History hook** (`conf.d/55-phi-history.zsh`) — every command, fast path
- **Python distiller** (planned) — session transcripts
- **AI boundary checks** — inline before inference

This frequency and breadth suggest the scrubber is a **Platform Service seam** — a place where behavior should be centralized, testable, and language-agnostic.

## Decision

Consolidate PHI scrubbing into a single canonical **Go binary** (`zdots-phi-scrub`) called via CLI by bash, Ruby, and future callers. All security logic lives in one place. Bash and Ruby become thin adapters that invoke the binary.

### CLI Interface

```bash
# Mode 1: Redact (stdin → redacted stdout)
echo "SSN 123-45-6789" | zdots-phi-scrub
# exit 0, outputs redacted text
# SSN [REDACTED:SSN]

# Suppress-flagged pattern: hard fail
echo "connection_string=user:pass@localhost" | zdots-phi-scrub
# exit 1, no output (fail hard)

# Mode 2: Suppress check (fast predicate)
zdots-phi-scrub --check "my_secret_key=value"
# exit 0 if input matches a suppress-flagged pattern
# exit 1 if not

# Optional: preload registry at startup (fail early on missing config)
zdots-phi-scrub --init
# exit 0 if registry loaded, exit 1 if missing
# no output unless error
```

### Registry Loading

The binary reads `etc/phi-patterns.yaml` on first use (lazy load). In production:
- On first invocation, parse YAML and compile regex patterns into memory
- Cache patterns for the lifetime of the binary (one shell session)
- Subsequent calls reuse the cache (no re-parsing)

Optional `--init` flag allows precmd hook (`conf.d/54-phi-init.zsh`) to preload and validate at shell startup. If `--init` is called and patterns are missing or invalid, exit 1 with stderr message. If not called, validation defers to first use.

### Observability (OTEL)

**Suppress-matches (audit-critical):** Emit OTEL span on any suppress-flagged pattern match. Spans include:
- Event name: `phi.suppress_match`
- Attributes: `pattern_name`, `match_type` (redaction or suppress)
- Status: `ERROR`

**Redactions (metrics-only):** Emit counter metrics (no per-call spans):
- `phi_scrub_redacts_total` — total redaction calls
- `phi_scrub_patterns_matched` — per-pattern counter (labels: `pattern_name`)
- `phi_scrub_suppress_matches_total` — total suppress-match count

This keeps the collector from being overwhelmed by high-cardinality precmd hook calls while preserving audit trail of suppressed inputs.

OTEL instrumentation is graceful: if collector is unreachable, spans/metrics are logged to stderr and execution continues. The binary never blocks on observability.

## Consequences

### Positives

- **Single source of truth:** security logic lives once, in compiled Go. No sync burden.
- **Faster execution:** Go regex is faster than bash sed, especially for repeated calls in precmd.
- **Better tests:** Go tests call the binary directly (no shell invocation), making tests clearer.
- **Language-agnostic:** Python, Go, Ruby future code all call the same binary via CLI.
- **Audit trail:** suppress-matches are observable events; normal redactions don't spam logs.

### Implementation Changes

**Bash adapters** (`lib/phi_scrubber.bash`):
```bash
phi_scrub() {
  zdots-phi-scrub
}

phi_should_suppress() {
  zdots-phi-scrub --check "$1"
}
```

Three functions become two thin wrappers (5 lines total).

**Ruby adapters** (`lib/zdots/ai/phi_scrubber.rb`):
```ruby
class PhiScrubber
  def self.call(text)
    output = `echo #{Shellwords.escape(text)} | zdots-phi-scrub`
    raise SuppressedError if $?.exitstatus != 0
    output.chomp
  end

  def self.suppressed?(line)
    system("zdots-phi-scrub --check #{Shellwords.escape(line)}")
    $?.exitstatus == 0
  end
end
```

Same public interface, shelled-out implementation.

**Delete:** Old Bash impl logic and Ruby impl logic — both replaced by binary calls.

### Test Changes

Contract test (`spec/zdots/ai/phi_contract_spec.rb`) moves from cross-impl testing to direct binary testing:

```go
// cmd/zdots-phi-scrub/scrubber_test.go
func TestRedactSSN(t *testing.T) {
  input := "SSN 123-45-6789"
  cmd := exec.Command("zdots-phi-scrub")
  cmd.Stdin = strings.NewReader(input)
  out, _ := cmd.Output()
  
  if strings.Contains(string(out), "123-45-6789") {
    t.Errorf("SSN not redacted")
  }
}

func TestSuppressHardFail(t *testing.T) {
  input := "connection_string=user:pass@localhost"
  cmd := exec.Command("zdots-phi-scrub")
  cmd.Stdin = strings.NewReader(input)
  err := cmd.Run()
  
  if err == nil {
    t.Fatal("suppress pattern should fail hard")
  }
}
```

No shell invocation. No dual-impl syncing.

## Implementation Plan

1. **Write Go binary** (`cmd/zdots-phi-scrub/main.go`):
   - `internal/phi/registry.go` — load and compile `etc/phi-patterns.yaml`
   - `internal/phi/scrubber.go` — redaction and suppress logic
   - `internal/otel/` — OTEL span/metric instrumentation
   - CLI flags: `--check`, `--init`

2. **Write tests** (`cmd/zdots-phi-scrub/*_test.go`):
   - Redaction correctness (all pattern types)
   - Suppress hard-fail
   - OTEL emission
   - Registry loading and caching
   - Error handling (missing config, invalid YAML)

3. **Update adapters**:
   - Thin `lib/phi_scrubber.bash` (sources are thin wrappers)
   - Thin `lib/zdots/ai/phi_scrubber.rb` (shells out to binary)
   - Delete old logic

4. **Update hooks**:
   - `conf.d/55-phi-history.zsh` — calls binary instead of sourced function
   - `conf.d/56-cmd-analytics.zsh` — calls binary instead of sourced function
   - `conf.d/54-phi-init.zsh` — optional call to `zdots-phi-scrub --init`

5. **Integration test**:
   - Bash script that redacts text via bash adapter
   - Same text via Ruby (via test harness)
   - Verify outputs are identical

6. **Verify stability**:
   - Shell sessions with live hooks
   - Check for regressions in history capture
   - Monitor OTEL spans/metrics in collector

## Revisit When

- **Multi-machine deployment** — if PHI scrubbing becomes a remote service (e.g., shared by multiple workstations), move the binary to `sbin/` and expose as a Core Service with endpoint rather than a CLI tool.
- **Scrubbing performance bottleneck** — if profiling shows regex compilation is a bottleneck, cache compiled patterns in mmap'd shared memory (binary pre-compiles, shares via shm).
- **New PHI pattern types** — adding patterns is one edit (`etc/phi-patterns.yaml`), no code changes.

## Related

- **Message Hygiene Pipeline** (CONTEXT.md) — owns the compose of normalize + PHI scrub
- **PHI Pattern Registry** (CONTEXT.md) — single source of patterns
- **Analytics Buffer unification** (future ADR) — will benefit from clear PHI scrubbing seam
