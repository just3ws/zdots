---
id: Z-307
title: >-
  [agent-issue] tests/mermaid_diagrams.bats availability guard passes when mmdc
  cannot launch, reporting 7 false doc
status: Done
assignee: []
created_date: '2026-08-21 20:17'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 182895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `446f549869793a94583c5f920f60268f`

tests/mermaid_diagrams.bats availability guard passes when mmdc cannot launch, reporting 7 false doc failures

**Symptom:** nightly `zdots-check` reported rc=1 with 7 failures, all named as
document Mermaid parse failures (docs/architecture.md, docs/local-ai.md,
docs/repository-evolution.md, README.md, docs/lifecycle.md,
docs/platform-dependency-graph.md, plus the catch-all sweep). SwiftBar surfaced
this as a red pulse. Evidence log:
`~/.local/state/zsh/zdots-watch-runs/check-20260821T033529.74759.log` lines 490-508.

**Actual cause:** none of the diagrams were malformed. `mmdc` (mermaid-cli
11.16.0, Homebrew) could not launch at all:

    Error: Could not find chrome-headless-shell (ver. 150.0.7871.24)
      cache path: /Users/mike/.cache/puppeteer

The puppeteer browser cache was empty. Resolved on the host 2026-08-21 by
installing the exact pinned build with mermaid-cli's own vendored installer
(not `npx`, which would float the version):

    $L/node_modules/.bin/browsers install chrome-headless-shell@150.0.7871.24 --path ~/.cache/puppeteer

After install: `bats tests/mermaid_diagrams.bats` -> 8/8 ok.

**The defect:** test 1, `mmdc is available (skip entire suite if not)`, PASSED
throughout. The guard establishes only that the binary is on PATH; it never
establishes that the binary can render. So a broken toolchain is misreported as
seven independent documentation defects, pointing the operator at the docs
instead of at the missing chromium. The guard should exercise a trivial render
(a two-node graph to a temp file) and skip the suite when that fails, so a
toolchain break reports as a skip, not as doc rot.

**Second-order risk:** while chromium is missing, the suite has zero real
coverage of the diagrams — an actually-broken Mermaid diagram is
indistinguishable from this failure mode.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed 2026-08-22 in commit 3c9eb99d. Replaced the `command -v mmdc` guard in all
8 tests with `_require_mmdc`, which renders a two-node graph to a temp file and
skips with the remediation command when that fails.

Verified both legs: chromium present -> 8/8 ok; `~/.cache/puppeteer` moved aside ->
8 skips and zero failures, where the old guard produced 7 failures naming innocent
documents.
<!-- SECTION:NOTES:END -->
