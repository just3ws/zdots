---
id: Z-129
title: Deepen Lesson intake behind one module
status: Done
assignee: []
created_date: '2026-06-05 19:58'
updated_date: '2026-06-15 13:07'
labels:
  - architecture
  - refactor
  - wave2
dependencies:
  - Z-135
priority: medium
ordinal: 20890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Architecture candidate #4 (Worth exploring). Lesson provenance is a convention re-invented at each creation site.

Files: sbin/zdots-brain:152,191,465 (add-lesson, save-capture, ingest), lib/zdots/jobs/distill.rb:31, lib/zdots/models/lesson.rb

Problem: Lesson.create at four sites with three source_trace_id conventions (bare trace_id, "ingest:<slug>", job.trace_id) and one with none. User-authored and AI-authored Lessons are indistinguishable. The model is a bare data holder; provenance rules live scattered in callers.

Solution: one Lesson intake module owns source_type and the trace-id convention; callers pass intent. Add a source_type discriminator (new term -> CONTEXT.md).

Wins: locality (provenance rule in one module), leverage (query user vs AI Lessons), interface-as-test-surface (one intake to assert).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A single Lesson intake path owns source_type and trace-id derivation
- [x] #2 All four creation sites go through it
- [x] #3 source_type is added to CONTEXT.md as a domain term
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New lib/zdots/models/lesson_intake.rb is the single Lesson intake: callers pass intent (source_type ∈ user|capture|ingest|distill); the module owns source_type assignment and derive_trace_id (user→nil, capture→bare trace_id, ingest→'ingest:<slug>', distill→job trace_id). All four Lesson.create sites routed through it: zdots-brain add-lesson/save-capture/ingest + jobs/distill.rb. Migration 20260615000000 adds source_type column + index (NULL-safe for pre-existing rows; PENDING application via 'zdots-ctx migrate'). CONTEXT.md gains 'Lesson source_type' as a domain term. spec/zdots/models/lesson_intake_spec.rb 13/0 on main. secret-scan OK. Commit 121d659. (sonnet worktree fan-out, diff-reviewed; same shape as Z-131.)
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
