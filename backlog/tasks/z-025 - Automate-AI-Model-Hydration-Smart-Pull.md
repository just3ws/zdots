---
id: Z-025
title: Automate AI Model Hydration (Smart Pull)
status: To Do
assignee: []
created_date: '2026-03-28 17:23'
updated_date: '2026-03-29 03:13'
labels: []
milestone: m-2
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement a bootstrap mechanism to automatically pull the specific LLM models required by the active ZDOTS_AI_PROFILE. This ensures AI features are ready immediately upon shell initialization while respecting disk space.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Add 'hydrate' command to AI providers
- [ ] #2 Integrate model hydration into bin/bootstrap
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
