---
id: Z-013
title: Inject Environment into Lightweight Linux (Debian/Raspberry Pi)
status: To Do
assignee: []
created_date: '2026-03-27 16:29'
labels: []
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend the provider pattern to support lightweight Debian-based environments like Raspberry Pi. This includes creating apt-based providers and ensuring the performance budget is maintained on slower ARM hardware.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Add Debian/Raspberry Pi profile to .zdots.env
- [ ] #2 Verify performance on low-resource hardware
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
