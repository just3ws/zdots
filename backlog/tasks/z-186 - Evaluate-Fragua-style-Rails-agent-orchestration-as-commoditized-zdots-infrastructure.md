---
id: Z-186
title: >-
  Evaluate Fragua-style Rails agent-orchestration as commoditized zdots
  infrastructure
status: To Do
assignee: []
created_date: '2026-07-01 13:27'
labels:
  - research
  - agent-ready
dependencies: []
references:
  - 'https://fragua.app/en'
priority: medium
ordinal: 82890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Review https://fragua.app/en and evaluate how its feature set could be implemented within this system's Rails infrastructure (context-engine) and commoditized as reusable infrastructure for other Rails apps on the zdots platform.

## What Fragua is
An AI-agent orchestrator specialized for Rails 8.x development. Feature set (from landing page 2026-07-01):
- Foundation: scaffold new Rails apps (maquina generators); analyze existing codebases to learn conventions; init a configured working tree.
- Spec: guided interview turning a feature idea into a reviewable spec; decompose into task list; accept attachments (PDF/MD/HTML/images) + knowledge-base files as context.
- Execute: autonomous agent implements on a feature branch; live work streaming; auto PR creation; real-time task tracking.
- Capabilities: code read/write + test execution (Minitest), per-feature git worktrees for parallel dev, native GitHub integration, bash execution.
- Observability/mgmt: live run timelines with step logs, token usage roll-ups (per-workspace/monthly), full agent audit trail, RBAC (admin/member), shared team workspaces.
- Infra/security: runs on the user's host (never proxied), passwordless email-code auth, BYOK billing direct to the AI provider, code+credentials stay on host.
- Stack: Rails 8.1, SQLite+WAL, Solid Queue, Hotwire (Turbo+Stimulus), gh CLI.

## Why this matters to zdots
zdots already owns much of this substrate for Claude Code: agent orchestration, git worktrees (Agent isolation), Workflow fan-out, token/cost tracking (ccusage), OTel run timelines/audit, local-AI boundary, and a Rails consumer (context-engine). The question is not 'clone Fragua' but: which of these capabilities are already latent in the platform, and what is the thin Rails-facing layer that packages them so ANY Rails app on the platform gets spec->execute->PR orchestration, run observability, and cost roll-ups for free.

## Task
1. Extract Fragua's capability list into a feature matrix; mark each: (a) already provided by zdots (name the tool/seam), (b) provided but not yet Rails-facing, (c) genuinely new.
2. For (b)/(c), sketch the commoditization surface: a mountable Rails engine / gem / generator vs. a set of zdots CLIs the app shells out to. Prefer the platform-service seam (per the work-tenant service-surface work, Z-184/Z-185) over per-app reimplementation.
3. Map onto context-engine as the reference consumer; identify what it would expose to other Rails apps.
4. Flag PHI/security constraints: on this platform AI is local-only + PHI-gated, unlike Fragua's BYOK-cloud model. Note where the models diverge.
5. Output: recommendation (build / partially adopt / watch), a phased slice if build, and any new backlog tickets it spawns.

Evaluation/research task — no implementation. Do not change context-engine or fragua.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Fragua feature matrix produced, each tagged already-in-zdots / not-yet-Rails-facing / new
- [ ] #2 Commoditization surface proposed (engine/gem/generator vs zdots CLI seam), aligned with the platform service-surface direction (Z-184/Z-185)
- [ ] #3 context-engine mapped as reference consumer; cross-app exposure identified
- [ ] #4 Local-only/PHI vs Fragua BYOK-cloud divergence documented
- [ ] #5 Build/adopt/watch recommendation with phased slice + spawned tickets
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
