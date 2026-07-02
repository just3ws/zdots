---
id: Z-101
title: >-
  DB column encryption via pgcrypto — at-rest protection for all sensitive
  tables
status: Done
assignee: []
created_date: '2026-05-23 21:41'
updated_date: '2026-06-29 16:55'
labels:
  - phi-safe
  - security
  - wave4
milestone: m-5
dependencies:
  - Z-095
modified_files:
  - db/migrations/20260629000000_encrypt_remaining_phi_columns.rb
  - lib/zdots/models/lesson.rb
  - lib/zdots/models/source_document.rb
  - sbin/zdots-brain
priority: medium
ordinal: 880
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lessons, methodologies, and session_residue already encrypt content columns via `pgp_sym_encrypt`. This task extends coverage to any remaining unencrypted sensitive columns and adds a migration to ensure the schema is consistent. Depends on Z-095 (Keychain) because the encryption key must come from Keychain, not a file, before this is meaningful on a work machine.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Audit of all tables in the `my` database: document which columns contain potentially sensitive content
- [x] #2 Any unencrypted sensitive columns added to the EncryptedContent concern (or justified as safe in writing)
- [x] #3 Migration adds `_enc` column variants for any newly encrypted fields
- [x] #4 zdots-brain status reports encryption coverage summary
- [x] #5 All existing rows migrated via `zdots-brain rekey` if any column is newly encrypted
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Committed 49018e4. Migration 20260629000000 encrypts lessons.context → context_enc and source_document.body_md → body_md_enc (3 + 2 rows migrated). Models updated. zdots-brain status now reports 8 encrypted columns; rekey extended to cover all 4 tables via REKEY_TABLES. 731/731 tests pass.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
