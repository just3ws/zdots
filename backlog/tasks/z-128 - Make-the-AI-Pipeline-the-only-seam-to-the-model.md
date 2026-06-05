---
id: Z-128
title: Make the AI Pipeline the only seam to the model
status: In Progress
assignee: []
created_date: '2026-06-05 19:58'
updated_date: '2026-06-05 20:06'
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
- [ ] #1 DocsSync routes inference through Zdots::AI::Pipeline, not client.chat
- [ ] #2 DocsSync reads decrypted content via the SessionResidue model, not raw bytea
- [ ] #3 No job bypasses the gate+scrub seam
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
