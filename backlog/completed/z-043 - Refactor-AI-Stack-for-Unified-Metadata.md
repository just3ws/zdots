---
id: Z-043
title: Refactor AI Stack for Unified Metadata
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-06 06:11'
updated_date: '2026-05-06 06:41'
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
- [x] #1 Update providers/ai/llama-cpp.zsh to use lib/metadata.bash instead of raw yq calls.
- [x] #2 Update bin/llama-ctl to delegate config resolution to lib/metadata.bash.
- [x] #3 Ensure ZDOTS_AI_ENDPOINT and ZDOTS_AI_MODEL remain consistent across all tools.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Refactored the AI stack to use the unified Platform Metadata Service.

Key Changes:
- `providers/ai/llama-cpp.zsh`: Replaced redundant `yq` calls and background subshells with `lib/metadata.bash env ai`.
- `bin/llama-ctl`: Integrated the metadata service for configuration resolution, eliminating duplicate YAML parsing logic.
- Performance: Significantly reduced shell startup overhead by consolidating metadata resolution into a single `yq` call (via the metadata service) rather than multiple calls.
- Consistency: Ensured `ZDOTS_AI_ENDPOINT` and `ZDOTS_AI_MODEL` are derived from the same source of truth across all tools.

Verification:
- `bin/llama-ctl config` and `status` verified for correct output.
- `ai-query` and `zaider` confirmed to still function correctly with the refactored provider.
- No regressions in health check or service management.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
