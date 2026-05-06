---
id: Z-044
title: Implement Shared Lifecycle Primitives
status: To Do
assignee: []
created_date: '2026-05-06 06:11'
updated_date: '2026-05-06 06:12'
labels: []
milestone: m-3
dependencies:
  - Z-042
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extract shared lifecycle logic from bin/llama-ctl, bin/otel-collector, and bin/local-ci into a deep library. This concentrates 'how' services are managed in one place.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Create lib/lifecycle.bash containing generic start/stop/status/health primitives.
- [ ] #2 Abstract away the differences between launchd (macOS) and background PIDs (CI/Linux).
- [ ] #3 Provide a standard 'Adapter' interface for services to declare their metadata (plist labels, ports, endpoints).
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
