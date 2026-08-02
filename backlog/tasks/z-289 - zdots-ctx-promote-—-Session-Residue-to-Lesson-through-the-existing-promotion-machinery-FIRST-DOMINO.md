---
id: Z-289
title: >-
  zdots-ctx promote — Session Residue to Lesson through the existing promotion
  machinery (FIRST DOMINO)
status: To Do
assignee: []
created_date: '2026-08-02 17:31'
labels:
  - agent-ready
dependencies: []
priority: high
ordinal: 165895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 90-day keystone (doc-003): the Virtuous Loop is dormant session-side because promote does not exist. The context-engine ALREADY has promotion machinery (transcription pipeline: raw -> cleaned -> distilled -> promoted, with doubt loop) — follow that seam rather than inventing one: zdots-ctx promote <residue-id> routes a Session Residue through the same distill/promote path to produce a draft Lesson for operator curation. Contract first: define what a promotable residue must carry (intent/result/summary already in schema — 23 rows exist). Local AI does the distillation (ai-query, on-box). Acceptance: one real residue from this machine becomes a curated Lesson end-to-end. SEQUENCING: this task unblocks Z-290 and Z-291 — every quarter it waits is a quarter of unlearned lessons.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
