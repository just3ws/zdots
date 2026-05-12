---
id: Z-058
title: 'Z-063: Implement DB Lifecycle (Backup/Restore)'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:21'
labels:
  - intelligence-suite
  - postgres
  - ops
dependencies:
  - Z-057
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement robust database lifecycle management, including automated backups and restores. This ensures the system state is versionable and recoverable, treating your 'Shell Brain' as a first-class data asset.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 'zdots-ctx backup' creates a timestamped, compressed SQL dump in ~/my/backups.
- [ ] #2 'zdots-ctx restore <file>' safely recreates the database from a dump.
- [ ] #3 Backup process is integrated into 'make bootstrap' or a weekly cron/hook.
- [ ] #4 Automatic rotation policy (keep last N backups).
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
