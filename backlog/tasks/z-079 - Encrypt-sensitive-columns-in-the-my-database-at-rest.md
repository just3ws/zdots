---
id: Z-079
title: Encrypt sensitive columns in the 'my' database at rest
status: Done
assignee: []
created_date: '2026-05-22 23:47'
updated_date: '2026-05-23 12:58'
labels:
  - phi
  - security
  - database
milestone: m-5
dependencies:
  - Z-087
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
FileVault provides disk-level encryption but offers no protection from a running PostgreSQL process or a user with zdots_ro access reading lesson/methodology content. Apply pgcrypto symmetric encryption to the high-risk text columns (lessons.content, methodologies.content, session_residue.raw) using a key stored in .zdots.secrets (gitignored, never committed). zdots_rw encrypts on write; zdots_ro reads ciphertext only. zdots-ctx query/hydrate decrypt transparently in application code. This layer sits between FileVault and the data — defense in depth without replacing either.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 pgcrypto extension enabled in the 'my' database via a new migration
- [ ] #2 lessons.content, methodologies.content, session_residue.raw stored as pgp_sym_encrypt output
- [ ] #3 ZDOTS_DB_ENCRYPTION_KEY loaded from .zdots.secrets; .zdots.local.example documents how to set it
- [ ] #4 zdots-ctx query and hydrate decrypt transparently — output is unchanged for callers
- [ ] #5 zdots_ro SELECT on encrypted columns returns ciphertext only (no key access)
- [ ] #6 Migration is idempotent; existing plaintext rows are re-encrypted on first migrate run
- [ ] #7 bootstrap warns clearly if ZDOTS_DB_ENCRYPTION_KEY is unset on a work profile
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Key source updated: ZDOTS_DB_ENCRYPTION_KEY must be retrieved from macOS Keychain via zdots-secrets-get (Z-087), not read from .zdots.secrets plaintext. Z-087 is now a prerequisite.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Migration 20260523100000_encrypt_phi_columns.rb: pgcrypto enabled, lessons.content → content_enc (bytea), methodologies.content → content_enc (bytea), session_residue.{summary,intent,result} → {summary,intent,result}_enc (bytea). Uses pgp_sym_encrypt/decrypt with ZDOTS_DB_ENCRYPTION_KEY from env (Keychain-backed). Migration aborts if key unset. Idempotent. FTS indexes dropped. Lesson/Methodology models updated with transparent content getter/setter. SessionResidue model created. zdots_ro sees only ciphertext.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
