---
id: Z-023
title: Fix jq control character parsing in AI providers
status: Done
assignee: []
created_date: '2026-03-28 04:55'
updated_date: '2026-03-28 05:47'
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
- [x] #1 Implement robust JSON response parsing in providers/ai/
- [x] #2 Add defensive character scrubbing if necessary
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Resolved jq parsing errors by implementing defensive character scrubbing. 1. Refactored Ollama and llama.cpp providers to use 'tr -d' to strip raw control characters from AI responses before passing to jq. 2. Improved extraction logic to use default values (// empty) to prevent jq errors on unexpected JSON structures.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
