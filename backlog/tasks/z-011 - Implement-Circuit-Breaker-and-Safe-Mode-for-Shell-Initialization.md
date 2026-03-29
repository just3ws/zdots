---
id: Z-011
title: Implement Circuit Breaker and 'Safe Mode' for Shell Initialization
status: Done
assignee: []
created_date: '2026-03-27 16:24'
updated_date: '2026-03-29 03:05'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement a 'Bulkhead' pattern for shell initialization. If a specific module (conf.d) or provider fails or times out, the system should catch the error, log it to the OTel control plane, and continue loading the rest of the environment in a degraded but functional state.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Wrap conf.d sourcing in a protective 'try/catch' style helper
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fully implemented the 'Bulkhead' pattern via zdots_safe_source. Isolated module loading verified with poison-pill testing.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented zdots_safe_source in env.sh as a POSIX-compatible circuit breaker wrapper. Modules loaded via conf.d loop in .zshrc are protected from cascading failures. ZDOTS_SAFE_MODE and timeout protection split to separate tasks.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
