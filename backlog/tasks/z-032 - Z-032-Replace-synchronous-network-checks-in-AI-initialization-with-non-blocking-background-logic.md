---
id: Z-032
title: >-
  Z-032 - Replace synchronous network checks in AI initialization with
  non-blocking background logic
status: To Do
assignee:
  - mike
created_date: '2026-04-04 15:15'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current AI initialization logic in `providers/ai/ollama.zsh` performs a synchronous network check via `curl -m 1` and an external process fork via `ollama list` to verify server availability. Despite the comment claiming it is "non-blocking", these calls block shell startup for up to 1 second if the server is down, violating the "Dwight Schrute principle" of shell performance. This task is to move these checks to the background.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Convert the `curl -m 1` and `ollama list` checks in `zdots_ai_init` (providers/ai/ollama.zsh) into backgrounded processes that do not block shell startup.
- [ ] #2 Ensure `zdots_ai_init` returns immediately, even if the AI server is not reachable.
- [ ] #3 Implement a mechanism to update `_ZDOTS_AI_SERVER_UP` and `_ZDOTS_AI_MODEL_PRESENT` flags asynchronously after the shell has loaded.
- [ ] #4 Verify that shell startup time is not impacted by AI server availability (e.g., test with a fake unreachable endpoint).
- [ ] #5 Maintain the existing `zdots_ai_infer` dynamic check for runtime safety.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
