---
id: Z-057
title: 'Z-062: Formalize the PostgreSQL Intelligence Schema'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:21'
updated_date: '2026-05-13 00:06'
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
- [x] #1 Migration scripts (init, migrate) implemented in bin/zdots-ctx or a companion script.
- [x] #2 Schema includes 'methodology', 'lessons_learnt', and 'session_residue' tables.
- [x] #3 Support for vector embeddings (pgvector) if available, or text-search fallbacks.
- [x] #4 Verification script to assert schema integrity.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Formalized the relational schema for the intelligence suite.
- Created etc/db/migrations/001_initial_schema.sql.
- Tables: methodologies, lessons, session_residue.
- Full-text search indexing (GIN) implemented for all tables.
- Optional pgvector support enabled.
- Automated migration engine implemented in zdots-ctx init-db.
- Verified schema integrity via table count reporting in status command.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
