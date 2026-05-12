---
id: Z-057
title: 'Z-062: Formalize the PostgreSQL Intelligence Schema'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:21'
labels:
  - intelligence-suite
  - postgres
  - schema
dependencies:
  - Z-056
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Define and implement the formal database schema for the intelligence suite in the PostgreSQL instance. This moves away from JSON experimentation into a structured, relational model for methodology and session history.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Migration scripts (init, migrate) implemented in bin/zdots-ctx or a companion script.
- [ ] #2 Schema includes 'methodology', 'lessons_learnt', and 'session_residue' tables.
- [ ] #3 Support for vector embeddings (pgvector) if available, or text-search fallbacks.
- [ ] #4 Verification script to assert schema integrity.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
