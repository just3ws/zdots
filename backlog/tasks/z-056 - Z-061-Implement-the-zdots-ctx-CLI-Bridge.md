---
id: Z-056
title: 'Z-061: Implement the zdots-ctx CLI Bridge'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:20'
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
- [ ] #1 bin/zdots-ctx exists and is executable.
- [ ] #2 Command 'zdots-ctx status' verifies connection to the Postgres database in ~/my.
- [ ] #3 Supports --json flag for AI-consumable output of connection metadata.
- [ ] #4 Implements a basic 'ping' query to the database.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
