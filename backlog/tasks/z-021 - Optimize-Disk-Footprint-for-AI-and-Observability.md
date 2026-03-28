---
id: Z-021
title: Optimize Disk Footprint for AI and Observability
status: To Do
assignee: []
created_date: '2026-03-28 02:27'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Address the 'finite disk space' constraint, especially for Raspberry Pi nodes. This includes automated model cleanup, preference for highly quantized models, and optimizing the growth of the OTel JSONL trace files.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Implement model presence check and 'smart pull' in AI providers
- [ ] #2 Add disk-space warnings to capabilities report
- [ ] #3 Implement trace log rotation and compression
- [ ] #4 Define 'constrained' model profiles in etc/ai-models.yaml (e.g., < 2GB)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
