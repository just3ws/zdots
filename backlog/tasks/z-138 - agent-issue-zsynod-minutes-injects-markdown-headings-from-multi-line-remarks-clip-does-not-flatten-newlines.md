---
id: Z-138
title: >-
  [agent-issue] zsynod minutes injects markdown headings from multi-line remarks
  (clip does not flatten newlines)
status: Done
assignee: []
created_date: '2026-06-08 19:20'
updated_date: '2026-06-15 00:31'
labels:
  - agent-reported
  - wave4
dependencies: []
priority: medium
ordinal: 29890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
zsynod 'minutes' renders a multi-line remark (pasted markdown such as '# zsynod turn' / '## Proposals') as real headings mid-document, because the cmd_minutes 'clip' jq helper truncated by length without flattening newlines. Observed under P5/P6 in zsynod/minutes.md.

FIXED in commit alongside this issue: all four 'clip' definitions in bin/zsynod now 'gsub("\\s+";" ")' (flatten + trim) before truncating, so a remark always renders on one bullet line. Ledger canon is immutable and unchanged — render-time fix only. Regression test: tests/zsynod_minutes.bats (2 cases, green).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Multi-line remark renders as a single bullet line in minutes.md
- [x] #2 No remark text appears as a real markdown heading
- [ ] #3 tests/zsynod_minutes.bats passes
- [ ] #4 multi-line remark renders as a single flattened bullet — no injected markdown headings
- [ ] #5 canonical section headings still render
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Done — fix already on main (701d2301, clip flattens whitespace at all 4 sites; experiments/zsynod/tests/zsynod_minutes.bats). Verified green this session. No new integration needed.
<!-- SECTION:NOTES:END -->
