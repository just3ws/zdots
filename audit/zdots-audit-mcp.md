# Audit: MCP Configuration
Generated: 2026-06-13T12:56:18Z
Agent: mcp

---

## Inventory

### MCP Servers (active)

| Server | Transport | Command | Registered in |
|--------|-----------|---------|---------------|
| `backlog` | stdio | `backlog mcp start` | `.mcp.json`, `~/.claude.json` |
| `ctx` | stdio | `${HOME}/.config/zsh/bin/ctx-mcp` | `.mcp.json`; `~/.claude.json` (hardcoded path) |
| `llama` | stdio | `${HOME}/.config/zsh/bin/llama-mcp` | `.mcp.json` only |

### MCP Bin Scripts

| File | Size | Last Modified |
|------|------|---------------|
| `bin/ctx-mcp` | 6 048 B / 190 lines | 2026-05-29 |
| `bin/ctx-mcp-register` | 2 285 B / 64 lines | 2026-05-27 |
| `bin/llama-mcp` | 24 916 B / 625 lines | 2026-05-27 |
| `bin/gemini-mcp-register` | 3 853 B / 116 lines | 2026-05-29 |

### Test Files

| File | Coverage |
|------|----------|
| `tests/mcp.bats` | ctx-mcp: protocol (A1–A7), parse (B1–B3), tool calls (C1–C5), error paths (D1–D5), contract (E1–E4) |
| `tests/gemini_mcp_register.bats` | gemini-mcp-register: help, guards, registration, idempotency, --force, env override |

### Backlog Tasks

| ID | Title | Status | Priority |
|----|-------|--------|----------|
| Z-111 | Register ctx-mcp in ~/.claude.json | Done | — |
| Z-132 | Evaluate sequential-thinking MCP server | To Do | low |
| Z-139 | cc-doctor: validate .mcp.json commands resolve + PATH includes $ZDOTDIR/bin | To Do | medium |

---

## Per-File Findings

---

## /Users/mike/.config/zsh/.mcp.json
Status: keep_with_note
Confidence: high
Risk: low

### Evidence
- Direct references: tracked in git, loaded by `cc-doctor`, sourced by Claude Code session via `enabledMcpjsonServers`
- Transport type: all three servers use `stdio` — no network sockets, no egress
- Decrypted content risk: low — this is config-only, no content at rest
- Tests: `cc-doctor` validates JSON validity and presence of `backlog`/`ctx`/`llama` keys at runtime
- Docs: referenced in CLAUDE.md and `cc-doctor --help`
- Git history notes: introduced to replace `~/.claude.json` as portable tracked config

### Note
`ctx` and `llama` commands use `${HOME}` variable references (e.g., `"${HOME}/.config/zsh/bin/ctx-mcp"`). Claude Code expands these at spawn time, and the active session confirms `ctx` is live. However, `~/.claude.json` (the legacy/global config) stores the ctx entry with a hardcoded absolute path (`/Users/mike/.config/zsh/bin/ctx-mcp`) rather than `${HOME}` — dual registration creates a latent divergence risk if paths change.

`llama` is in `.mcp.json` but **not** in `~/.claude.json`. `settings.local.json` has `enabledMcpjsonServers: [backlog, ctx, llama]`, so `llama` is active via the project-scoped `.mcp.json`.

### Recommendation
1. Remove the `ctx` entry from `~/.claude.json` — it is now redundant with `.mcp.json` and the two entries can diverge silently.
2. File a follow-up under Z-139 to add cc-doctor check: verify `${HOME}` in .mcp.json resolves at spawn time (claude mcp list output confirms server is running).

### Rationale
Dual registration (`.mcp.json` + `~/.claude.json`) with different path styles is drift-prone. `.mcp.json` is the canonical tracked source; `~/.claude.json` is the legacy global. The legacy entry should be retired.

### Future commit plan
No commit during dry run.

---

## /Users/mike/.config/zsh/bin/ctx-mcp
Status: keep_with_note
Confidence: high
Risk: medium

### Evidence
- Direct references: registered as `ctx` in `.mcp.json` and `~/.claude.json`; called by Claude Code, Gemini CLI
- Transport type: stdio (JSON-RPC 2.0) — local only
- Decrypted content risk: **medium** — tool returns Knowledge Layer content (lessons, methodologies, session residue) back to Claude Code (cloud). Content flows: local PostgreSQL → `zdots-ctx` → ctx-mcp → Claude Code (cloud). The PostgreSQL data is stored in plaintext (encryption key provisioning is blocked behind `ZDOTS_CAPTURE_ENABLED=0`). PHI scrubbing happens at **ingest** (Z-135), so residue in the DB should already be scrubbed before ctx-mcp sees it. However, no scrubbing layer sits between ctx-mcp output and Claude Code.
- Tests: `tests/mcp.bats` — strong protocol/contract coverage; **5 tools tested** (C1–C5)
- Docs: `docs/tooling.md` (brief mention); no dedicated MCP server doc
- Git history notes: created for Z-111; updated 2026-05-29 (manifest integration)

### Key finding — unadvertised tools in dispatch table
`bin/ctx-mcp` has 10 entries in `call_tool` but only 5 are advertised via `Zdots::Manifest.mcp_tools`. The hidden 5:
- `ctx_add_methodology`
- `ctx_add_lesson`
- `ctx_capture`
- `ctx_semantic_search`
- `ctx_jobs`

These tools are **callable** (if a client sends a `tools/call` for them by name) but are not listed in `tools/list`. An agent that guesses or caches tool names can invoke write operations (`add_methodology`, `add_lesson`, `capture`) silently. `ctx_capture` in particular triggers session residue distillation, which has its own PHI safety gate (`ZDOTS_CAPTURE_ENABLED` check in `zdots-ctx`), but the gate is upstream — ctx-mcp does not apply it; it passes the call through blindly and returns whatever zdots-ctx returns (including error messages containing session ID).

Test E3 hardcodes the expected count as 5; E4 hardcodes the expected name set. Both would pass even if the dispatch table grows further — tests validate the advertised surface, not the full callable surface.

### Recommendation
1. Either promote the 5 hidden tools to the Manifest (with `mcp: true`) so they are properly advertised and documented, OR remove them from `call_tool` dispatch entirely if they are intentionally hidden.
2. Add contract test: every name in `call_tool` must also appear in `tools/list` response (no silent dispatch entries).
3. Mark `ctx_capture` as `needs_human_review` — it writes to the Knowledge Layer and the PHI gate is in `zdots-ctx`, not ctx-mcp. Consider explicit `ZDOTS_CAPTURE_ENABLED` check in ctx-mcp before forwarding.

### Rationale
Unadvertised-but-dispatchable tools are a capability surface that no client tooling will document, test, or gate on. The write tools (`add_methodology`, `add_lesson`, `capture`) are the highest-risk entries because they mutate the Knowledge Layer.

### Future commit plan
No commit during dry run.

---

## /Users/mike/.config/zsh/bin/ctx-mcp-register
Status: keep_with_note
Confidence: high
Risk: low

### Evidence
- Direct references: invoked manually by operator to register ctx-mcp in `~/.claude.json`
- Transport type: bash — reads and writes JSON file; no network
- Decrypted content risk: none — config tool only
- Tests: no dedicated bats test; covered indirectly by Z-111 acceptance criteria
- Docs: inline `--help` in script; referenced in Z-111

### Note
This script targets `~/.claude.json` (legacy global), not `.mcp.json` (tracked portable). Now that `.mcp.json` is the canonical location, `ctx-mcp-register` is writing to the redundant path. It does not support registering to `.mcp.json`. If the dual-registration issue from `.mcp.json` findings is resolved by removing the `~/.claude.json` entry, this script should either be updated to operate on `.mcp.json` or deprecated.

Also: only registers `ctx` server — does not register `llama`. `gemini-mcp-register` registers both; Claude Code path uses `.mcp.json` for both. The asymmetry is undocumented.

### Recommendation
Evaluate whether `ctx-mcp-register` is still needed now that `.mcp.json` covers Claude Code. If retained, update to target `.mcp.json` and also register `llama`. If deprecated, remove from `bin/` and update `docs/tooling.md`.

### Future commit plan
No commit during dry run.

---

## /Users/mike/.config/zsh/bin/llama-mcp
Status: keep_with_note
Confidence: high
Risk: low

### Evidence
- Direct references: registered as `llama` in `.mcp.json`; `gemini-mcp-register` registers it for Gemini CLI
- Transport type: stdio (JSON-RPC 2.0) — local only
- Decrypted content risk: low — tools return operational metadata (health, config, model info, test results, code snippets). No Knowledge Layer content, no session residue, no credentials
- Tests: **no protocol-level bats tests** — `gemini_mcp_register.bats` only tests the *registration* script, not the server protocol. No equivalent of `mcp.bats` for llama-mcp.
- Docs: `docs/tooling.md` (brief mention); `docs/generated/docs-contract-known-gaps.txt` explicitly notes "no --help contract by design"
- Git history notes: created 2026-05-27 with full tool set

### Key finding — no unit tests
`llama-mcp` is 625 lines, exposes 5 tools, and has zero protocol-level tests. There is no bats file that:
- Verifies `initialize` / `tools/list` response format
- Tests each tool dispatch
- Tests parse error handling
- Validates tool count/name contract

This is a coverage gap flagged in the docs contract gaps file but not yet addressed.

### Key finding — `yq` shell interpolation at constant evaluation time
In `tool_llama_integration_snippet`, two snippet strings use backtick shell interpolation (`\`yq '.server.ubatch_size' ...\``) evaluated at constant definition time (Ruby heredoc literal assignment). This means the value is captured once when the process starts, not at call time. If the server is not running or `yq` is absent, the interpolated value silently falls back to empty string with `|| "2048"`. No error is surfaced to the caller. Low severity but obscures misconfiguration.

### Recommendation
1. Create `tests/llama_mcp.bats` mirroring the structure of `tests/mcp.bats` — protocol (initialize, tools/list, ping), parse errors, tool dispatch, contract (name/count match). This directly addresses Z-139's coverage gap.
2. Move the `yq` interpolation to inside `tool_llama_integration_snippet` so it runs at call time with a clear fallback message, not silently at startup.

### Future commit plan
No commit during dry run.

---

## /Users/mike/.config/zsh/bin/gemini-mcp-register
Status: keep
Confidence: high
Risk: low

### Evidence
- Direct references: registers `ctx` and `llama` servers with Gemini CLI at `~/.gemini/settings.json`
- Transport type: bash — invokes `gemini mcp add`; no network calls itself
- Decrypted content risk: none — config tool only
- Tests: `tests/gemini_mcp_register.bats` — comprehensive: help, guards, registration, idempotency, --force, env override (14 tests)
- Docs: inline `--help`; referenced in `docs/tooling.md`

### Recommendation
Keep as-is. Well-tested, idempotent, scoped to Gemini CLI only.

### Future commit plan
No commit during dry run.

---

## settings.json — MCP Permission Grants

Status: keep_with_note
Confidence: high
Risk: low

### Evidence
Four MCP tools granted in `allow` list across tracked/local settings:
- `mcp__backlog__task_list` — read-only backlog
- `mcp__backlog__task_view` — read-only backlog
- `mcp__backlog__task_create` — write (settings.local.json)
- `mcp__backlog__task_edit` — write (settings.local.json)
- `mcp__ctx__ctx_query` — read Knowledge Layer
- `mcp__ctx__ctx_status` — read status

### Note
`mcp__ctx__ctx_hydrate` and `mcp__ctx__ctx_enqueue` are callable (advertised in tools/list) but have no explicit allow entry. Claude Code prompts for permission on first use. This is correct behavior — no issue. However, the five unadvertised ctx tools (`ctx_add_methodology`, `ctx_add_lesson`, `ctx_capture`, etc.) have no allow entries either, and since they don't appear in `tools/list`, Claude Code will never surface a permission prompt for them. A client that directly calls them would bypass the permission UI — the only gate would be whatever `zdots-ctx` enforces.

### Future commit plan
No commit during dry run.

---

## Backlog Task: Z-132 (Sequential-thinking MCP)

Status: keep_with_note
Confidence: high
Risk: low (unevaluated)

### Evidence
Not yet adopted. Acceptance criteria require: official source verification, no-network-calls verification, and addition to `.mcp.json` if adopted. These have not been completed.

### Recommendation
No change to codebase. Z-132 is correctly scoped and sequenced. Proceed through its AC before adoption.

---

## Overall Risk Summary

| Layer | Risk | Notes |
|-------|------|-------|
| Transport | **low** | All three MCP servers use stdio; no TCP/HTTP sockets; no egress |
| PHI exposure via ctx-mcp | **medium** | KB content (already PHI-scrubbed at ingest) flows to Claude Code cloud; scrub at ingest must hold |
| Unadvertised write tools (ctx-mcp) | **medium** | 5 tools callable but unlisted; write operations (add_lesson, add_methodology, capture) have no ctx-mcp-level gate |
| llama-mcp test coverage | **medium** | Zero protocol tests for a 625-line, 5-tool server |
| Dual registration (.mcp.json + ~/.claude.json) | **low** | Functional, but divergent path styles risk silent drift |
| ctx-mcp-register targeting ~/.claude.json | **low** | Targets legacy path; now redundant with .mcp.json |
| .mcp.json ${HOME} expansion | **low** | Claude Code expands; confirmed active in session; no immediate risk |
| Sequential thinking MCP (Z-132) | **low** | Not adopted; proper vetting process in place |

### Stop Conditions Hit
None. No PHI leakage in progress, no active misconfiguration that exposes secrets. All transport is local-only stdio.

---

## Known Gap Verification

### ctx-mcp tests
Partially addressed: `tests/mcp.bats` covers the 5 advertised tools and the full protocol surface. **Gap:** the 5 unadvertised-but-dispatchable tools have no test coverage. No bats test verifies that `call_tool` dispatch and `tools/list` are in sync.

### ctx-mcp-register agent support
`bin/ctx-mcp-register` supports **Claude Code only** (writes to `~/.claude.json`). Gemini CLI registration is handled by the separate `bin/gemini-mcp-register`. No registration script exists for Cursor, Windsurf, or other MCP clients. This is a scoping decision, not a defect, but it is undocumented.

### llama-mcp tests
**Gap confirmed:** no bats test file for llama-mcp protocol or tool dispatch. Tracked in `docs/generated/docs-contract-known-gaps.txt`. Not yet addressed.

### Z-139 (cc-doctor .mcp.json validation)
`cc-doctor` validates JSON validity, server presence (backlog/ctx/llama), and stale port references. It does **not** validate that commands in `.mcp.json` resolve on PATH, or that PATH overrides in `env` include `$ZDOTDIR/bin`. Z-139 is open and correctly describes this gap.
