---
id: Z-039
title: Emit scan findings in --json output for programmatic consumers
status: To Do
assignee: []
created_date: '2026-04-19 02:32'
labels:
  - ai-query
  - security
  - dx
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Tools that call ai-query --json (CI scripts, RubyLLM integrations, agent pipelines) receive content and top-level risk metadata but not the individual scanner findings. A consumer that wants to branch on a specific finding type — for example, take different action when EXEC_COMMAND is detected vs REDIRECT_INSTEAD — cannot do so without re-implementing the scanner rules. Exposing structured findings in the JSON output closes this gap and makes ai-query a complete programmatic interface for downstream tooling.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 --json output includes a findings array: each element contains weight, name, and excerpt for each scanner rule that matched,risk_score and risk_level remain at the top level of the JSON object unchanged (backward compatible),findings is an empty array [] when no scanner patterns match,All existing --json key names are preserved with no breaking changes,Tests verify: findings array is present and valid JSON on all --json invocations; findings is [] on clean input; findings is correctly populated on an injection fixture input
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
