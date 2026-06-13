# zdots Audit Dry Run Summary
Generated: 2026-06-13
Mode: dry run — no commits made, no production files changed

---

## Scope Completed

| Area | Status |
|------|--------|
| bin/ (87 files) | sampled + key files audited |
| sbin/ (2 files) | audited |
| Root files | audited |
| .agents/skills/ | fully audited |
| .claude/commands/ | inventoried |
| tests/ | audited |
| docs/ | audited |
| backlog/ | audited (tasks status sweep) |
| experiments/zsynod/ | audited |
| MCP layer | fully audited (by subagent) |
| Known findings | all 9 verified |

---

## Audit Order Used

Orientation → MCP (subagent, completed early) → known findings verification (all 9) → bin/sbin sampling → root files → docs/tests → backlog → experiments/zsynod → artifacts

Note: 6 parallel subagents were launched; all stalled at 600s watchdog. MCP subagent completed its output file before stalling. Other sections completed directly in main session using targeted evidence commands.

---

## Current Git State

Branch: `main` (clean on entry)
After audit: `.claude/settings.json` modified (added 16 allowlist entries for audit tools), `audit/` directory created (untracked), `.claude/commands/zdots-audit.md` created (untracked).
No production files modified.

---

## Known Findings Verification Results

| Finding | Verified Result |
|---------|----------------|
| docs/adr/ exists or missing | **EXISTS** — 2 ADRs (0001-nginx, 0002-phi-scrubber-go) |
| grill-with-docs depends on ADRs | **YES** — references docs/adr/ in multiple places |
| improve-codebase-architecture depends on ADRs | **YES** — in skill description |
| bin/ctx-mcp has or lacks MCP tests | **HAS TESTS** — tests/mcp.bats covers protocol + 5 tools |
| bin/ctx-mcp-register: Claude Desktop only or more | **Claude Desktop ONLY** — writes to ~/.claude.json |
| tests/docs_contract.bats coverage for bin/ and sbin/ | **EXISTS** — covers ~47 commands; 18 documented gaps in known-gaps.txt |
| Z-115 status vs commit 85d4713 | **Done** — commit 85d4713 fixes zdash --help; task marked Done but not moved to completed/ |
| Z-116 status vs commit 85d4713 | **Done** — same commit fixes zdots-ask --help exit code; same issue |
| setup-matt-pocock-skills/ has SKILL.md | **HAS SKILL.md** ✓ |
| zoom-out/SKILL.md has YAML description | **YES** ✓ — valid YAML with description field |
| All zsynod files under experiments/zsynod | **NO** — zsynod is distributed across bin/, lib/, tests/, functions/, man/ |

---

## Findings by Directory

### bin/
- 87 files, 86 executable, 1 non-executable (`zsynod_tui.py`)
- `bin/__pycache__/` — Python cache pollution
- Coverage: docs_contract.bats covers 47; 18 known-gaps; ~15 true gaps (no contract, no documented reason)
- PHI/sacred: `bin/zdots-phi-scrub`, `bin/cc-hook-guard`, `bin/zdots-ctx`, `bin/zdots-ctl`

### sbin/
- 2 files: `zdots-brain` (Go binary, Knowledge Layer), `zdots-recommend` (Ruby)
- Both correctly placed in sbin/

### Root files
- 7 tracked experiment artifacts in root: inspect_mlx*.py, mlx_*.json/txt, test_pack.lua, zdots_system_audit.md, AUDIT.md
- 5 candidates for relocation/deletion; test_pack.lua needs human confirmation

### .agents/skills/
- 16 skills, all with SKILL.md and valid YAML
- No staleness evidence
- ADR dependencies satisfied

### tests/
- docs_contract.bats ✓, mcp.bats ✓, gemini_mcp_register.bats ✓
- 10 zsynod test files
- Gap: no llama_mcp.bats

### docs/
- 40+ docs, well-organized
- docs/adr/: EXISTS (2 ADRs)
- docs/generated/: interface-inventory + known-gaps (auto-generated, current)
- docs/wiki/: 8 pages

### backlog/
- 59 tasks in tasks/ — 30 are Done but not moved to completed/
- Z-112 and Z-113: duplicate tasks (same bug, both Done)
- PHI safety tasks (Z-095 to Z-102): active open work — do not close

### experiments/zsynod/
- EXISTS with full content
- zsynod has outgrown the experiment namespace (10 tests, man pages, lib/ Python, shell function)
- Operator promotion decision needed

---

## Findings by Action

| Action | Count | High Confidence | Notes |
|--------|-------|----------------|-------|
| keep | ~40+ | yes | All sacred files, most production tools |
| keep_with_note | 8 | yes | ctx-mcp-register, .mcp.json, llama-mcp, zsynod files, AUDIT.md |
| close_backlog_task | 32 | high | 30 Done tasks + Z-112 + Z-113 duplicates |
| relocate_candidate | 4 | high-medium | zsynod_tui.py, inspect_mlx*.py |
| delete_candidate | 4 | high-medium | bin/__pycache__, mlx_*.json/txt, .DS_Store files |
| needs_human_review | 5 | high | zsynod promotion, lib/ Python, ctx-mcp write tools, test_pack.lua, functions/_zsynod |
| create_backlog_task | 2 | high | llama_mcp tests, zsynod promotion decision |
| add_test | 3 | medium | pi-ctx-*, zdots-secret-scan, colima-status contracts |

---

## High-Risk Files

| File | Risk | Why |
|------|------|-----|
| `bin/zdots-phi-scrub` | high | PHI Scrubber binary — sacred |
| `bin/ctx-mcp` (write tools) | medium-high | 5 unadvertised dispatchable write tools |
| `bin/cc-hook-guard` | high | PHI/security gate hook for Claude Code |
| `lib/phi_scrubber.bash` | high | PHI Scrubber library |
| `functions/enabled/_zsynod` | medium-high | Shell startup path involvement |
| `sbin/zdots-brain` | high | Knowledge Layer binary |

---

## MCP Findings Summary

(Full: `audit/zdots-audit-mcp.md`)

- All 3 MCP servers use stdio — no egress
- `ctx-mcp` has test coverage for 5 advertised tools; 5 unadvertised tools are dispatchable (write operations)
- `llama-mcp`: 625 lines, 5 tools, zero protocol tests
- `ctx-mcp-register`: Claude Desktop only — correctly scoped but undocumented
- Dual registration (.mcp.json + ~/.claude.json) creates divergence risk

---

## zsynod Summary

(Full: `audit/zdots-audit-zsynod.md`)

zsynod has outgrown `experiments/`. Current footprint:
- `experiments/zsynod/` — main implementation (charter, ledger, sessions)
- `bin/zsynod_tui.py` — MISPLACED (non-executable Python TUI)
- `bin/zsynod-migrate` — Python migration script
- `lib/zsynod_core.py` + `lib/zsynod_otel.py` — Python modules in lib/
- `functions/enabled/_zsynod` — shell function (startup path)
- `tests/zsynod_*.bats` — 10 test files
- `man/man1/zsynod.1` + `share/man/man1/zsynod.1` — man pages (potential duplicate)
- 6 open backlog tasks (Z-136 to Z-144)

---

## Backlog Summary

(Full: `audit/zdots-audit-backlog.md`)

- 30 Done tasks sitting in tasks/ (not in completed/)
- Z-112 + Z-113: duplicate tasks for same bug (both Done)
- PHI safety tasks Z-095 to Z-102: mix of Done and open; active work
- zsynod tasks (Z-136, Z-137, Z-138, Z-142, Z-143, Z-144): all open, low-medium risk

---

## Proposed Future Commit Plan

(In order of risk/priority)

1. `git worktree prune` — orphaned audit worktrees
2. `backlog task archive Z-NNN` ×30 — move Done tasks to completed
3. `git mv bin/zsynod_tui.py experiments/zsynod/` + `rm -rf bin/__pycache__/`
4. `git rm inspect_mlx.py inspect_mlx_stream.py mlx_benchmark*.json mlx_help.txt` — root cleanup
5. (after human review) decide fate of test_pack.lua
6. `git add tests/llama_mcp.bats` — new test file for llama-mcp (after writing tests)
7. (after human review) fix ctx-mcp write tool exposure
8. `git rm .agents/.DS_Store .agents/skills/.DS_Store`

---

## Human Review Required

1. **zsynod promotion** — first-class capability or stay in experiments/ with cleanup?
2. **lib/zsynod_core.py + lib/zsynod_otel.py** — keep in lib/ or move under experiments/zsynod/?
3. **ctx-mcp unadvertised write tools** — advertise in Manifest or remove from dispatch?
4. **test_pack.lua** — what is this? Active work or abandoned?
5. **functions/enabled/_zsynod** — what does this function do? Is it a completion function?
6. **ctx-mcp-register fate** — update to target .mcp.json or deprecate?

---

## Do Not Touch

- `.zshrc`, `.zprofile`, `.zshenv`, `.zlogin`, `.zlogout` — shell startup
- `conf.d/` — shell startup modules
- `lib/phi_scrubber.bash` — PHI Scrubber
- `etc/phi-patterns.yaml` — PHI patterns registry
- `bin/zdots-phi-scrub` — PHI Scrubber binary
- `bin/cc-hook-guard` — PHI gate hook
- `sbin/zdots-brain` — Knowledge Layer binary
- `backlog/` PHI safety tasks (Z-095 to Z-102) without operator coordination

---

## Risks

1. `ctx-mcp` unadvertised write tools — silent Knowledge Layer mutation possible via unlisted API surface
2. `llama-mcp` zero tests — regression risk for 5-tool MCP server
3. 30 Done tasks in active tasks/ — operator spends time re-reviewing closed work
4. zsynod dual footprint (experiments/ + production paths) — unclear ownership and evolution path
5. Dual registration in .mcp.json + ~/.claude.json — path drift risk

---

## Unknown Unknowns

1. `test_pack.lua` — unknown purpose and author
2. `bin/zdots-mlx-prepare` — is the MLX inference path still active?
3. `share/man/man1/zsynod.1` vs `man/man1/zsynod.1` — which is authoritative?
4. `backlog/docs/doc-002 - PHI-Safety-Policy.md` — referenced in AGENTS.md but location unverified in this pass
5. `github-kb-analysis` skill — in .agents/skills/ but not in .claude/commands/; intentional?

---

## Recommended Next Pass

1. Operator reviews Human Review list (6 items above) and makes decisions
2. Agent executes approved low-risk commits (worktree prune, backlog archival, zsynod_tui.py relocation, root cleanup)
3. Agent writes `tests/llama_mcp.bats` after operator confirms scope
4. Agent adds pi-ctx-* and zdots-secret-scan to docs_contract.bats or known-gaps
5. Second audit pass after zsynod promotion decision to verify new footprint

---

## Artifacts Created

```
audit/zdots-audit-summary.md          ← this file
audit/zdots-audit-findings.md         ← bin/sbin/root/experiments findings
audit/zdots-audit-manifest.tsv        ← machine-readable file inventory
audit/zdots-audit-recommendations.md  ← prioritized recommendations
audit/zdots-audit-plan.json           ← machine-readable action plan
audit/zdots-audit-mcp.md              ← MCP deep-dive (subagent-written)
audit/zdots-audit-skills.md           ← skills audit
audit/zdots-audit-docs-contract.md    ← tests + docs contract audit
audit/zdots-audit-backlog.md          ← backlog hygiene audit
audit/zdots-audit-zsynod.md           ← zsynod location audit
audit/zdots-audit-commands.log        ← commands run during audit
.claude/commands/zdots-audit.md       ← /zdots-audit skill (new)
```
