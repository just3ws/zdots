---
id: Z-066
title: 'Z-071: Implement Async Embed Worker'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 22:57'
labels:
  - intelligence-suite
  - queue
  - ai
dependencies:
  - Z-065
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create an asynchronous worker job that takes raw text from newly added lessons or methodologies, generates an embedding via the local AI, and updates the database row. This ensures shell commands aren't blocked by slow embedding generation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Add 'embed' job type to zdots-ctx worker.
- [ ] #2 Worker successfully calls local /v1/embeddings endpoint and updates the target row's vector column.
- [ ] #3 zdots-ctx add-methodology and add-lesson automatically enqueue an 'embed' job upon success.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
