# Audit: Backlog
Generated: 2026-06-13
Agent: main-session

---

## Structure

```
backlog/
  Backlog.md           — index/overview
  tasks/               — open tasks (59 files)
  completed/           — closed tasks (large, not counted)
  archive/             — archived tasks + milestones
```

---

## Critical Finding: Done Tasks Not Moved to completed/

**30 tasks** in `backlog/tasks/` have `status: Done` but have not been moved to `backlog/completed/`.

This is the single largest hygiene issue in the backlog. Done tasks in `tasks/` pollute the active backlog, inflate counts, and make the true "open work" set hard to see.

| ID | Summary |
|----|---------|
| Z-010 | Enhance Documentation with Meta-Discovery and Wiki Structure |
| Z-025 | Automate AI Model Hydration Smart-Pull |
| Z-030 | Fix OTel Collector connection to Colima Docker socket |
| Z-031 | Optimize shell performance by eliminating redundant forking |
| Z-032 | Optimize llama.cpp for performance and limited primary storage |
| Z-042 | Implement Platform Metadata Service |
| Z-043 | Refactor AI Stack for Unified Metadata |
| Z-044 | Implement Shared Lifecycle Primitives |
| Z-048 | Implement declarative service lifecycle module |
| Z-049 | Unify configuration registry and service metadata |
| Z-050 | Enforce opaque service control seam in orchestrator |
| Z-051 | Unified model asset management module |
| Z-076 | Refactor dependencies and module loading for Zdots |
| Z-078 | Verify model provenance with sha256 checksum on download |
| Z-079 | Encrypt sensitive columns in the my database at rest |
| Z-086 | Seed PHI safety policy into local knowledge base |
| Z-088 | Sandbox llama-server to loopback-only network |
| Z-089 | Emit PHI-adjacent operations to macOS Unified Logging |
| Z-090 | Assert macOS Application Firewall is enabled in zdots-ctl check |
| Z-091 | Assert SIP and FileVault status in zdots-ctl check |
| Z-097 | ZDOTS_CAPTURE_ENABLED gate — hard disable on PHI machines |
| Z-098 | Work-machine profile defaults — safe by default |
| Z-100 | Application Firewall assertion in zdots-ctl check |
| Z-112 | zdots-ctl status fails with syntax error near fi (line 451) |
| Z-113 | zdots-ctl status fails with syntax error near unexpected token fi (line 451) |
| Z-115 | zdash --help emits _cmd_list:12 read-only variable error |
| Z-116 | zdots-ask --help prints usage but exits 2 |
| Z-117 | make test fails — DB skip, Unified Log assertions |
| Z-120 | zdots-ctl up times out waiting for AI server health |
| Z-128 | Make the AI Pipeline the only seam to the model |

**Recommended action:** `close_backlog_task` (move all 30 to `backlog/completed/`). Low risk, high confidence.

---

## Duplicate Tasks

### Z-112 and Z-113 — DUPLICATE
Both describe the same bug: `zdots-ctl status` fails with a syntax error near `fi` at `bin/zdots-ctl line 451`.

- Z-112: "syntax error near fi"
- Z-113: "syntax error near unexpected token fi"

Both have `status: Done`. The bug was filed twice by different agent sessions. Both should be closed. One should be archived as a duplicate.

**Recommended action:** `close_backlog_task` for both + note Z-113 as duplicate of Z-112.

---

## Z-115 and Z-116 Verification

### Z-115 — zdash --help
- Task status: **Done**
- Commit 85d4713 "feat(dev): build docs contract, harden test suite, and standardize CLI/Ruby internals" fixes zdash --help behavior
- Finding: VERIFIED DONE. Move to completed/.

### Z-116 — zdots-ask --help
- Task status: **Done**
- Same commit (85d4713) fixes zdots-ask --help exit code
- Finding: VERIFIED DONE. Move to completed/.

---

## Open Tasks Count

Tasks in `backlog/tasks/` NOT marked Done: ~29 open tasks (59 total minus 30 Done).

Notable open tasks by category:

**PHI / Security (some Done, some open):**
- Z-079 (DB encryption) — Done
- Z-095 (Replace .zdots.secrets with Keychain) — open
- Z-096 (zshaddhistory PHI redaction hook) — open
- Z-099 (SIP/FileVault in zdots-ctl check) — open
- Z-101 (DB column encryption via pgcrypto) — open
- Z-102 (sandbox-exec for llama-server) — open

**Architecture / Deepening:**
- Z-127 (Collapse Platform Service into one deep module) — open
- Z-129 (Deepen Lesson intake behind one module) — open
- Z-130 (Shrink AI Invocation Interface) — open
- Z-131 (Narrow Searchable drop-dead semantic branch) — open

**zsynod (all open):**
- Z-136, Z-137, Z-138, Z-142, Z-143, Z-144

**Docs / Tooling:**
- Z-119 (Fix help exit codes + docs contract coverage) — status unknown, linked from known-gaps file

**MCP:**
- Z-132 (Evaluate sequential-thinking MCP) — open
- Z-139 (cc-doctor: validate .mcp.json commands resolve) — open

**Agent issues (open):**
- Z-103 (cognitive load detection) — open
- Z-118 (rtk git diff pathspec) — open
- Z-124 (docs interface drift) — open
- Z-125 (ztask done ignores ZDOTS_AI_MODE=none) — open
- Z-126 (bench module profiling — operation not permitted) — open
- Z-133 (Adopt promptfoo for local model evals) — open
- Z-135 (Runtime insight feedback loop) — open
- Z-140 (zsvc status embed false negative) — open
- Z-141 (zdots-gh auth precheck failure) — open
- Z-145 (zdots-doctor Colima legacy path) — open
- Z-146 (zdots-heal otel-collector 608M log) — open
- Z-147 (zdots-heal orphan scanner regex too broad) — open

---

## Backlog Docs

`backlog/Backlog.md` — index file.
`backlog/docs/` not present (docs/ is separate at repo root).

PHI safety policy: `backlog/docs/doc-002 - PHI-Safety-Policy.md` referenced in AGENTS.md — need to verify this exists.

---

## Recommendations

| Finding | Action | Confidence | Risk |
|---------|--------|------------|------|
| 30 Done tasks in tasks/ | close_backlog_task (move to completed/) | high | low |
| Z-112 + Z-113 duplicate | close_backlog_task both, note duplicate | high | low |
| Z-115 verified Done | close_backlog_task | high | low |
| Z-116 verified Done | close_backlog_task | high | low |
| PHI tasks Z-095 to Z-102 (open) | keep — active security work | high | high if dropped |
| zsynod tasks (Z-136 to Z-144) | keep — active work | high | low |
| Z-119 (known-gaps driver) | needs_human_review — check status | medium | medium |
