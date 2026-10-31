---
id: Z-174
title: >-
  OKF ingest adapter — source_type:okf behind the 009 envelope + concept
  type-bridge
status: Done
assignee: []
created_date: '2026-06-28 16:33'
updated_date: '2026-06-28 21:23'
labels:
  - agent-ready
  - knowledge-layer
dependencies:
  - Z-150
  - Z-151
priority: medium
ordinal: 70890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add an OKF (Open Knowledge Format v0.1) bundle reader as a source_type behind decision-009's ingest envelope. Each concept .md -> a source_document row (body_md = markdown body, frontmatter -> provenance). The type-bridge resolves OKF type/tags through concept_alias to canonical concept tags; unknown types tolerated and logged for registry curation. Conforms to the zdots OKF profile (doc-006). Rides 009 (DB stays the store) per decision-010. Links ingested as untyped concept tags in v1 (prose->typed-relation deferred).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zdots ctx ingest <bundle> --type okf creates source_document rows
- [ ] #2 OKF type/tags resolve to concept slugs via concept_alias
- [ ] #3 unknown types tolerated and logged, not rejected
- [ ] #4 round-trips a fixture bundle: tags land on correct concepts
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
