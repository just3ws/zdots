---
id: Z-044
title: Implement Shared Lifecycle Primitives
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-06 06:11'
updated_date: '2026-05-06 06:47'
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
- [x] #1 Create lib/lifecycle.bash containing generic start/stop/status/health primitives.
- [x] #2 Abstract away the differences between launchd (macOS) and background PIDs (CI/Linux).
- [x] #3 Provide a standard 'Adapter' interface for services to declare their metadata (plist labels, ports, endpoints).
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented a unified Service Lifecycle Engine in `lib/lifecycle.bash`.

Key Features:
- Multi-backend support: `launchd` (macOS), `docker-compose`, and `pid`-based background processes (CI/Linux).
- Standardized primitives for `start`, `stop`, `status`, `health`, and `restart`.
- Abstracted OS-specific logic (e.g., `launchctl bootstrap` vs `nohup`) behind a consistent functional interface.
- Includes waiting and health-check helpers with timeout protection.
- Unit tested for `launchd` and `pid` logic via mocks.

This library provides the foundational engine for deep lifecycle management, allowing individual service scripts to become thin adapters.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
