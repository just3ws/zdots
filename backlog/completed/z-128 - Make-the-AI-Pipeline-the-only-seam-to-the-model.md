---
id: Z-128
title: Make the AI Pipeline the only seam to the model
status: Done
assignee: []
created_date: '2026-06-05 19:58'
updated_date: '2026-06-05 21:07'
labels:
  - architecture
  - refactor
  - security
dependencies: []
priority: high
ordinal: 19890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Architecture candidate #3 (Strong). Two adapters reach the model: the deep Pipeline (gate -> scrub -> infer) and a raw client.chat in DocsSync that skips both.

Files: lib/zdots/ai/pipeline.rb, lib/zdots/jobs/docs_sync.rb, lib/zdots/ai/client.rb

Problem: docs_sync.rb:21 reads session_residue raw (no decrypt) and :41 calls Zdots::AI.client.chat directly — bypassing the locality gate AND PHI scrub. Ciphertext (raw bytea) flows to the model, and the new PHI suppress fail-hard (this session) does not protect this path. A scrub-bypass hole, not just duplication.

Solution: Pipeline is the only seam to inference; jobs read through models (decrypt), never raw datasets, never the client directly. Route DocsSync through Pipeline.call.

Wins: closes the scrub-bypass leak, leverage (gate+scrub for every job free), locality (one place inference can fail), interface-as-test-surface (one Pipeline to fake).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 DocsSync routes inference through Zdots::AI::Pipeline, not client.chat
- [x] #2 DocsSync reads decrypted content via the SessionResidue model, not raw bytea
- [x] #3 No job bypasses the gate+scrub seam
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
docs_sync.rb now reads via Zdots::Models::SessionResidue (decrypted .summary/.result, not raw bytea keys which were the wrong column names → empty strings) and routes inference through Zdots::AI::Pipeline.call (gate → PHI scrub → infer), matching Distill. Per-document decision extracted to #sync_document (DB-free, unit-tested).

Evidence:
- AC1/AC3: grep -rnE 'AI\.client|client\.chat' lib/zdots/jobs/ → no matches (no job bypasses the seam).
- AC2: SessionResidue.where(trace_id:).first + .summary/.result decrypt via EncryptedContent.
- spec/zdots/jobs/docs_sync_spec.rb 5/5; full rspec 157 examples, 0 failures.
- make check exit=0 (480 bats tests pass). Two unrelated pre-existing bats breakages fixed in a separate commit: zdots-worker stub omission (fallout from the worker Platform Service) and update-local phase-number drift (06/11 → 07/12 after fabric/12th phase added).

Commits: fa5acc6 (refactor), 425d91b (test fixes). Merged to main.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
DocsSync routed through the Pipeline seam; no job calls AI.client. Closed a scrub/gate bypass and a latent empty-prompt bug (raw :summary/:result keys). make check green.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
