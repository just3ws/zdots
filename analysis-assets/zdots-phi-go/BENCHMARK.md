# zdots-phi (Go prototype) — benchmark & findings

_2026-06-07 · darwin/arm64 · go1.26.3 · hyperfine. Prototype in this dir; the
live pipeline (lib/phi_scrubber.bash, lib/zdots/ai/phi_scrubber.rb) is unchanged._

## What was built

`main.go` → a 3.3 MB static binary, **zero runtime deps**, loading the single
registry `etc/phi-patterns.yaml` and mirroring the `phi_scrub` contract:
`scrub` (stdin→stdout, fail-hard exit 1 on suppress), `suppressed?` (exit code),
`check` (compile all patterns in RE2, **fail loud** on a bad pattern).

**Correctness: byte-identical** to `lib/phi_scrubber.bash` across mixed
redaction, suppress-drop (both exit 1, no stdout), and clean passthrough. 0 raw
secrets leaked from the 1.37 MB blob.

## Numbers

### A — cold per-call, small input (83 B): process-boundary cost
| impl | mean | vs Go |
|---|---|---|
| **go** | **2.5 ms** | 1× |
| bash (source+yq load+sed forks) | 13.8 ms | 5.5× slower |
| ruby (interp start) | 34.2 ms | 13.6× slower |

Go wins decisively — startup dominates and the Go binary starts fastest.

### B — hot, 2000× small: the history-hook reality
| path | per-op |
|---|---|
| bash `phi_should_suppress` preflight (`[[ =~ ]]`, **no fork**) | **0.017 ms** |
| go binary spawn (`scrub`) | 2.35 ms |
| bash `phi_scrub` (preloaded, sed forks) | 3.87 ms |

The hook's **common clean-path is the in-shell preflight at 0.017 ms** — ~140×
faster than *any* binary spawn. Go beats bash only when redaction actually fires
(2.35 vs 3.87 ms, 1.6×), which is the rare path.

### C — large input throughput (1.37 MB): engine cost dominates
| impl | mean | note |
|---|---|---|
| **ruby (Onigmo)** | **73 ms** | fastest engine |
| go (RE2) | 159 ms | 2.2× slower than ruby |
| bash (5 sed passes) | 216 ms | slowest |

**Go RE2 is ~2.2× slower than Ruby's Onigmo here** — 5 sequential `ReplaceAll`
passes, each re-scanning the full buffer, and RE2's larger constant factor.

## Findings (the honest version)

1. **Go is not universally faster.** It wins where **process startup** dominates
   (cold small calls: 5.5×/13.6×), loses where **regex engine** dominates (large
   blobs vs Ruby). The premise "Go = more powerful/efficient" holds only for the
   startup-bound case.
2. **The history hook can't be improved by a binary.** Its hot path is already
   fork-free (`[[ =~ ]]` in-shell, 0.017 ms). A Go binary spawn (2.35 ms) is a
   ~140× regression there — only a persistent daemon+socket could win, which is
   over-engineering for a regex match (Schrute).
3. **RE2's real value is correctness, not speed:** linear-time (no catastrophic
   backtracking on adversarial input) and — crucially — **the same engine the
   OTel collector already uses**. A Go scrubber collapses the 3-engine drift risk
   (sed-ERE / Onigmo / RE2) flagged in the stability review into one dialect.
4. **`zdots-phi check` closes the silent-drift gap.** It fails loud if any
   registry pattern won't compile in RE2 — the exact failure mode the collector's
   `error_mode: ignore` hides today.
5. **Big-input Go slowness is fixable** (not done here): combine the 5 redaction
   regexes into **one alternation pass** with `ReplaceAllFunc` dispatching by the
   matched group → single scan instead of five. Expected to close most of the gap
   to Ruby. The current prototype is deliberately literal (one pass per pattern)
   to match bash/ruby semantics exactly.

## Verdict

Adopt Go for the scrubber **as a shared cross-process + collector-parity tool**,
not as a drop-in for the in-shell hook:

- **Use it for:** CLI/script scrubbing on small inputs (ai-query prompts, etc.) —
  5.5×/13.6× faster; and as the **RE2 parity oracle** in the contract test/CI
  (`zdots-phi check` + a fixture corpus) — the genuine stability win.
- **Keep in-shell:** `phi_should_suppress` preflight (free; a binary can't beat it).
- **Keep in Ruby in-process:** the context-engine/Rails path (fork-per-call would
  regress the request path; Onigmo is also faster on large bodies).
- **If large-blob scrubbing matters:** implement the single-pass alternation
  optimization before relying on Go there.

Net: Go is worth it for **engine-unification + fail-loud correctness + fast cold
small-input scrubbing**, *not* as a blanket "rewrite for speed." The composable
contract (stdin/stdout/exit) is preserved either way.
