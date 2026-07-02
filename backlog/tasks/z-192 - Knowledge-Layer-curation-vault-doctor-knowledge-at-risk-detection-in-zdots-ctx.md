---
id: Z-192
title: >-
  Knowledge Layer curation: vault-doctor + knowledge-at-risk detection in
  zdots-ctx
status: To Do
assignee: []
created_date: '2026-07-01 23:21'
labels:
  - feature
  - platform-service
dependencies: []
priority: low
ordinal: 88890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
bear-vault-doctor (Obsidian vault structural health) and bear-knowledge-map (knowledge-at-risk detection + capture) are Knowledge Layer curation — zdots-ctx territory, generalizable to every vault the platform ingests. Also converges with the 'lessons with teeth' self-improvement move: curation passes that ask what standing check makes each lesson un-forgettable. Add zdots-ctx verbs (or a zdots-vault-doctor) for vault integrity (broken links, orphans, structure) and knowledge-at-risk surfacing, vault-agnostic.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Vault structural health check runs against any vault path (links, orphans, structure)
- [ ] #2 Knowledge-at-risk detection surfaces stale/undocumented areas as review candidates
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
