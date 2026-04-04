---
id: Z-032
title: Z-033 - Optimize llama.cpp for performance and limited primary storage
status: To Do
assignee:
  - mike
created_date: '2026-04-04 15:23'
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
- [ ] #1 Convert the synchronous `curl -m 1` check in `providers/ai/llama-cpp.zsh` to a non-blocking backgrounded process.
- [ ] #2 Implement a mechanism to specify an external model storage path for `llama.cpp` models (e.g., via `ZDOTS_AI_MODELS_DIR`).
- [ ] #3 Add a pruning/cleanup utility to the AI provider to remove old or unused models when disk space is low.
- [ ] #4 Verify that the shell startup remains fast even if the `llama.cpp` server is not reachable.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
