---
id: Z-273
title: >-
  Capabilities attestation honesty: fix malformed entries + teach peer-bootstrap
  metadata/function classes
status: To Do
assignee: []
created_date: '2026-08-01 09:57'
labels:
  - enhancement
  - audit-filed
dependencies: []
priority: medium
ordinal: 149895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Both attestation gaps are parser artifacts, not missing tools (verified by replay 2026-08-01):
- zdots 115/121: 'cmd | ai-query <task>' entry attests literal 'cmd' (ai-query exists); 'pi-ctx-{query,hydrate,status,brace}' attests the brace-literal (all 4 bins exist); zdots_svc_managed/resolve declared '(function)' can never pass command -v; zaider/laid are zsh-function-only (genuinely uninvocable for agents). True availability 117/121.
- adots 26/32: all 6 misses are metadata:VAR=value entries — command -v on a variable assignment, attestable-never. Cost 2+ investigation cycles (Z-196 follow-up, this audit).

Fix: (a) normalize the 2 malformed etc/capabilities.sh entries (ai-query as command word; split pi-ctx brace into 4); (b) peer-bootstrap.bash: attest metadata:* via [ -n "$VAR" ] + path check, '(function)' entries via typeset -f when zsh context available; (c) zaider/laid: thin bin/ wrappers (exec zsh -ic) or re-declare interactive-only. Then session-brief numbers read honest (121/121-ish, 32/32) or fail for real reasons. (2026-08-01 platform audit, contracts — verified)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
