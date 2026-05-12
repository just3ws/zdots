---
id: Z-046
title: Refactor Service Lifecycle for OTel and AI
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-06 06:12'
updated_date: '2026-05-12 17:17'
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
- [x] #1 Refactor bin/llama-ctl to use lib/lifecycle.bash.
- [x] #2 Refactor bin/otel-collector to use lib/lifecycle.bash.
- [x] #3 Verify status and health commands return consistent structured output.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Refactored bin/llama-ctl and bin/otel-collector to use centralized lifecycle primitives in lib/lifecycle.bash.
Added new helpers:
- zdots_svc_print_status: Standardized text/JSON status output with support for custom metadata.
- zdots_svc_print_health: Standardized text/JSON health output.
- zdots_svc_logs: Standardized log tailing with clean exit traps.

Modified bin/llama-ctl and bin/otel-collector to:
- Use zdots_svc_restart for the restart command.
- Delegate status, health, and logs to the new helpers.
- Pass service-specific metadata (e.g., AI profile, active model) to the status helper.

Verified consistent JSON output and passed all 160 tests in `make check`.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
