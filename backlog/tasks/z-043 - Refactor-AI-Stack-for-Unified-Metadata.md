---
id: Z-043
title: Refactor AI Stack for Unified Metadata
status: To Do
assignee: []
created_date: '2026-05-06 06:11'
updated_date: '2026-05-06 06:12'
labels: []
milestone: m-3
dependencies:
  - Z-042
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Realize the value of the Metadata Service by refactoring the AI stack. This eliminates duplicate logic and improves shell startup performance by removing redundant subshells.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Update providers/ai/llama-cpp.zsh to use lib/metadata.bash instead of raw yq calls.
- [ ] #2 Update bin/llama-ctl to delegate config resolution to lib/metadata.bash.
- [ ] #3 Ensure ZDOTS_AI_ENDPOINT and ZDOTS_AI_MODEL remain consistent across all tools.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
