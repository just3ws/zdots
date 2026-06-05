---
id: Z-129
title: Deepen Lesson intake behind one module
status: To Do
assignee: []
created_date: '2026-06-05 19:58'
labels:
  - architecture
  - refactor
dependencies: []
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
- [ ] #1 A single Lesson intake path owns source_type and trace-id derivation
- [ ] #2 All four creation sites go through it
- [ ] #3 source_type is added to CONTEXT.md as a domain term
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
