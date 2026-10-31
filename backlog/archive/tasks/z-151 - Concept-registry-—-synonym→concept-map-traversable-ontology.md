---
id: Z-151
title: Concept registry — synonym→concept map + traversable ontology
status: Done
assignee: []
created_date: '2026-06-15 01:51'
updated_date: '2026-06-28 20:30'
labels:
  - wave2
  - agent-ready
dependencies:
  - Z-135
ordinal: 42890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Make AGENTS.md §9 vocabulary real as data (replaces fictional GLOSSARY.md/ONTOLOGY.md): concept + concept_alias + concept_link + tag join, exposed via zdots ctx concept verbs. Aliases resolve on ingest so different words land on one concept. See decision-009 + doc-004.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 concept/concept_alias/concept_link/tag tables + migration
- [x] #2 Seeded from AGENTS.md §9 core terms incl. Do-NOT-use lists as disallowed aliases
- [x] #3 zdots ctx concept <slug>|add|alias|link|resolve all emit --json
- [x] #4 AGENTS.md §9 updated: GLOSSARY/ONTOLOGY references point at zdots ctx concept
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC#1 done: concept/concept_alias/concept_link/concept_tag tables in migration 20260628000000_add_knowledge_foundation.rb. Applied + verified cold (4 tables, FKs CASCADE, UNIQUE on lower(alias), uuid PKs).

AC#2 done: lib/zdots/models/concept.rb — Concept.seed_canon! hardcodes all 14 AGENTS.md §9 terms + disallowed aliases. Seeded into DB: `zdots-ctx concept seed-canon` → 14 concepts, 46 aliases. "service" alias belongs to platform-service not capability (unique constraint enforces this).

AC#3 done: zdots-brain concept verb (add/alias/link/resolve/<slug>/seed-canon --json), zdots-ctx concept delegator. Verified: `zdots-ctx concept seam --json` returns JSON with aliases[].

AC#4 done: AGENTS.md §9 updated — concept registry is now live, references `zdots-ctx concept resolve <word>` + `zdots-ctx concept <slug>`. CONTEXT.md remains prose reference.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
