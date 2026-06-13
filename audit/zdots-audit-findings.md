# Audit: General Findings (bin/ + sbin/ + root + experiments/)
Generated: 2026-06-13
Agent: main-session

---

## bin/ (87 files, all executable except zsynod_tui.py)

### Non-executable bin file

## bin/zsynod_tui.py
Status: relocate_candidate
Confidence: high
Risk: low
### Evidence
- Direct references: Python TUI for zsynod, not executable
- `bin/__pycache__/zsynod_tui.cpython-314.pyc` proves it was imported
- Not in docs_contract.bats (nor in known-gaps — noted as `__pycache__: Python bytecode directory created by zsynod_tui.py compilation; not a command`)
- Git history: added with zsynod work
### Recommendation
relocate_candidate → `experiments/zsynod/`
### Rationale
Non-executable Python file in bin/ won't run from PATH. Wrong directory for the file type and purpose.

---

## bin/__pycache__/ (zsynod_tui.cpython-314.pyc)
Status: delete_candidate
Confidence: high
Risk: low
### Evidence
- Python bytecode cache in bin/ — should never be here
- Explicitly called out in docs-contract-known-gaps.txt as "not a command"
### Recommendation
delete_candidate. Relocating zsynod_tui.py removes the cause. Also check `.gitignore` covers `__pycache__/`.

---

### Key bin/ files — selected findings

## bin/zdots-secret-scan
Status: keep
Confidence: high
Risk: low
### Evidence
- Go binary shim (from commit 88d48b8 "feat(secret-scan): wire Go zdots-secret-scan as default via bin/secret-scan shim")
- Replaces original bash secret-scan
- Referenced by pre-commit hooks and `.claude/settings.json` deny list
- Tests: no contract test in docs_contract.bats, not in known-gaps — gap
### Recommendation
keep + add_test (docs_contract.bats entry or dedicated test)

---

## bin/zsynod-migrate
Status: keep_with_note
Confidence: medium
Risk: low
### Evidence
- Python script: "Migrate Zsynod ledger from Bash-JSONL to Python-Pydantic"
- Validates hash chain during migration
- Not in docs_contract.bats, not in known-gaps
- May be a one-time migration tool or ongoing utility — unclear
### Recommendation
keep_with_note — clarify if this is a one-time tool (→ experiments/) or recurring (→ add docs_contract entry)

---

## bin/trace-verify
Status: keep
Confidence: medium
Risk: low
### Evidence
- Shell script for contract testing of the shell control plane
- YAML frontmatter in script identifies it
- Not in docs_contract.bats (known-gaps: "first positional arg is session_id; treats --help as session ID")
### Recommendation
keep — gap in docs_contract.bats is documented in known-gaps/Z-119

---

## bin/zdots-ingest-prepare
Status: keep
Confidence: medium
Risk: low
### Evidence
- Bash: prepares documents (PDF, Docx, VTT) for ingestion into Zdots Brain
- Not in docs_contract.bats, not in known-gaps — true gap
### Recommendation
keep + create_backlog_task to add docs_contract coverage (or add to known-gaps with rationale)

---

## bin/zdots-mlx-prepare
Status: keep_with_note
Confidence: low
Risk: low
### Evidence
- Python script importing `mlx_lm` — MLX inference library
- Sits alongside `mlx_benchmark_20260609_195045.json` and `mlx_help.txt` (root) and `inspect_mlx*.py` (root)
- All from Jun 9 investigation of MLX
- Not in docs_contract.bats, not in known-gaps — true gap
- May be experimental (MLX = Apple Silicon ML framework) — unclear if still used
### Recommendation
keep_with_note — verify if MLX inference path is still active or abandoned

---

## bin/zdots-phi-scrub
Status: keep
Confidence: high
Risk: high
### Evidence
- PHI Scrubber binary — SACRED
- Referenced from lib/phi_scrubber.bash
- Part of the Message Hygiene Pipeline
- Go binary per ADR-0002
### Recommendation
keep — sacred component, no changes without operator coordination

---

## bin/cc-hook-guard, bin/cc-hook-lint, bin/cc-hook-session, bin/cc-statusline
Status: keep
Confidence: high
Risk: medium
### Evidence
- Referenced in `.claude/settings.json` hooks
- Hook infrastructure — changes affect all Claude Code sessions
- All in docs-contract known-gaps (by design — stdin-driven, no --help contract)
### Recommendation
keep — sacred, referenced directly from settings.json

---

## bin/colima-status
Status: keep
Confidence: high
Risk: low
### Evidence
- Authoritative Colima status tool (AGENTS.md: "Always use colima-status, never probe directly")
- Not in docs_contract.bats, not in known-gaps — true gap
- Referenced extensively in AGENTS.md, CLAUDE.md, agent prompts
### Recommendation
keep + add to docs_contract.bats or known-gaps

---

## bin/ctx-mcp, bin/ctx-mcp-register
Status: see zdots-audit-mcp.md
Confidence: high
Risk: high (ctx-mcp), low (ctx-mcp-register)

---

## bin/zdots-secret-scan (Go binary shim)
Status: keep
Confidence: high
Risk: low
### Evidence
- Shim wrapping cmd/zdots-secret-scan (Go, committed per recent commits)
- Replaces bash prototype
- Recent: commit 88d48b8 (HEAD~1)

---

## sbin/ (2 files)

## sbin/zdots-brain
Status: keep
Confidence: high
Risk: high
### Evidence
- Go binary — Knowledge Layer executable
- Runs migrations, manages Sequel models
- NOT on user PATH (sbin/ convention: system/root use)
- Referenced by: zdots-ctx (Ruby bridge), migrations
### Recommendation
keep — core infrastructure binary, sacred

---

## sbin/zdots-recommend
Status: keep
Confidence: high
Risk: low
### Evidence
- Ruby script: "View and act on operational recommendations"
- In sbin/ (appropriate — admin-level operation)
- Not in docs_contract.bats — but sbin/ commands not expected to be there
### Recommendation
keep

---

## Root Files — Anomalies

### Tracked experiment artifacts (all in git, all in root)

| File | Date | Classification | Recommendation |
|------|------|---------------|----------------|
| `inspect_mlx.py` | Jun 9 | MLX investigation script | relocate_candidate → experiments/ |
| `inspect_mlx_stream.py` | Jun 9 | MLX stream inspection | relocate_candidate → experiments/ |
| `mlx_benchmark_20260609_195045.json` | Jun 9 | Benchmark artifact | delete_candidate (data point, not source) |
| `mlx_help.txt` | Jun 9 | MLX help text snippet | delete_candidate |
| `test_pack.lua` | Jun 12 | Lua test file | relocate_candidate → experiments/ or delete |
| `zdots_system_audit.md` | May 29 | Previous audit run | keep_with_note (historical) or → audit/ |
| `AUDIT.md` | May 29 | Belief Integrity Audit doc | keep (referenced practice?) |

All 7 are tracked in git. Relocating or deleting requires `git rm` / `git mv`. Low risk, but root pollution.

### Git notes
- Commit `a9a20e4 chore(cleanup): remove sandbox files and finalize repository state` was supposed to clean up but these files survived (were in that commit, not removed by it)
- `b8240a0` last touched `test_pack.lua` (Jun 12 — very recent, may be in-progress work)

**Do not delete `test_pack.lua` without confirming it's not active work.**

### Sacred root files (no audit)
`.zshrc`, `.zprofile`, `.zshenv`, `.zlogin`, `.zlogout` — shell startup, sacred.
`.p10k.zsh` — prompt, sacred.
`AGENTS.md`, `CLAUDE.md` — agent context, sacred.

---

## experiments/

## experiments/zsynod/
Status: keep
Confidence: high
Risk: low
### Evidence
- Main zsynod implementation
- Charter, decisions, ledger, minutes, sessions, transcripts
- Active (open backlog tasks, Python lib, tests)
### Recommendation
keep — active experiment, maturing toward production

## experiments/enable-zsynod.sh
Status: keep_with_note
Confidence: medium
Risk: low
### Evidence
- Shell script to enable the zsynod experiment
- In experiments/ — correct location
### Recommendation
keep_with_note — verify it still works with current zsynod architecture

---

## Orphaned Worktrees (not production)

`.claude/worktrees/agent-a926184c9c04e2581` and `.claude/worktrees/agent-aa1d122122760da74` are stale agent worktrees from this audit session's timed-out subagents. These contain full repo copies and are safe to prune.

```bash
git worktree list
git worktree prune
```

No production impact. Not tracked in main branch.
