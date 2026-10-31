---
id: Z-056
title: 'Z-061: Implement the zdots-ctx CLI Bridge'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:20'
updated_date: '2026-05-13 00:06'
labels:
  - intelligence-suite
  - cli
  - postgres
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the primary CLI interface in Zdots to bridge the shell with the PostgreSQL intelligence suite. This tool will serve as the single entry point for all context-related operations (query, capture, hydrate).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 bin/zdots-ctx exists and is executable.
- [x] #2 Command 'zdots-ctx status' verifies connection to the Postgres database in ~/my.
- [x] #3 Supports --json flag for AI-consumable output of connection metadata.
- [x] #4 Implements a basic 'ping' query to the database.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented the primary CLI interface for the PostgreSQL Intelligence Suite.
- Created bin/zdots-ctx with support for status, query, hydrate, backup, and restore.
- Integrated connection verification into zdots-ctl.
- Added --json support for automated discovery.
- Successfully verified database connectivity and metadata reporting.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
