---
id: Z-010
title: Enhance Documentation with Meta-Discovery and Wiki Structure
status: Done
assignee: []
created_date: '2026-03-27 16:18'
updated_date: '2026-04-15 11:51'
labels: []
milestone: m-2
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Restructure documentation into a Wiki-style format with YAML frontmatter for meta-discovery. Ensure diagrams are prominently displayed on the README and cross-link all reference documents (POSIX, XDG, Zsh/Bash manuals).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Add YAML frontmatter to all .md files
- [x] #2 Move architecture diagrams to README.md
- [x] #3 Create docs/references.md with links to POSIX, XDG, and Shell manuals
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Wiki structure established with YAML frontmatter. README restructured with sequence diagrams.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All docs now have YAML frontmatter. 6 files added post-task-creation lacked it: llama-cpp.md, otel-collector-guide.md, startup-performance-budget.md, storage-hygiene.md, terminal-capabilities.md, zsh-quality-rubric.md. All 10 docs/*.md files now have id/title/purpose/links frontmatter. docs/references.md already existed (AC #3). README had frontmatter and diagrams (ACs #1/#2 previously completed).
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
