---
id: Z-085
title: >-
  Capture PHI-safe operating guidance in bootstrap and SETUP.md for future
  system seeds
status: To Do
assignee: []
created_date: '2026-05-22 23:49'
labels:
  - phi
  - security
  - bootstrap
  - docs
milestone: m-5
dependencies:
  - Z-083
  - Z-084
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A fresh clone on a regulated machine must self-configure for PHI safety without the developer having to read a separate runbook. Bootstrap gains a PHI-SAFE OPERATING MODE banner (parallel to the AI SECURITY BOUNDARY banner) that fires when ZDOTS_CONTEXT=work, summarising the active safety posture: capture disabled, history redaction on, AI locality enforced, DB encryption key required. SETUP.md gains a 'Regulated / PHI work' section with explicit step-by-step instructions. These files are the system seed — every future clone inherits the guidance automatically.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 bootstrap prints a PHI-SAFE OPERATING MODE banner when ZDOTS_CONTEXT=work listing: capture=disabled, history-redact=on, ai-mode=local, db-encryption=required
- [ ] #2 bootstrap exits with a warning (not error) if ZDOTS_CONTEXT=work and ZDOTS_DB_ENCRYPTION_KEY is unset
- [ ] #3 SETUP.md 'Regulated / PHI work' section covers: setting ZDOTS_CONTEXT=work, generating ZDOTS_DB_ENCRYPTION_KEY, verifying posture with zdots-ctl check
- [ ] #4 zdots-ctl check includes a phi-posture assertion: fails with clear message if ZDOTS_CONTEXT=work but capture or history-redact are misconfigured
- [ ] #5 AGENTS.md Section 8 (or equivalent) summarises PHI operating mode for agent context
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
