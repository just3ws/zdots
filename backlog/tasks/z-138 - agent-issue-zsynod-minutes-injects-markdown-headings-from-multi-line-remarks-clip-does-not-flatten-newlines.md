---
id: Z-138
title: >-
  [agent-issue] zsynod minutes injects markdown headings from multi-line remarks
  (clip does not flatten newlines)
status: To Do
assignee: []
created_date: '2026-06-08 19:20'
updated_date: '2026-06-14 18:37'
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
- [ ] #1 Multi-line remark renders as a single bullet line in minutes.md
- [ ] #2 No remark text appears as a real markdown heading
- [ ] #3 tests/zsynod_minutes.bats passes
<!-- AC:END -->
