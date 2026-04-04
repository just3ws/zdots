---
id: Z-033
title: Z-034 - Design and implement optimal AI shell integration for llama.cpp
status: To Do
assignee:
  - mike
created_date: '2026-04-04 15:23'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The goal is to determine and implement the most effective way for the AI (`llama.cpp`) to assist the user within the shell environment. This includes context-awareness (CWD, history, environment) and seamless integration via a lightweight alias or hook, following the "Dwight Schrute principle" of high-signal, low-friction UX.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Research and define a standard prompt structure for shell AI (including CWD, OS, and history context).
- [ ] #2 Implement a `?` or `ai` alias that sends the current shell context (last command, output, and PWD) to `llama.cpp` for analysis.
- [ ] #3 Create a 'smart command suggestion' utility that uses `llama.cpp` to suggest the next command based on history.
- [ ] #4 Ensure that the AI responses are properly redacted via `zdots_trace_redact` before logging to telemetry.
- [ ] #5 Verify the integration works seamlessly with the `llama.cpp` OpenAI-compatible API.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
