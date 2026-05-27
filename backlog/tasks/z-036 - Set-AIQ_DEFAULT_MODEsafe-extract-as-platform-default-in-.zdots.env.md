---
id: Z-036
title: Set AIQ_DEFAULT_MODE=safe-extract as platform default in .zdots.env
status: Done
assignee: []
created_date: '2026-04-19 02:32'
updated_date: '2026-05-27 17:42'
labels:
  - ai-query
  - security
  - config
dependencies: []
modified_files:
  - .zdots.env
  - docs/ai-query.md
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
All tooling that calls ai-query should get safe-extract mode without requiring per-call flags. Currently, if AIQ_DEFAULT_MODE is not set, the script defaults to safe-extract via code — but this is not enforced at the platform config layer. Scripts that call ai-query with no --mode flag rely on a code default rather than explicit operator intent. Setting AIQ_DEFAULT_MODE=safe-extract in the platform environment config makes the intended default visible, auditable, and immune to future code-default drift.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 AIQ_DEFAULT_MODE=safe-extract is present in .zdots.env (or the canonical platform environment config file),docs/ai-query.md reflects AIQ_DEFAULT_MODE=safe-extract as the documented platform default,Existing ai-query tests pass with no regressions after the config change
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added AIQ_DEFAULT_MODE=safe-extract to .zdots.env section 4 (AI Tool Defaults). Uses parameter expansion default so local overrides still work. docs/ai-query.md already documented this as the platform default.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
