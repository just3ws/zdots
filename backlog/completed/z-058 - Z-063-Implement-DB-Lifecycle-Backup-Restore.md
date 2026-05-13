---
id: Z-058
title: 'Z-063: Implement DB Lifecycle (Backup/Restore)'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:21'
updated_date: '2026-05-13 00:06'
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
- [x] #1 'zdots-ctx backup' creates a timestamped, compressed SQL dump in ~/my/backups.
- [x] #2 'zdots-ctx restore <file>' safely recreates the database from a dump.
- [x] #3 Backup process is integrated into 'make bootstrap' or a weekly cron/hook.
- [x] #4 Automatic rotation policy (keep last N backups).
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented database lifecycle management in zdots-ctx.
- 'backup' command creates compressed SQL dumps in ~/my/backups.
- 'restore' command safely overwrites the database from a dump with a safety prompt.
- Automated rotation policy keeps the last 10 backups.
- Verified backup and restore workflows with live data.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
