---
id: Z-262
title: 'Work-extension layer: extract tenant (Work) concerns from platform repos'
status: To Do
assignee: []
created_date: '2026-07-28 17:43'
labels:
  - agent-reported
dependencies: []
priority: high
ordinal: 138895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Operator directive (2026-07-28):** all Work concerns move out of zdots/adots/my purview into a 'work' extension — a layer that is loaded by the platform but whose content and history ride outside the four platform repos. 'work' is a placeholder for whatever employer the platform is deployed onto.

## Coupling map (full scan 2026-07-28, all four repos)

**Real content requiring extraction:**
1. `etc/phi-patterns.yaml` — `url_path_client_id` structural rule embeds Work's production route inventory (12 exempt path prefixes, routes.rb line citations, app.work.com probe URL, service.name work3 probes). CONFLICT: AGENTS.md §10 hard rule says phi-patterns.yaml is the ONLY pattern source — extraction needs an overlay contract change (`etc/phi-patterns.d/*.yaml` union at compile, or ZDOTS_PHI_PATTERNS_EXTRA), operator sign-off + /docs-sync required.
2. `etc/otel-collector.yaml` — `resource/work3logs` processor, work3 CORS origins (staging.work.localhost etc.). Pattern to copy: ZDOTS_APP_LOG in bin/otel-collector is already correctly abstracted (ZDOTS_APP_SERVICE_NAME + ZDOTS_OTEL_EXTRA_ORIGINS).
3. ~~conf.d/71-shell-tools.zsh `kubens work-dev`~~ — DONE 2026-07-28: gated behind ZDOTS_K8S_DEFAULT_NS in .zdots.local.

**Comment/doc mentions (swap to <tenant>/${ZDOTS_TENANT}, no mechanism):** bin/nginx-ctl:30, bin/zdots-ctl:561, bin/nginx-regen-certs:36, etc/nginx/servers/00-default.conf:4, bin/zdots-snapshot:6, bin/colima-autostart:26, bin/zdots-gh:465, bin/agent-guide:630, .claude/commands/cc-audit.md:85, analysis-assets/graphify/*.md (5 files — or move whole dir to work layer).

**Already clean (leave alone):** .zdots.work, Brewfile.work, all ZDOTS_CONTEXT=home|work branching, work.github.com aliasing, PHI docs, adots (zero tracked hits), vdots (zero hits), my vaults.

## Recommended architecture

A dedicated plain repo `~/.config/zdots-work/` (NOT a git submodule — a submodule writes the work repo's URL+SHA into platform history via gitlink/.gitmodules, exactly what must not ride along). Its own history, own remote (work GitHub), employer-owned.

Loader seam: `.zdots.local` (already gitignored, already the machine-local layer) sets `ZDOTS_WORK_EXT=~/.config/zdots-work`; zdots sources `$ZDOTS_WORK_EXT/init.zsh` if present and unions `$ZDOTS_WORK_EXT/phi-patterns.d/` + otel fragment at compile time. work.localhost nginx vhost already lives untracked in etc/nginx/servers/ — same pattern, formalized.

Result: platform repos are employer-agnostic; the work extension is tracked in its own history; a new employer = new zdots-work repo, zero platform edits.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
