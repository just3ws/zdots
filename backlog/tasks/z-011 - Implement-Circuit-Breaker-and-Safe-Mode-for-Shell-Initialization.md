---
id: Z-011
title: Implement Circuit Breaker and 'Safe Mode' for Shell Initialization
status: In Progress
assignee: []
created_date: '2026-03-27 16:24'
updated_date: '2026-03-27 23:32'
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
- [ ] #2 Implement ZDOTS_SAFE_MODE to bypass heavy integrations
- [ ] #3 Add timeout protection for provider initialization
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented the 'zdots_safe_source' bulkhead in env.sh and integrated it into the .zshrc loading loop. Verified the circuit breaker by sourcing a 'poison pill' file with a syntax error and confirming the shell remains operational.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
