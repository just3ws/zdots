---
id: Z-048
title: 'feat(arch): implement declarative service lifecycle module'
status: Done
assignee: []
created_date: '2026-05-08 00:59'
updated_date: '2026-05-08 01:07'
labels: []
milestone: m-4
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Consolidate the duplicated launchd plist generation and registration logic from llama-ctl and otel-collector into a deep declarative interface in lib/lifecycle.bash.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 lib/lifecycle.bash exports a declarative function (e.g. zdots_svc_register) that handles plist generation.
- [x] #2 Existing llama-ctl and otel-collector scripts are refactored to use this new interface.
- [x] #3 launchd services are successfully registered, started, and reported via the new module.
- [x] #4 Unit tests verify correct plist generation and registration logic.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
