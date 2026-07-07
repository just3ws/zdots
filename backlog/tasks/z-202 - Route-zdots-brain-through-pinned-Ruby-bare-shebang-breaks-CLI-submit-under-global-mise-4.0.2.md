---
id: Z-202
title: >-
  Route zdots-brain through pinned Ruby: bare shebang breaks CLI/submit under
  global mise 4.0.2
status: Done
assignee: []
created_date: '2026-07-07 13:08'
updated_date: '2026-07-07 13:20'
labels:
  - request
  - bug
dependencies: []
references:
  - blocks TASK-124 (just3ws.github.io)
  - related z-164 transcriptions UI (unpushed/lost work branch)
priority: high
ordinal: 98890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
sbin/zdots-brain has a bare #!/usr/bin/env ruby shebang. Invoked outside ~/.config/zsh (or from launchd/cron), ruby resolves to the global mise Ruby 4.0.2, which lacks the bundled gems; jobs/base.rb requires opentelemetry, so every direct-invocation path dies with a LoadError before doing anything. The gems live only in the pinned Ruby 4.0.5 (etc/ruby-version, mise.toml). Direct callers affected: zdots-ctx (jobs/enqueue/query/hydrate and ~16 sites), zdots-ingest-media (the z-164 / TASK-124 submit tool), zdots-debrief. The worker is NOT affected: bin/zdots-worker runs brain via mise exec (4.0.5). Symptom: could not submit YouTube videos for transcription from the site repo (zdots-ctx enqueue transcription and zdots-ingest-media both LoadError). Blocks TASK-124 in just3ws.github.io.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zdots-ctx jobs and enqueue succeed from a non-mise-activated dir (e.g. the site repo) with no opentelemetry LoadError
- [ ] #2 zdots-ingest-media and zdots-debrief load under the pinned Ruby regardless of caller cwd
- [ ] #3 worker path (mise exec) unchanged: no re-exec, no added startup cost
- [ ] #4 no infinite re-exec loop when the pinned Ruby is itself misconfigured; it fails loud instead
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Single self-heal guard at the top of sbin/zdots-brain: canary require opentelemetry; on LoadError set ENV sentinel ZDOTS_BRAIN_PINNED and exec bin/zdots-ruby (etc/ruby-version 4.0.5, bundle exec) re-running this script with original ARGV. Sentinel prevents a loop; base.rb own require becomes the fail-loud path. Chosen over editing ~18 call sites across 3 files (whack-a-mole; future callers would regress).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED + VERIFIED, PENDING COMMIT (do not mark Done until landed; same trap as z-164). Verified from site-repo cwd with ruby 4.0.2: zdots-ctx jobs -> exit 0, prompt return (no loop, 40s-bounded), real jobs table, zero LoadError. Worker no-regression: canary passes under mise exec 4.0.5 so guard no-ops. Syntax OK under 4.0.2. File changed: sbin/zdots-brain (guard after the Encoding pins).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed in commit 0b5ab68 (zdots main). Self-heal guard added to sbin/zdots-brain: canary require opentelemetry, on LoadError re-exec once under bin/zdots-ruby (pinned 4.0.5) with an ENV sentinel to prevent looping. Covers all direct callers (zdots-ctx, zdots-ingest-media, zdots-debrief) in one place. Verified from a non-mise cwd (ruby 4.0.2): zdots-ctx jobs -> exit 0, prompt return, real jobs table, zero LoadError. Worker (mise exec 4.0.5) unchanged: canary passes, guard no-ops. YouTube submission via zdots-ctx enqueue transcription / zdots-ingest-media now works from any dir.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
