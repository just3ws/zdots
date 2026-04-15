---
id: Z-032
title: Z-033 - Optimize llama.cpp for performance and limited primary storage
status: Done
assignee:
  - mike
created_date: '2026-04-04 15:23'
updated_date: '2026-04-15 11:51'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The `llama.cpp` integration needs to be hardened for performance and storage efficiency. This involves making health checks non-blocking and supporting external model storage to respect the user's primary disk constraints. This aligns with the "Dwight Schrute principle" of performance-conscious engineering.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Convert the synchronous `curl -m 1` check in `providers/ai/llama-cpp.zsh` to a non-blocking backgrounded process.
- [x] #2 Implement a mechanism to specify an external model storage path for `llama.cpp` models (e.g., via `ZDOTS_AI_MODELS_DIR`).
- [x] #3 Add a pruning/cleanup utility to the AI provider to remove old or unused models when disk space is low.
- [x] #4 Verify that the shell startup remains fast even if the `llama.cpp` server is not reachable.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All ACs completed in the llama.cpp bring-up session.\n\n- AC #1: Non-blocking health check implemented in `providers/ai/llama-cpp.zsh:zdots_ai_init` — backgrounded curl with `&!`, never blocks prompt.\n- AC #2: `ZDOTS_AI_MODELS_DIR` wired in both provider and `bin/llama-ctl`; override to external SSD documented in `docs/storage-hygiene.md`.\n- AC #3: `llama-ctl model-prune` deletes all GGUFs except the active profile's model.\n- AC #4: Shell startup unaffected when server is down — health check is fire-and-forget.\n\nmake check: 14/14 pass (verified in Z-031 session).
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output
- [x] #2 file path
- [x] #3 or test result)
- [x] #4 make check passes with output captured in task notes or commit message
- [x] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
