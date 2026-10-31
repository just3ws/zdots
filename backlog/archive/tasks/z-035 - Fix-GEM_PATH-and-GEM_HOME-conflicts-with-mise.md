---
id: Z-035
title: Fix GEM_PATH and GEM_HOME conflicts with mise
status: Done
assignee: []
created_date: '2026-04-08 15:59'
updated_date: '2026-04-08 15:59'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
GEM_PATH and GEM_HOME in env.sh are causing conflicts with mise-managed Ruby versions. Removing these global exports allows mise to manage the Ruby environment correctly.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 GEM_HOME and GEM_PATH are no longer exported globally in env.sh.
- [x] #2 mise-managed Ruby works without environment variable conflicts.
- [x] #3 Existing tests pass.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed global GEM_HOME and GEM_PATH from env.sh. These exports were causing conflicts with mise-managed Ruby versions, which prefer these variables to be unset or managed by mise for correct version isolation. Verified that Bats tests still pass and that these variables are no longer present in env.sh or PATH.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
