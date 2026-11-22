---
id: Z-370
title: Document local model architecture and audited implementation
status: In Progress
assignee: []
created_date: '2026-11-22T23:22:04Z'
updated_date: '2026-11-22T23:56:11Z'
labels: []
dependencies: []
references:
  - docs/architecture-diagram-audit-plan.md
  - docs/local-ai.md
  - docs/llama-cpp.md
  - etc/ai-models.yaml
modified_files:
  - docs/local-model-architecture.md
  - docs/local-ai.md
  - docs/llama-cpp.md
  - docs/platform-map.md
  - README.md
ordinal: 247895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The local model audit currently lives in conversation and a temporary file. Future operators need a repository reference that explains model selection, runtime ownership, caller routing, and the evidence behind the machine's observed model inventory.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Repository documentation explains local model architecture and links implementation sources.
- [x] #2 The dated inventory distinguishes loaded, available, installed, and absent models and preserves exact file sizes and fingerprints.
- [x] #3 Documentation records audit limitations and the embedding context discrepancy.
- [x] #4 Existing documentation links readers to the reference and relevant documentation checks pass.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Trace model selection, Platform Service startup, prompt hygiene, caller routing, embedding use, and Apple/Whisper integration in current sources.
2. Add docs/local-model-architecture.md with stable architecture and implementation references plus a clearly dated 2026-11-22 model inventory, metadata, fingerprints, and limitations.
3. Link it from docs/local-ai.md, docs/llama-cpp.md, README.md, and docs/platform-map.md; correct adjacent stale draft/cache claims in the routing guide.
4. Review all changed documentation, check local links and audit values, and run the appropriate existing documentation validation. Preserve runtime configuration and Groma-owned files.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added docs/local-model-architecture.md and links from four existing references. Corrected stale routing-guide draft/cache/download claims and llama.cpp profile/server-default tables.

Local source links and all four exact filenames, file sizes, and SHA256 fingerprints match the prior audit. make docs-contract passed all 16 tests.

The new architecture diagram and all seven routing-guide diagrams rendered with mmdc using installed Google Chrome through a temporary Puppeteer configuration; the CLI's default bundled browser was absent.

Full make check is running. Groma-owned files were not edited; Groma reports ordinary docs are not covered by its enabled scanner.

Full make check exited 2; RTK summary reported 35 errors and 11 warnings but did not retain recoverable detail. Repeating with unfiltered output captured to /private/tmp/zdots-z370-check.log to identify failures. Documentation-specific checks, metadata/link checks, and all eight rendered diagrams passed.

Captured full-check failures: eight zdots_pages.bats tests fail because bin/zdots-pages is absent (exit 127); RBS coverage is 13.85% versus floor 14.06%; YARD coverage is 41.98% versus floor 43.26%. These failures concern unchanged publisher/library surfaces. Full output: /private/tmp/zdots-z370-check.log. No infrastructure fixes attempted. All documentation acceptance criteria are verified; task remains In Progress because the full-check Definition of Done gate has not passed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added docs/local-model-architecture.md with a Mermaid runtime map, source-linked implementation responsibilities, profile and lifecycle rules, caller paths, integrity semantics, exact dated model inventory and SHA256 fingerprints, and audit limits. Linked it from README, platform map, routing guide, and llama.cpp reference; corrected adjacent stale model/default/draft/cache claims. Documentation contract: 16/16 passed; all eight affected diagrams rendered; link, size, filename, fingerprint and diff-whitespace checks passed. Full make check failed on the absent zdots-pages executable and RBS/YARD coverage floors, recorded in Z-371. No runtime or library implementation changed. Z-370 remains In Progress pending the full-check gate.
<!-- SECTION:FINAL_SUMMARY:END -->
