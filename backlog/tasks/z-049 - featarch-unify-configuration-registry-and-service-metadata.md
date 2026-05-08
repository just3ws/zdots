---
id: Z-049
title: 'feat(arch): unify configuration registry and service metadata'
status: Done
assignee: []
created_date: '2026-05-08 00:59'
updated_date: '2026-05-08 01:13'
labels: []
milestone: m-4
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deepen the metadata module into a Configuration Registry that provides a unified, semantic interface for retrieving fully resolved service configurations, eliminating duplicated endpoint construction logic.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 lib/metadata.bash provides a semantic interface for service config resolution (e.g. zdots_meta_service_config \"ai\").
- [x] #2 Callers no longer manually construct endpoints or perform complex key mapping.
- [x] #3 llama-ctl and providers/ai/llama-cpp.zsh use the unified registry.
- [x] #4 Tests confirm correct resolution of nested YAML fields into fully formed config objects.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
