---
id: Z-349
title: >-
  Usage-backed Brewfile audit: cross-reference formulae against Atuin shell
  history
status: To Do
assignee: []
created_date: '2026-10-20 15:55'
labels:
  - agent-reported
  - enhancement
dependencies: []
priority: medium
type: enhancement
ordinal: 224895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Cross-reference the 208 installed Homebrew leaves and 386 declared Brewfile.* entries against the 10,885 commands in ~/.local/share/atuin/history.db (and traces.jsonl) from the past 7 months. Identify Tier 3 zero-use packages and generate a report for safe operator review before pruning.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Map declared Homebrew formulae to their provided binary names
- [ ] #2 Query Atuin SQLite history for binary execution frequencies over 180 days
- [ ] #3 Generate annotated report of zero-use candidates without auto-uninstalling
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
