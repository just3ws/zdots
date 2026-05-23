---
id: Z-091
title: Assert SIP and FileVault status in zdots-ctl check on darwin work machines
status: To Do
assignee: []
created_date: '2026-05-23 01:21'
labels:
  - phi
  - security
  - macos
  - sip
  - filevault
milestone: m-5
dependencies:
  - Z-077
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On a regulated work machine, System Integrity Protection (SIP) and FileVault are non-negotiable baseline controls. Neither is currently checked by zdots-ctl check. A PHI-context machine that has SIP disabled or an unencrypted disk is out of compliance regardless of what zdots does at the application layer.\n\n  SIP:       csrutil status  → \"System Integrity Protection status: enabled.\"\n  FileVault: fdesetup status → \"FileVault is On.\"\n\nBoth checks run only on darwin and only when ZDOTS_CONTEXT=work. Failure is a hard check failure — not a warning — because these are prerequisites for the application-layer controls to be meaningful.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zdots-ctl check asserts SIP is enabled on darwin when ZDOTS_CONTEXT=work; failure is a hard check failure with remediation note
- [ ] #2 zdots-ctl check asserts FileVault is On on darwin when ZDOTS_CONTEXT=work; failure is a hard check failure
- [ ] #3 Both assertions are skipped on non-darwin or when ZDOTS_CONTEXT != work (with a log notice)
- [ ] #4 zdots-ctl check --json includes sip_enabled and filevault_enabled fields in platform section
- [ ] #5 SETUP.md 'Regulated / PHI work' section documents both requirements and how to verify
- [ ] #6 Assertions use only standard macOS CLI tools (csrutil, fdesetup) — no third-party dependencies
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
