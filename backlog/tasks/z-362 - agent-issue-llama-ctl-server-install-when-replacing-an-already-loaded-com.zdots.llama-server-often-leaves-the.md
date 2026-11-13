---
id: Z-362
title: >-
  [agent-issue] llama-ctl server install, when replacing an already-loaded
  com.zdots.llama-server, often leaves the
status: Done
assignee: []
created_date: '2026-11-13T17:33:00Z'
updated_date: '2026-11-13T20:10:00Z'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 239895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `7a084f400fe91d285e4b113951e052c5`

llama-ctl server install, when replacing an already-loaded com.zdots.llama-server, often leaves the service NOT loaded: it prints 'server started' (once with '[!!] check logs'), but launchctl print reports 'Could not find service' and :11500 is down. Seen 2 of 4 installs on 2026-11-13 while switching ZDOTS_AI_PROFILE; a second install fixes it. Likely bootout/bootstrap race (bootout returns before the old process exits). Readiness wait passed against the dying old server.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Root cause: install_llama and install_embed unloaded the old job with a bare `launchctl bootout`, which returns while launchd still lists the job as SIGTERMed. zdots_svc_launchd_start then took its "SIGTERMed — KeepAlive will restart it" branch, but bootout had removed KeepAlive, so nothing loaded. Fix: both installers use zdots_svc_launchd_stop (which already waited until the job is gone), and a new zdots_svc_launchd_require_loaded makes install exit 1 if the job is not loaded after start. Tests: tests/lifecycle.bats reproduces the lingering SIGTERMed job with a fake launchctl and checks the installers. On the work Mac: llama-ctl server install 3/3 loaded and healthy (was 2/4), embed install loaded and healthy.
<!-- SECTION:FINAL_SUMMARY:END -->
