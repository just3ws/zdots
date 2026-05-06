---
id: Z-046
title: Refactor Service Lifecycle for OTel and AI
status: To Do
assignee: []
created_date: '2026-05-06 06:12'
labels: []
milestone: m-3
dependencies:
  - Z-044
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Apply the shared lifecycle primitives to the two primary host services. This removes manual launchctl/curl boilerplate from individual scripts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Refactor bin/llama-ctl to use lib/lifecycle.bash.
- [ ] #2 Refactor bin/otel-collector to use lib/lifecycle.bash.
- [ ] #3 Verify status and health commands return consistent structured output.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
