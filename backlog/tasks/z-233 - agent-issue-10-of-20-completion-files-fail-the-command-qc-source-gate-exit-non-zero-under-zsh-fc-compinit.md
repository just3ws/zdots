---
id: Z-233
title: >-
  [agent-issue] 10 of 20 completion files fail the command-qc source gate (exit
  non-zero under zsh -fc compinit)
status: To Do
assignee: []
created_date: '2026-07-15 22:39'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 112895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `64fc7ae163a5227411ce047015e86825`

command-qc step 3 verify — zsh -fc 'autoload -Uz compinit; compinit -C; source functions/enabled/_<cmd>' — exits non-zero for: _cc-doctor _fabric-ai _otel-smoke _ruby-audit _zai _zclaude _zdots-ask _zdots-doctor _zdots-graph-audit _zdots-o2-query. Note the gate is noisy: passing files (e.g. _zsvc) emit the same '_arguments: can only be called from completion function' stderr but exit 0, so the differentiator is exit status only. Either the 10 files have real structural issues (e.g. top-level dispatch executing at source time) or the documented verify command needs hardening; either way the process gate and the files disagree. Suggest wiring the gate into local-ci once resolved so drift is machine-caught.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
