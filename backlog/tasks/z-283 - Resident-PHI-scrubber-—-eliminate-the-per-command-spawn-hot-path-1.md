---
id: Z-283
title: 'Resident PHI scrubber — eliminate the per-command spawn (hot path #1)'
status: To Do
assignee: []
created_date: '2026-08-02 14:56'
labels:
  - agent-ready
dependencies: []
priority: high
ordinal: 159895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
MEASURED (shell_hook_metrics, 2.5 months): every interactive command pays a zdots-phi-scrub fork/exec — clean avg 28.9ms, min 6.98ms, redacted avg 46.3ms. The hook fires per zshaddhistory; at a few hundred commands/day this is the single largest recurring latency tax on the platform.

DESIGN (contract is stable and tiny — ideal closed surface): keep the Go binary, run it resident. Preferred shape: zsh coproc per shell (start lazily on first history add; speak length-prefixed or NUL-delimited request/response over the coproc pipes; preserve exit-semantics 0=clean/redacted, 2=suppress, 1=error as a status byte). Alternative: single launchd Unix-socket daemon shared by all shells (one registry in memory, but adds a daemon lifecycle + socket permission surface — coproc avoids both).

REQUIREMENTS: (a) fail-safe unchanged — coproc dead/unresponsive -> fall back to one-shot spawn, never write unredacted; (b) registry staleness — re-exec the coproc when phi-patterns.yaml (or work-ext fragments) mtime changes; (c) Z-266 retry+stderr-audit semantics preserved; (d) bench before/after with bin/bench + shell_hook_metrics deltas; (e) phi_boundary bats extended for coproc death + registry-change reload. Expected result: sub-ms per command, and the transient registry-read failure class (Z-266) structurally gone — one load per shell, not per command.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
