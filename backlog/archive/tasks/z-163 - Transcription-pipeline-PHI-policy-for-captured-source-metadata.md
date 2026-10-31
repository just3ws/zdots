---
id: Z-163
title: 'Transcription pipeline: PHI policy for captured source metadata'
status: Done
assignee: []
created_date: '2026-06-20 18:11'
updated_date: '2026-06-20 18:21'
labels:
  - transcription-pipeline
  - hitl
  - phi
dependencies: []
priority: high
ordinal: 54890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
HITL decision gate. Captured source metadata (yt-dlp info, filenames, paths) lands in the `my` DB and renders on my.local. On a PHI-adjacent machine this needs a policy before any code writes it.

Decide:
- Scrub-before-INSERT: source metadata passes the PHI Scrubber/pseudonymizer before persisting, keyed to the destination model (local vs shared/cloud).
- Whether `media_sources.title` / `source_snapshot` need encrypted-column treatment (like `lessons.content_enc`) for clinical sources — local file paths/filenames are themselves a PHI vector.

Output: a short written policy the AFK slices can implement against. No code in this task.

Part of the transcription-pipeline v1 cut line. Blocks the ingest slice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Written policy states whether/how source metadata is scrubbed before INSERT, keyed to destination
- [x] #2 Decision recorded on whether media_sources.title and source_snapshot require encrypted-column treatment for clinical sources
- [x] #3 Policy is concrete enough that the ingest slice can implement against it with no further questions
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
PHI POLICY — Captured Source Metadata (RATIFIED 2026-06-20)

Governing principle: keep patient-identifying data OUT of media_sources / source_snapshot entirely, rather than store-then-encrypt it. No PHI in the columns ⇒ no column-encryption needed; the dashboard renders only safe fields.

RISK TIERS (source-type-keyed, not uniform):
- PUBLIC (youtube/vimeo): metadata already public → store as-is.
- PRIVATE (local file, sharepoint): PHI-bearing (filename/path/embedded tags carry patient identifiers; Teams recordings are the live case).

RATIFIED DECISIONS:
D1 — Scrub-before-INSERT: YES, all sources, as a backstop. Free-text fields (title, description, snapshot raw) pass zdots-phi-scrub before persisting. Catches credentials/SSN/MRN/DOB. NOTE: scrubber has no name patterns (verified) — it fails open on names, so it is a backstop only, not the control for private sources.

D2 — PRIVATE sources store ONLY the non-PHI provenance set; identifying free-text is never persisted as plaintext:
  KEEP: sha256, byte_size, duration_sec, codec/resolution/fps, mtime/birthtime/embedded creation_time, host, + an operator-supplied non-PHI label (typed at ingest).
  DROP (not stored): absolute path, filename, embedded title tags, free-text description. source_snapshot.raw is filtered to the KEEP set before storage. Dashboard renders the operator label.

D3 — Encrypted columns: NOT in v1. D2 keeps PHI out of media_sources; FileVault (enforced by zdots-ctl check) covers at-rest. Defer content_enc-style treatment unless a real need to store raw clinical identifiers emerges. // ponytail: don't encrypt what you don't store; upgrade: add content_enc if D2 ever has to store raw clinical identifiers.

D4 — Destination keying: metadata policy is source-type-keyed (above). Transcript CONTENT scrubbing is destination-keyed and lives in Z-168 (scrub before ai-query); local stays on-box; name pseudonymization deferred until a shared/cloud destination is actually used.

IMPLEMENTED BY: Z-164 (ingest writes the KEEP set + label; public stores as-is), Z-168 (content scrub before AI).
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
- [x] #4 This is a no-code policy decision: the deliverable is the written policy recorded in the transcription-pipeline plan (or a doc). The default 'make check' and 'git clean' DoD items are N/A here.
<!-- DOD:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: claude
created: 2026-06-20 18:14
---
HITL gate. Done = a written PHI policy the AFK slices (Z-164, Z-168) implement against. No code in this task, so the default make-check/commit DoD items don't apply.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ratified PHI policy for captured source metadata. Core decision: PHI never enters media_sources/source_snapshot. Public sources (youtube/vimeo) stored as-is; private/clinical sources (local file, sharepoint) store only a technical fingerprint (sha256, duration, codec, timestamps) + an operator-supplied non-PHI label — raw filename/path/description are dropped, never persisted. A zdots-phi-scrub pass on all free-text is a backstop (note: it has no name patterns, so it is not the control for private sources — dropping the fields is). FileVault covers at-rest; no column encryption in v1. Implemented by Z-164 (ingest) and Z-168 (content scrub).
<!-- SECTION:FINAL_SUMMARY:END -->
