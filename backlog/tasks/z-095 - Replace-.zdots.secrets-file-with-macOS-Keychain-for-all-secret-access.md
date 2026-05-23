---
id: Z-095
title: Replace .zdots.secrets file with macOS Keychain for all secret access
status: To Do
assignee: []
created_date: '2026-05-23 16:15'
labels:
  - phi-safe
  - security
  - agent-ready
milestone: m-5
dependencies: []
modified_files:
  - bin/bootstrap
  - lib/keychain.bash
  - .zdots.env
  - SETUP.md
priority: high
ordinal: 870
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`.zdots.secrets` is a plaintext file that exports `ZDOTS_DB_ENCRYPTION_KEY` and any API keys. On a work machine it represents a PHI risk: it can be synced to iCloud Drive, accidentally committed, or read by any process with filesystem access. FileVault protects at rest but not against in-session file reads.

The `Zdots::Crypto::KeyStore` seam (added in e7e0a54) already centralises all key reads — Z-087 is now a 1-file change plus bootstrap wiring.

Replace the `.zdots.secrets` file mechanism with direct Keychain reads at shell startup. The file should be removed from all machines after migration; its gitignore entry stays as a tombstone.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zdots startup sources no plaintext secrets file on macOS — ZDOTS_DB_ENCRYPTION_KEY and any API key tokens are loaded via `security find-generic-password` at shell init
- [ ] #2 bin/bootstrap provisions Keychain entries if absent (prompts user; does not store in any file)
- [ ] #3 .zdots.secrets file can be deleted from all machines after migration without breaking anything
- [ ] #4 Zdots::Crypto::KeyStore.current_key continues to work — reads ENV var that was populated from Keychain
- [ ] #5 zdots-ctl check reports PASS for Keychain-sourced secrets and WARN if .zdots.secrets still exists
- [ ] #6 No secret material appears in shell history, env exports to child processes are unchanged
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
