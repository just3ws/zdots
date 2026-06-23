---
id: Z-173
title: >-
  [agent-issue] phi-history hook overhead exceeds threshold (~60ms; double
  binary spawn per command)
status: To Do
assignee: []
created_date: '2026-06-22 19:45'
updated_date: '2026-06-23 02:30'
labels:
  - performance
  - phi
dependencies: []
priority: medium
ordinal: 69890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The phi-history shell hook (conf.d/55-phi-history.zsh) warns 'phi-history: ~60ms overhead (threshold 20ms)' on commands. Observed live during a 'sentry-cli info' run this session.

ROOT CAUSE (hypothesis): zshaddhistory() fires on EVERY interactive command and spawns the zdots-phi-scrub Go binary up to TWICE per line — line 56 'zdots-phi-scrub --check' (suppress detection) and line 66 'zdots-phi-scrub' (redact pass). Each spawn is a cold-ish Go process start.

EVIDENCE (this machine, bin/zdots-phi-scrub):
  - single --check spawn: ~15-16ms warm, ~40ms first/cold
  - check + redact (clean-command path, both spawns): ~20ms+
  - matches the ~60ms warning under load / cold cache

IMPACT: adds latency to every command on a work (PHI) machine where the hook is mandatory (ZDOTS_HISTORY_REDACT=1). Threshold is 20ms (print) / 1ms (metric record), so it's firing routinely.

POSSIBLE DIRECTIONS (operator's call — not prescribing): single-pass binary that both checks-and-redacts in one invocation; or a long-lived scrub daemon/socket the hook talks to; or combine --check into the default scrub exit code so only one spawn is needed. Filed per AGENTS.md §5 — do not hand-patch the PHI boundary.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PARTIAL FIX committed 9b5bfe8c5 (this work-machine session, operating ON zdots → fix-forward authorized).

Eliminated the redundant double-spawn: the hook spawned zdots-phi-scrub twice/command (--check + redact). Default mode already detects suppress, so gave the binary a distinct suppress exit code (2; 1 = operational error) and collapsed the hook to ONE spawn. Stack-wide convention now: binary → message_hygiene → cmd-analytics → history hook all read exit 2 = suppress.

MEASURED: clean-command hot path 15.9ms → 7.2ms (~55%) on this machine.
TESTS: phi_boundary + fuzz green (93); new Go test asserts default-mode suppress=2; bats exit-code assertions updated to exit:2 / -ne 0.

REMAINING (the deeper cost): even one spawn pays ~7ms RE2 registry-compile per command because each invocation is a cold process. The SOTA fix is a resident scrub daemon/socket (compile once, serve) — an architectural change to the PHI boundary, operator-designed. Left open under this issue.
<!-- SECTION:NOTES:END -->
