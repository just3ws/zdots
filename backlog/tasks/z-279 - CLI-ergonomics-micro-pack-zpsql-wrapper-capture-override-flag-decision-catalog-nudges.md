---
id: Z-279
title: >-
  CLI ergonomics micro-pack: zpsql wrapper, capture-override flag decision,
  catalog nudges
status: To Do
assignee: []
created_date: '2026-08-01 09:57'
labels:
  - enhancement
  - audit-filed
dependencies: []
priority: low
ordinal: 155895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
From usage synthesis (12.7k agent calls + human history): (a) add bin/zpsql — Keychain lookup + zdots_ro psql, replacing the hand-typed PGPASSWORD="$(security find-generic-password ...)" psql incantation (31 observed; also keeps Keychain access inside one auditable wrapper); reference in AGENTS.md §7. (b) ZDOTS_CAPTURE_ENABLED=1 per-call override appears in the wild — either sanction it as a documented zdots-ctx capture flag or make it warn. (c) surface zdots-platform and 'zsvc health' in the tooling-catalog hydrate blob — observed 122 raw bare-git adots invocations vs 15 wrapper uses, and hand-rolled curl health probes. (2026-08-01 system audit, usage)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
