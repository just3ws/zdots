---
id: Z-280
title: >-
  worker boots crash-loop when a new-table migration is pending — Sequel models
  query schema at require time
status: To Do
assignee: []
created_date: '2026-08-01 16:21'
labels:
  - agent-reported
dependencies: []
priority: medium
ordinal: 156895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Jul 28 flap root cause (diagnosed 2026-08-01): all 17 models in lib/zdots/models/ use Sequel::Model(Zdots.db[:table]), which SELECTs the table at class-definition time; sbin/zdots-brain:47 requires them at boot. bus_participants (28ce34648, model+migration same commit) hit disk before zdots-ctx migrate ran -> 32 consecutive boot crashes under KeepAlive until migrate landed; 'last exit code 1' warn is the fossil. Crash is pre-init_otel so dashboards were structurally blind (Z-229 echo) — only launchd saw it; zdots-doctor flap check now covers this class.

Fix options (either/both, two one-liners):
1. Sequel::Model.require_valid_table = false in lib/zdots/db.rb — missing table errors at first use inside the per-job rescue instead of killing boot.
2. cmd_worker boot guard: pending migrations -> print 'pending migrations — run zdots-ctx migrate' and exit with a distinct code the flap check can name.
Procedural: migrate BEFORE worker restart (/zdots-update ordering was bypassed on Jul 28).

Current state verified: worker pid up 3d15h, queue 0 pending/failed, 716 completed, 26 historical dead, o2 clean 24h. Will recur structurally on any future new-table migration + early restart.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
