---
id: Z-100
title: Application Firewall assertion in zdots-ctl check
status: To Do
assignee: []
created_date: '2026-05-23 21:40'
labels:
  - phi-safe
  - security
milestone: m-5
dependencies:
  - Z-099
modified_files:
  - bin/zdots-ctl
  - lib/phi_assertions.bash
priority: medium
ordinal: 850
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The macOS Application Firewall controls inbound connections per-application. On a PHI machine it should be enabled to prevent unexpected inbound network access to local services (llama-server, PostgreSQL, LGTM stack). 

Check state via `defaults read /Library/Preferences/com.apple.alf globalstate` (1 = on, 2 = on + block all). Warn if 0 (off). This is lower priority than FileVault because the PHI risk is inbound access, not data exfiltration — but it belongs in the same check section.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `zdots-ctl check` reports Application Firewall state under PHI section
- [ ] #2 WARN (not FAIL) if firewall is off — does not block `zdots-ctl up`
- [ ] #3 macOS-only; skipped on non-darwin
- [ ] #4 Output follows PASS/WARN/FAIL structured format established in Z-091
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
