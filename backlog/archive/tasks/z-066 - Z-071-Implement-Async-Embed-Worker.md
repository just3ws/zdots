---
id: Z-066
title: 'Z-071: Implement Async Embed Worker'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 22:57'
updated_date: '2026-05-14 01:20'
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
- [x] #1 Add 'embed' job type to zdots-ctx worker.
- [x] #2 Worker successfully calls local /v1/embeddings endpoint and updates the target row's vector column.
- [x] #3 zdots-ctx add-methodology and add-lesson automatically enqueue an 'embed' job upon success.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented the Async Embed Worker to automate vector indexing.
- Added 'embed' job type to the `zdots-ctx worker`.
- Implemented robust multi-line text handling using temp files for `/v1/embeddings` curl calls.
- Updated `add-methodology`, `add-lesson`, `seed`, and `capture` commands to automatically enqueue embedding jobs.
- Verified successful background embedding of seeded methodologies.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
