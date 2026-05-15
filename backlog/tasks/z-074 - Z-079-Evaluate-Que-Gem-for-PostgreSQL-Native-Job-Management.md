---
id: Z-074
title: 'Z-079: Evaluate Que Gem for PostgreSQL-Native Job Management'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:43'
labels:
  - industrialization
  - ruby
  - queue
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Evaluate the 'Que' gem as a replacement for the custom Ruby worker. Que uses PostgreSQL advisory locks for high-performance, concurrent job processing without requiring Redis. This would provide true multi-worker safety and scheduled job support.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Benchmarked Que against current custom worker for latency and CPU usage.
- [ ] #2 Verified Que's compatibility with Sequel and the existing jobs table schema.
- [ ] #3 Confirmed Que supports OTel span propagation natively or via middleware.
- [ ] #4 Documented a migration path from the custom worker to Que.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
