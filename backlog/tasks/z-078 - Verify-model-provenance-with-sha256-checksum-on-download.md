---
id: Z-078
title: Verify model provenance with sha256 checksum on download
status: Done
assignee: []
created_date: '2026-05-22 23:47'
updated_date: '2026-05-23 06:39'
labels:
  - phi
  - security
  - llama-cpp
milestone: m-5
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
llama-ctl model-download currently pulls the model with no integrity check. On a regulated machine, the model running inference must be verifiably the expected artifact — not a tampered version from a CDN or mirror. Add a sha256 manifest checked against the downloaded file. Refuse to start llama-server with an unverified model file. The manifest lives in the repo (tracked) so the expected hash is auditable.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 bin/llama-ctl model-download computes sha256 of the downloaded model and compares against a tracked manifest file
- [ ] #2 Mismatch causes a hard exit with a clear error — model file is NOT used
- [ ] #3 Manifest file is tracked in git at a well-known path (e.g. lib/llama-models.sha256)
- [ ] #4 llama-ctl start checks the model file hash before launching llama-server; refuses to start if unverified
- [ ] #5 Re-running model-download after a verified download is a no-op (idempotent)
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
lib/llama-models.sha256 manifest created with SHA256 for qwen2.5-coder-7b-instruct-q4_k_m.gguf. zdots_model_verify() added to lib/model-store.bash — hard-fails on mismatch, no-op if file not in manifest. llama-ctl model-download verifies after download (idempotent: skip if already downloaded). llama-ctl start verifies before launch. llama-ctl model-verify subcommand for manual checks. zdots-ctl check verifies all manifest entries.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
