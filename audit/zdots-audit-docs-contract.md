# Audit: Tests + Docs Contract
Generated: 2026-06-13
Agent: main-session

---

## Key Findings Summary

### docs/adr/ status
**EXISTS** — 2 ADRs:
- `docs/adr/0001-nginx-not-in-ai-query-path.md`
- `docs/adr/0002-phi-scrubber-go-binary.md`

### docs_contract.bats status
**EXISTS** at `tests/docs_contract.bats`
- Coverage: ~45 commands (see list below)
- Known-gaps file: EXISTS at `docs/generated/docs-contract-known-gaps.txt`
- Known gaps: 18 explicitly documented, all linked to Z-119

### Commands covered by docs_contract.bats
```
agent-guide, ai-query, alias-suggest, bootstrap, capabilities, cc-doctor,
commit-msg, diff-review, docker-reclaim, history-analyze, history-import,
idiot-test, llama-caps, llama-ctl, local-ci, nginx-ctl, nginx-repair,
openobserve-ctl, otel-collector, otel-smoke, ruby-audit, ruby-audit-batch,
ruby-audit-diff, whisper-ctl, zdash, zdots-ask, zdots-ctl, zdots-ctx,
zdots-doctor, zdots-endpoints, zdots-gh, zdots-graph-audit, zdots-keychain,
zdots-log-analyze, zdots-my-sync, zdots-o2-query, zdots-otel-phi-compile,
zdots-quiz, zdots-ruby-bump, zdots-ruby-clone, zdots-status, zdots-update-local,
zdots-worker, zmetrics, zmorning, zsvc, zsynod, ztask
```
~47 commands covered.

### Explicitly documented gaps (docs-contract-known-gaps.txt, all linked to Z-119)
```
bench               --help exits 1 instead of 0
zdots-pattern       --help exits 2 instead of 0
zdots-issue         --help exits 2 instead of 0
check               shell integrity runner; not --help-aware
colima-autostart    launchd daemon; no interactive --help
ctx-mcp             MCP stdio server; no --help contract by design
ctx-mcp-register    registration tool; --help not implemented
diarize             uv Python; --help triggers dependency download
gemini-invoke       starts session on invocation; no --help contract
llama-mcp           MCP stdio server; no --help contract by design
secret-scan         runs scan on invocation; no --help contract
trace-verify        treats --help as a session ID
zdots-ruby          Ruby launcher shim; passes args to mise-managed Ruby
cc-hook-guard       PreToolUse hook; stdin-driven, no --help contract
cc-hook-lint        hook; stdin-driven, no --help contract
cc-hook-session     SessionStart hook; emits brief, no --help contract
cc-statusline       statusline generator; reads stdin/env, no --help contract
__pycache__         Python bytecode dir; not a command
```

### Commands in bin/ NOT in docs_contract AND NOT in known-gaps
These are the true coverage gaps — no test AND no documented reason:
```
bench               (in known-gaps ✓)
cc-home             NOT covered, NOT in known-gaps ← gap
colima-status       NOT covered, NOT in known-gaps ← gap
gemini-mcp-register NOT covered, NOT in known-gaps ← gap (has test in gemini_mcp_register.bats)
history-import      appears to be covered
llama-mcp           (in known-gaps ✓)
log-rotate          NOT covered, NOT in known-gaps ← gap
pi-ctx-brief        NOT covered, NOT in known-gaps ← gap
pi-ctx-hydrate      NOT covered, NOT in known-gaps ← gap
pi-ctx-query        NOT covered, NOT in known-gaps ← gap
pi-ctx-status       NOT covered, NOT in known-gaps ← gap
secret-scan         (in known-gaps ✓)
zdots-config        NOT covered, NOT in known-gaps ← gap
zdots-github-keys   NOT covered, NOT in known-gaps ← gap
zdots-index-tools   NOT covered, NOT in known-gaps ← gap
zdots-ingest-prepare NOT covered, NOT in known-gaps ← gap
zdots-mlx-prepare   NOT covered, NOT in known-gaps ← gap
zdots-patch-export  NOT covered, NOT in known-gaps ← gap
zdots-php-scrub     NOT covered, NOT in known-gaps ← gap (also zdots-phi-scrub)
zdots-pulse         NOT covered, NOT in known-gaps ← gap
zdots-ruby-default-gems NOT covered, NOT in known-gaps ← gap
zdots-schema        NOT covered, NOT in known-gaps ← gap
zdots-secret-scan   NOT covered, NOT in known-gaps ← gap (new Go binary)
zdots-server-keys   NOT covered, NOT in known-gaps ← gap
zsynod-migrate      NOT covered, NOT in known-gaps ← gap
zsynod_tui.py       Python file — not a command per se
```

Note: `gemini-mcp-register` has a dedicated test file (`tests/gemini_mcp_register.bats`) which is a stronger contract than docs_contract.bats would provide. The pi-ctx-* commands and zdots-secret-scan (new Go binary) are the most notable gaps without any coverage.

### Z-115 status
**Done** — status field = `Done` in task file.
Commit 85d4713 "feat(dev): build docs contract, harden test suite, and standardize CLI/Ruby internals" explicitly fixes zdash --help behavior.
**Issue:** task is in `backlog/tasks/` but status is Done — should be moved to `backlog/completed/`.

### Z-116 status
**Done** — status field = `Done` in task file.
Same commit (85d4713) fixes zdots-ask --help exit code.
**Issue:** same as Z-115 — in tasks/ but Done.

### ADR dependency
Skills that reference docs/adr/: grill-with-docs, improve-codebase-architecture.
docs/adr/ EXISTS → no gap. Both skills are correctly wired.

---

## docs/ Structure Assessment

docs/ is well-organized with clear subsections:
- `docs/adr/` — Architecture Decision Records (2 ADRs)
- `docs/agents/` — Agent domain, issue-tracker, triage docs
- `docs/generated/` — Interface inventory + known-gaps (auto-generated)
- `docs/wiki/` — 8 wiki pages (Home, Command-Reference, System-Map, etc.)
- `docs/karpathy/` — LLM knowledge base pattern docs (4 files)
- Root docs/ — 40+ markdown files covering architecture, tooling, lifecycle, etc.

**Docs coverage gap:** pi-ctx-* commands (4) have no docs pages in docs/. They're in `AGENTS.md` and `CLAUDE.md` briefly, but no dedicated doc. Same for the new Go zdots-secret-scan.

---

## tests/ Inventory

| Test file | Coverage area |
|-----------|--------------|
| `tests/docs_contract.bats` | CLI --help contracts for 47 commands |
| `tests/mcp.bats` | ctx-mcp protocol, tool dispatch |
| `tests/gemini_mcp_register.bats` | gemini-mcp-register, 14 tests |
| `tests/zsynod_*.bats` (×10) | zsynod — full lifecycle |
| Other tests | Various (capabilities, secret-scan, phi-scrub, etc.) |

Test suite is substantial. Primary gaps:
1. No `tests/llama_mcp.bats` (confirmed by known-gaps and MCP audit)
2. No contract tests for pi-ctx-* commands
3. No contract test for zdots-secret-scan (new Go binary per latest commits)

---

## Backlog Connection

Z-119: "Fix help exit codes and add docs contract coverage for 13 uncovered bin scripts"
- Status: unknown (not checked — but the known-gaps file references it on every gap line)
- The known-gaps file is the formalized tracking mechanism for this Z-119 work

Z-124: "Audit found docs/interface drift — docs_contract misses ruby-audit-batch, ruby-audit-diff, zdots-ruby-clone, zmetrics; some help paths execute work; agent-guide reports stale service state"
- Several of these are now COVERED (ruby-audit-batch, ruby-audit-diff appear in docs_contract)
- Z-124 may be partially resolved — needs operator verification

---

## Recommendations

| Finding | Recommendation | Confidence | Risk |
|---------|---------------|------------|------|
| Z-115 in tasks/ but Done | close_backlog_task (move to completed/) | high | low |
| Z-116 in tasks/ but Done | close_backlog_task (move to completed/) | high | low |
| docs/adr/ exists with 2 ADRs | keep | high | low |
| docs_contract.bats exists | keep | high | low |
| pi-ctx-* not in docs_contract | add_test + add_docs | medium | low |
| zdots-secret-scan not in docs_contract | add_test | medium | low |
| llama-mcp no protocol tests | create_backlog_task | high | medium |
