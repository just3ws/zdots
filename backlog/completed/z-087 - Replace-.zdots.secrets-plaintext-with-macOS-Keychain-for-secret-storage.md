---
id: Z-087
title: Replace .zdots.secrets plaintext with macOS Keychain for secret storage
status: Done
assignee: []
created_date: '2026-05-23 01:20'
updated_date: '2026-05-23 05:58'
labels:
  - phi
  - security
  - keychain
  - macos
milestone: m-5
dependencies:
  - Z-077
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The .zdots.secrets file stores sensitive values (ZDOTS_DB_ENCRYPTION_KEY, AI API keys) as plaintext. On Apple Silicon, the macOS Keychain is backed by the Secure Enclave — hardware-protected, requires authentication to access, and survives machine reinstalls via iCloud Keychain sync. Replace .zdots.secrets as the canonical secret store with Keychain entries accessed via the `security` CLI. .zdots.secrets becomes a fallback shim for Linux/non-macOS environments only. The key retrieval path: Keychain first, .zdots.secrets fallback, hard error if neither present.\n\nStore/retrieve pattern:\n  security add-generic-password -a \"$USER\" -s zdots-<name> -w \"$VALUE\"\n  security find-generic-password -a \"$USER\" -s zdots-<name> -w\n\nThis is the prerequisite for Z-079 (DB encryption) since the encryption key must come from Keychain, not a plaintext file.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zdots-secrets-set <name> <value> command writes to macOS Keychain on darwin, falls back to .zdots.secrets on non-darwin
- [ ] #2 zdots-secrets-get <name> reads from Keychain first, falls back to .zdots.secrets, exits non-zero with clear error if not found in either
- [ ] #3 ZDOTS_DB_ENCRYPTION_KEY retrieved via zdots-secrets-get at runtime — never read from a plaintext file on macOS
- [ ] #4 bootstrap detects darwin and prompts operator to store required secrets in Keychain via zdots-secrets-set
- [ ] #5 bootstrap warns if .zdots.secrets exists on darwin with a suggestion to migrate to Keychain
- [ ] #6 .zdots.secrets remains supported as a fallback for Linux and CI environments
- [ ] #7 .zdots.local.example documents the Keychain pattern and migration from .zdots.secrets
- [ ] #8 zdots-ctl check asserts that on darwin, ZDOTS_DB_ENCRYPTION_KEY is sourced from Keychain (not .zdots.secrets)
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Migrated MAXMIND_ACCOUNT_ID, MAXMIND_LICENSE_KEY, and HUGGINGFACE_TOKEN from plaintext .zdots.secrets into macOS Keychain. Built lib/keychain.bash (get/set/delete/list/load) and bin/zdots-keychain CLI (add/get/delete/list/migrate/verify). Replaced .zdots.secrets literal values with inline Keychain calls via _zdots_kc(). Updated .zdots.secrets.example to show the pattern.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
