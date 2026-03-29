---
id: Z-028
title: Implement ZDOTS_SAFE_MODE bypass for heavy integrations
status: To Do
assignee: []
created_date: '2026-03-29 03:08'
labels: []
milestone: Interchangeable Parts
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When ZDOTS_SAFE_MODE=1, skip non-essential conf.d modules (AI, integrations, heavy completions) to provide a minimal safe shell for debugging. Split from Z-011 AC#2.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
