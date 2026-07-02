---
id: Z-190
title: 'zdots-gh delivery-metrics verbs: dora / standup / rollup'
status: Done
assignee: []
created_date: '2026-07-01 23:21'
updated_date: '2026-07-01 23:47'
labels:
  - feature
  - platform-service
dependencies: []
priority: medium
ordinal: 86890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
work-dora (DORA four keys, source-labeled honesty), work-daily-stand (43K), work-team-rollup, work-portfolio all compute generic delivery metrics over the lake zdots-gh feeds. The math is 100% generic; org framing is tenant. Add 'zdots-gh dora|standup|rollup <owner>' computing from the existing warehouse (deploy frequency, lead time, change-fail, MTTR; flow-first standup; per-engineer rollup), each metric carrying source + honesty label per work-dora's rigor standard. Tenants keep presentation/audience framing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 dora verb computes four keys + lead-time-by-domain from the warehouse with per-metric source labels
- [ ] #2 standup + rollup verbs over the same lake
- [ ] #3 Output stable/parseable (md + --json) so tenant reports are thin wrappers
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Shipped: dora/standup/rollup verbs (SQL computes incl. quantile_cont medians + DORA tier bands; jq renders md and --json from the same rows; per-metric honesty labels solid/proxy/gap per work-dora standard; lead-time by-repo replaces tenant title-keyword domains). Plus --repos concern-scoped warehouses (just3ws platform-trio lake separate from [redacted]) and empty-estate bind-safe warehouse schema. Verified on live [redacted] (four keys render, mttr gaps honestly, json jq-valid) + just3ws (0-issue estate builds, [redacted] parity byte-identical).
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
