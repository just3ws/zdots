---
id: Z-300
title: >-
  [agent-issue] zdots-ctx / ctx MCP tools have no way to edit tags (or any
  field) on an existing lesson or methodolo
status: To Do
assignee: []
created_date: '2026-08-08 22:16'
labels:
  - agent-reported
  - request
dependencies: []
priority: low
ordinal: 175895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** low
**Trace ID:** `60ae42c257383c0d1f1953df6ff769ca`

zdots-ctx / ctx MCP tools have no way to edit tags (or any field) on an existing lesson or methodology after creation — only add-lesson and add-methodology (create-new) exist, no retag/edit/update command. Wanted to add tags (ui-design, ai-design-workflow, prompt-engineering) to lesson 8d24b932-66ee-4ecc-b805-f72d78e7566a which only has the single generic tag video-distillation, but there is no sanctioned interface to do so. Not working around via raw SQL since AGENTS.md restricts zdots_rw writes to zdots-ctx/context-engine only.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
