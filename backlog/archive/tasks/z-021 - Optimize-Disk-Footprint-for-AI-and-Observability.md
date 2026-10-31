---
id: Z-021
title: Optimize Disk Footprint for AI and Observability
status: Done
assignee: []
created_date: '2026-03-28 02:27'
updated_date: '2026-03-29 03:13'
labels: []
milestone: m-2
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Address the 'finite disk space' constraint, especially for Raspberry Pi nodes. This includes automated model cleanup, preference for highly quantized models, and optimizing the growth of the OTel JSONL trace files.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Implement model presence check and 'smart pull' in AI providers
- [x] #2 Add disk-space warnings to capabilities report
- [x] #3 Implement trace log rotation and compression
- [x] #4 Define 'constrained' model profiles in etc/ai-models.yaml (e.g., < 2GB)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Optimized Zdots for finite disk space environments. 1. Implemented model presence checks in the Ollama provider to warn if a large model is missing. 2. Added a live Disk Available check to bin/capabilities. 3. Implemented a 10MB log rotation bulkhead for the OTel JSONL traces. 4. Defined an ultra-lightweight 'constrained' AI profile using qwen2.5-coder:1.5b (~1GB) for Raspberry Pi nodes.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented smart model pull checks in AI providers, added disk-space warnings to bin/capabilities, introduced 10MB log rotation for OTel JSONL traces, and defined a constrained model profile (qwen2.5-coder:1.5b) in etc/ai-models.yaml for low-resource nodes.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
