---
id: Z-029
title: Add timeout protection for provider initialization
status: To Do
assignee: []
created_date: '2026-03-29 03:08'
labels: []
milestone: Interchangeable Parts
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Wrap zdots_require calls with a timeout mechanism so a hanging provider cannot block shell startup. Split from Z-011 AC#3.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
