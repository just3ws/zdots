---
id: Z-147
title: >-
  [agent-issue] zdots-heal: Gate 6 orphan scanner regex too broad — matches
  prose words; needs command-prefix anchoring
status: To Do
assignee: []
created_date: '2026-06-12 18:06'
updated_date: '2026-06-14 21:30'
labels:
  - agent-reported
  - bug
  - wave4
dependencies: []
priority: medium
ordinal: 38890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `6bf14d21464f22110cd5256b140c4c30`

zdots-heal: Gate 6 orphan scanner regex too broad — matches prose words; needs command-prefix anchoring

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Gate 6 scanner anchors on command-prefix shapes (zsvc, colima-status, capabilities, agent-guide, cc-doctor, zdots-*); no longer matches prose words
- [ ] #2 Path/filename-embedded tokens are rejected
- [ ] #3 Skill-name tokens (.claude/commands/*.md) skipped — they are /slash commands, not bin/ orphans
- [ ] #4 True orphaned command reference still flagged (verified via fixture)
<!-- AC:END -->
