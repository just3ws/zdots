---
id: Z-102
title: sandbox-exec profile for llama-server — contain local inference process
status: To Do
assignee: []
created_date: '2026-05-23 21:41'
updated_date: '2026-06-14 18:37'
labels:
  - phi-safe
  - security
  - wave4
milestone: m-5
dependencies: []
modified_files:
  - etc/llama-server.sb
  - bin/llama-ctl
priority: low
ordinal: 890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
llama-server is a network-accessible inference process. Even though `Zdots::AI.assert_local!` prevents calling non-local endpoints, a compromised or buggy llama-server could exfiltrate data it receives. `sandbox-exec` (macOS) can restrict what the process can read/write/connect to.

Profile should: allow read of model files (specific path), allow bind on 127.0.0.1:8080 only, deny all outbound network, deny write to anything outside a temp scratch dir.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 sandbox-exec profile written to `etc/llama-server.sb`
- [ ] #2 llama-ctl start wraps llama-server invocation with `sandbox-exec -f etc/llama-server.sb`
- [ ] #3 Profile tested: model loads, inference works, outbound network attempt is blocked
- [ ] #4 Fallback: if sandbox-exec is unavailable or profile fails, llama-ctl logs a warning and starts without sandbox (does not hard-block)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
