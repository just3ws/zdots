# zdots Audit — Recommendations
Generated: 2026-06-13
Mode: dry run — no commits

---

## Priority 1: Low-risk, High-value Housekeeping

### 1.1 Move 30 Done tasks from tasks/ to completed/
Evidence: 30 tasks in `backlog/tasks/` have `status: Done`.
Action: `backlog task archive` (or `git mv`) for each.
Risk: low. No code changes. Backlog hygiene only.

### 1.2 Prune stale agent worktrees
Evidence: Two orphaned worktrees from timed-out audit agents.
Action: `git worktree prune`
Risk: low. Worktrees contain no un-merged commits.

### 1.3 Relocate bin/zsynod_tui.py → experiments/zsynod/
Evidence: Non-executable Python TUI in bin/ won't run from PATH.
Action: `git mv bin/zsynod_tui.py experiments/zsynod/`
Followup: Remove `bin/__pycache__/` (bytecode pollution).
Risk: low. No references to this file as a command.

### 1.4 Relocate root experiment artifacts → experiments/ or delete
Files: `inspect_mlx.py`, `inspect_mlx_stream.py`, `mlx_benchmark_*.json`, `mlx_help.txt`
Evidence: Experiment artifacts from Jun 9 MLX investigation, committed to repo root.
**Caveat:** `test_pack.lua` (Jun 12) may be active — needs operator confirmation before touching.
Action: `git mv inspect_mlx*.py experiments/` + `git rm mlx_benchmark*.json mlx_help.txt`
Risk: low for the Jun 9 files. Do NOT touch test_pack.lua without confirmation.

---

## Priority 2: Test Coverage Gaps

### 2.1 Add llama-mcp protocol tests
Evidence: `bin/llama-mcp` is 625 lines, 5 tools, zero protocol-level bats tests.
Action: Create `tests/llama_mcp.bats` mirroring `tests/mcp.bats` structure.
Risk: medium (test gap for a PHI-adjacent MCP server).
Backlog: Z-139 partially covers this; a dedicated task may be warranted.

### 2.2 Add ctx-mcp dispatch/advertised-surface contract test
Evidence: 5 unadvertised-but-dispatchable tools in ctx-mcp (see zdots-audit-mcp.md).
Action: Add test verifying `call_tool` dispatch list == `tools/list` output.
Risk: medium (silent write operations via unlisted tools).

### 2.3 Add docs_contract.bats entries for uncovered commands
Gaps without documented rationale: `colima-status`, `pi-ctx-*` (4 commands), `zdots-secret-scan`, `zdots-ingest-prepare`, `zdots-config`, `zdots-schema`, `zdots-pulse`, `log-rotate`, others.
Action: Either add `--help` contracts or add entries to `docs/generated/docs-contract-known-gaps.txt` with Z-119 reference.
Risk: low.

---

## Priority 3: Architecture Decisions Needed (human review required)

### 3.1 zsynod promotion decision
Evidence: zsynod has 10 test files, man pages, lib/ Python modules, shell function in startup path, and 6 open tasks. It has outgrown `experiments/`.
Options:
  A. Formalize as first-class capability (move lib/zsynod_*.py to proper location, add to AGENTS.md services table)
  B. Retain as experiment but move stray files back (bin/zsynod_tui.py → experiments/, lib/*.py → experiments/zsynod/lib/)
Action: Operator architecture decision. File backlog task.

### 3.2 lib/zsynod_core.py + lib/zsynod_otel.py placement
Evidence: Python modules in `lib/` alongside bash library files. Architecturally inconsistent.
Risk: medium (lib/ convention is bash; Python modules here are undocumented convention).
Action: needs_human_review — operator decides if lib/ hosts Python or if zsynod Python should be under experiments/zsynod/.

### 3.3 ctx-mcp write tools exposure
Evidence: 5 tools callable via ctx-mcp but not advertised in tools/list (ctx_add_methodology, ctx_add_lesson, ctx_capture, ctx_semantic_search, ctx_jobs).
Risk: medium — write operations with no PHI gate at ctx-mcp level.
Action: Either promote all to Manifest (advertise) or remove from dispatch. Operator decides policy.

### 3.4 ctx-mcp-register redundancy with .mcp.json
Evidence: ctx-mcp-register writes to ~/.claude.json (Claude Desktop); .mcp.json now covers Claude Code. Dual registration creates divergence risk.
Action: Decide whether ctx-mcp-register should be updated to target .mcp.json or deprecated.

---

## Priority 4: Documentation Additions

### 4.1 Document ctx-mcp-register scope
Add clear note in tool docs: "Targets Claude Desktop (~/.claude.json) only. Claude Code uses .mcp.json."

### 4.2 Document zsynod production vs experiment status
The zsynod README and CHARTER.md don't clarify whether this is still an experiment. Update to reflect actual integration depth.

---

## Do Not Touch

| Item | Reason |
|------|--------|
| `.zshrc`, `.zprofile`, `.zshenv` | Shell startup — sacred |
| `lib/phi_scrubber.bash` | PHI Scrubber — sacred |
| `etc/phi-patterns.yaml` | PHI patterns registry — sacred |
| `conf.d/` | Shell startup modules — sacred |
| `bin/zdots-phi-scrub` | PHI Scrubber binary — sacred |
| `bin/cc-hook-guard` | PHI/security gate hook |
| `sbin/zdots-brain` | Knowledge Layer binary |
| `functions/enabled/_zsynod` | Shell startup involvement |
| `bin/zdots-ctx` | Knowledge Layer CLI |
| `backlog/` task infrastructure | Without operator coordination |

---

## Unknown Unknowns

1. `test_pack.lua` — Jun 12 file, unknown purpose and author. Do not delete without investigation.
2. `zdots_system_audit.md` + `AUDIT.md` — previous audit artifacts. Are these referenced or orphaned?
3. `bin/zdots-mlx-prepare` — MLX inference preparation. Is the MLX inference path still active?
4. `share/man/man1/zsynod.1` vs `man/man1/zsynod.1` — which is authoritative?
5. `docs/agents/domain.md` references no ADRs yet — is this intentional or a gap to fill?
6. `backlog/docs/doc-002 - PHI-Safety-Policy.md` referenced in AGENTS.md — does it exist?

---

## Recommended Next Pass

1. Operator decides: (a) zsynod promotion, (b) lib/ Python convention, (c) ctx-mcp write tool policy
2. Agent: close 30 Done tasks in tasks/ (one commit per batch, or one per task using backlog CLI)
3. Agent: `git worktree prune`
4. Agent: relocate `bin/zsynod_tui.py` + clean `bin/__pycache__/`
5. Agent: investigate and resolve `test_pack.lua` question
6. Agent: create `tests/llama_mcp.bats`
7. Agent: address ctx-mcp dispatch/advertise gap (after policy decision in step 1c)
