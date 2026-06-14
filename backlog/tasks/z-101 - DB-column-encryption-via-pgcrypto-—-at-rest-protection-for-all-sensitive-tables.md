---
id: Z-101
title: >-
  DB column encryption via pgcrypto — at-rest protection for all sensitive
  tables
status: To Do
assignee: []
created_date: '2026-05-23 21:41'
updated_date: '2026-06-14 18:37'
labels:
  - phi-safe
  - security
  - wave4
milestone: m-5
dependencies:
  - Z-095
modified_files:
  - db/migrations/
  - lib/zdots/models/
priority: medium
ordinal: 880
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lessons, methodologies, and session_residue already encrypt content columns via `pgp_sym_encrypt`. This task extends coverage to any remaining unencrypted sensitive columns and adds a migration to ensure the schema is consistent. Depends on Z-095 (Keychain) because the encryption key must come from Keychain, not a file, before this is meaningful on a work machine.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Audit of all tables in the `my` database: document which columns contain potentially sensitive content
- [ ] #2 Any unencrypted sensitive columns added to the EncryptedContent concern (or justified as safe in writing)
- [ ] #3 Migration adds `_enc` column variants for any newly encrypted fields
- [ ] #4 zdots-brain status reports encryption coverage summary
- [ ] #5 All existing rows migrated via `zdots-brain rekey` if any column is newly encrypted
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
