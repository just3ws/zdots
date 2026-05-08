---
id: Z-051
title: 'feat(ai): unified model asset management module'
status: To Do
assignee: []
created_date: '2026-05-08 01:00'
labels: []
milestone: m-4
dependencies:
  - Z-049
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extract and unify the HuggingFace model download and management logic from llama-ctl and whisper-ctl into a dedicated 'Model Store' module.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A shared utility (e.g. lib/model-store.bash) manages HF downloads and model caching.
- [ ] #2 llama-ctl and whisper-ctl are refactored to delegate download logic to the store.
- [ ] #3 Supports semantic model aliases (e.g. \"llama:light\") mapped to specific files.
- [ ] #4 Existing models are migrated or correctly linked by the new store.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
