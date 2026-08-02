---
id: Z-255
title: 'Observe → act: wire Alert actions (not just display)'
status: To Do
assignee: []
created_date: '2026-07-24 12:51'
updated_date: '2026-08-01 09:55'
labels:
  - platform-dynamism
  - observability
  - agent-ready
dependencies: []
priority: medium
ordinal: 131895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
otel/o2/statusline observe deeply but mostly DISPLAY. The Alert vocabulary (CONTEXT.md: 'condition-based, with actions and thresholds') implies actions — verify whether any are wired, then wire the high-value ones:
- Platform Service down → attempt bounded auto-restart (zsvc) + notify.
- Recurring error signature in o2 → auto-file a zdots-issue with the trace attached (dedup so it files once).
- PHI/policy gap detected → surface into the Virtuous Loop / dashboard.

Bounded and idempotent: an action fires once per condition-window, logs to the phi-boundary audit trail, and never masks a hard STOP gate.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 At least one Alert condition triggers a real action (auto-restart or auto-issue), not just a display
- [ ] #2 Actions are bounded (once per window) and idempotent; recurring-error auto-issue dedups
- [ ] #3 Every fired action emits to the com.zdots phi-boundary audit trail
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-01 audit: greenfield — no Alert model/table/routes anywhere in context-engine (only flash-message :alert). my DB has no alerts/pipeline_events tables (only pipeline_runs, policy_resolution_events). Scope must first decide where Alert definitions live (zdots side vs new context-engine table); if context-engine hosts, schema goes through ~/.config/zsh/db/migrations/ (owner zdots-brain), NOT a Rails migration.
<!-- SECTION:NOTES:END -->
