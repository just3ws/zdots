---
id: Z-285
title: >-
  rtk rg handler corrupts match output — exempt rg from auto-rewrite until fixed
  (tooling #6)
status: Done
assignee: []
created_date: '2026-08-02 14:57'
updated_date: '2026-08-02 15:00'
labels:
  - agent-ready
dependencies: []
priority: medium
ordinal: 161895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
REPRO (twice, 2026-08-02 session): rg invocations auto-rewritten through rtk returned results with the matched string REPLACED by 'n' (e.g. searching lib/ for 'scrub_failure' printed lines reading "suppressed via n"; searching for 'def self.db' printed bare 'n'). Each occurrence silently corrupts evidence and cost a re-run via rtk proxy. rg is presumably rtk's most-used handler (rtk grep alone averages 25.7% savings — L4), so a correctness bug here is also the main adoption blocker for Z-275 (adoption 5.2%).

ACTIONS: (1) locate the CC auto-rewrite hook (not in tracked .claude/settings.json — likely user-level ~/.claude config) and exempt rg/grep until the handler is proven faithful; (2) fix or file upstream in the rtk repo: handler must never alter matched text — add a golden test: rtk rg output byte-identical to raw rg for a fixture tree; (3) re-enable the rewrite once the golden test passes. Verify with: rtk rg 'scrub_failure' conf.d/ vs rtk proxy rg — outputs must match.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLOSED — PREMISE WRONG, rtk exonerated (2026-08-02). Controlled repro: direct 'rtk rg -n scrub_failure <file>' is byte-faithful to raw rg. The two 'corruptions' both used a bundled -r flag (rg -rn, rg -rln): rg's -r is --replace and consumed the following letters as the replacement string ('n', 'ln') — outputs match that exactly. Operator/agent flag error (grep muscle memory; rg is recursive by default), not a handler bug. No exemption made, no golden test needed; [hooks].exclude_commands documented as the knob if a real handler bug ever appears.
<!-- SECTION:NOTES:END -->
