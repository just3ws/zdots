---
id: Z-136
title: >-
  [agent-issue] zsynod init emits jq missing members.json stderr on fresh
  ZSYNOD_DIR while exiting 0
status: Done
assignee: []
created_date: '2026-06-07 22:18'
updated_date: '2026-06-15 00:31'
labels:
  - agent-reported
  - bug
  - wave4
dependencies: []
priority: medium
ordinal: 27890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `477447f357ef1f5e67726fab77d02749`

zsynod init emits jq missing members.json stderr on fresh ZSYNOD_DIR while exiting 0

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 zsynod init on a fresh ZSYNOD_DIR produces clean stderr and exits 0 (members.json still created)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Done 2026-06-14 (sonnet). _voting_ids() now guards [[ -f $MEMBERS ]] || return 0 (mirrors _member_known); fresh-init jq stderr noise gone. Test: zsynod_init.bats 'quiet on fresh ZSYNOD_DIR' green; syntax ok; secret-scan ok.
<!-- SECTION:NOTES:END -->
