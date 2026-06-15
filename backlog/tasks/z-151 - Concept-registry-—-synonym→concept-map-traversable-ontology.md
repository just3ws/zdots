---
id: Z-151
title: Concept registry — synonym→concept map + traversable ontology
status: To Do
assignee: []
created_date: '2026-06-15 01:51'
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
- [ ] #1 concept/concept_alias/concept_link/tag tables + migration
- [ ] #2 Seeded from AGENTS.md §9 core terms incl. Do-NOT-use lists as disallowed aliases
- [ ] #3 zdots ctx concept <slug>|add|alias|link|resolve all emit --json
- [ ] #4 AGENTS.md §9 updated: GLOSSARY/ONTOLOGY references point at zdots ctx concept
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
