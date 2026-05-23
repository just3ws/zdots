---
id: Z-090
title: Assert macOS Application Firewall is enabled in zdots-ctl check
status: To Do
assignee: []
created_date: '2026-05-23 01:21'
labels:
  - phi
  - security
  - firewall
  - macos
milestone: m-5
dependencies:
  - Z-077
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The macOS Application Firewall (socketfilterfw) provides OS-level network filtering. zdots-ctl check should assert it is enabled on darwin work machines as a baseline security requirement. For defense-in-depth, document how to add application-specific rules that block curl and llama-server from reaching known cloud AI endpoints — a second gate behind zdots_assert_local_endpoint that operates at the kernel level.\n\nzdots-ctl check currently has no macOS security posture assertions. This adds the first, with a clear failure message and remediation command.\n\n  Check:    /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate\n  Enable:   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zdots-ctl check includes firewall assertion on darwin: fails with clear message and remediation command if Application Firewall is off
- [ ] #2 Assertion is skipped (with log notice) on non-darwin systems
- [ ] #3 zdots-ctl check --json includes firewall_enabled: true/false field in platform section
- [ ] #4 SETUP.md 'Regulated / PHI work' section documents enabling the firewall and optionally adding block rules for known cloud AI hostnames
- [ ] #5 Assertion failure is non-fatal by default (warning, not error) — operator may have network-level controls instead; ZDOTS_SKIP_FIREWALL_CHECK=1 suppresses it
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
