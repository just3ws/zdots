---
id: Z-133
title: Adopt promptfoo for local-model and PHI-rule evals
status: To Do
assignee: []
created_date: '2026-06-06 00:10'
updated_date: '2026-06-14 18:37'
labels:
  - ai-tooling
  - testing
  - agent-ready
  - wave1
dependencies: []
priority: low
ordinal: 24890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
"Unit testing for LLMs." Use promptfoo to run automated evals against the local llama.cpp endpoint — e.g. does Qwen3-14B follow the PHI Operating Mode rules better than smaller models, and how do thinking vs non-thinking modes compare. Must stay local-only (point at http://127.0.0.1:11500; configure no cloud providers).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Install promptfoo and confirm it can target the local llama.cpp OpenAI-compatible endpoint
- [ ] #2 Author an initial eval suite covering PHI-rule adherence and thinking vs non-thinking output
- [ ] #3 No cloud providers configured — evals run entirely against local endpoints
- [ ] #4 Document usage (where evals live, how to run)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
