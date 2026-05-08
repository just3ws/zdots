---
id: Z-050
title: 'feat(arch): enforce opaque service control seam in orchestrator'
status: In Progress
assignee: []
created_date: '2026-05-08 01:00'
updated_date: '2026-05-08 01:22'
labels: []
milestone: m-4
dependencies:
  - Z-048
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Refactor the platform orchestrator (zdots-ctl) to use the standardized CLI grammar of individual services (start/stop/status) rather than reaching into implementation details like launchctl.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zdots-ctl status uses the CLI interface of child services (e.g. otel-collector status --json) instead of launchctl directly.
- [ ] #2 Removing or changing the launchd implementation of a service does not break zdots-ctl.
- [ ] #3 zdots-ctl health checks are derived from service-level health subcommands.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
