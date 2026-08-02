---
id: Z-274
title: >-
  Self-describing docs pipeline: man-gen --refresh, help-structure lint, fold
  interface-inventory into index-tools
status: To Do
assignee: []
created_date: '2026-08-01 09:57'
labels:
  - enhancement
  - audit-filed
dependencies: []
priority: medium
ordinal: 150895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Three drift surfaces, one family:
1. 83 of 103 man pages are frozen --help snapshots with no regeneration path. Add zdots-man-gen --refresh: regenerate .TH-marked (generated) pages only, never .Dd curated ones; guard with the bin/ tree-hash trick; wire to the zdots-index-tools daily path.
2. Help quality is bimodal (Examples in ~18%). Add report-only docs-contract lint: every non-gap --help has a Usage line; >2 subcommands requires Commands: section + >=1 example. Fix long tail via /command-qc passes.
3. interface-inventory.json cited as authority but is a stale 2026-05-29 manual snapshot of ~15 commands. Either fold generation into zdots-index-tools (it already loops every bin --help; keep mutation-risk as a curated overlay) or demote it from authority in documentation-system.md.
Together with Z-264/Z-265 this makes --help the single machine-parseable source feeding man/completions/catalog. (2026-08-01 system audit, cliux)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
