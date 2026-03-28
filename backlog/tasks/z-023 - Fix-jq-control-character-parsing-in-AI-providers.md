---
id: Z-023
title: Fix jq control character parsing in AI providers
status: To Do
assignee: []
created_date: '2026-03-28 04:55'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Address the 'invalid character' error when local LLMs return raw control characters. This involves using 'jq' more defensively when parsing responses or pre-processing the AI output.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Implement robust JSON response parsing in providers/ai/
- [ ] #2 Add defensive character scrubbing if necessary
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
