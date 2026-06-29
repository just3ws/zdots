---
id: Z-179
title: '[agent-issue] Z-172.03: Add Presidio NER as second PHI layer (shadow-mode)'
status: To Do
assignee: []
created_date: '2026-06-29 12:48'
labels:
  - agent-reported
  - request
dependencies: []
priority: high
ordinal: 75890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** high
**Trace ID:** `0d2e75b812e72d620a684e07675a75c9`

Add Microsoft Presidio (spaCy NER) as a second PHI detection layer behind the regex/RE2 gate in etc/phi-patterns.yaml. Not a replacement — catches free-text names/addresses regex is structurally blind to. Shadow-mode first: log what it WOULD redact, never change anything. Measure on SYNTHETIC PHI only. False-positive rate measured before any promotion from shadow to active. PHI pipeline change requires operator coordination per AGENTS.md §5. Tracks Z-172.03.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
