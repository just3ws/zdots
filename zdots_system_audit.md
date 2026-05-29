# Zdots System Audit — Skills × MCP × Implementation

> Corroboration of what's promised, what's built, and what's missing.

---

## Confirmed Gaps

### 1. `docs/adr/` Does Not Exist

Two skills depend on it:
- [grill-with-docs](file:///Users/mike/.config/zsh/.agents/skills/grill-with-docs/SKILL.md) — reads ADRs, creates/updates them inline
- [improve-codebase-architecture](file:///Users/mike/.config/zsh/.agents/skills/improve-codebase-architecture/SKILL.md) — reads ADRs for architectural context

**Impact:** Both skills will either fail silently or hallucinate structure. No ADR directory → no architectural decision record trail.

**Fix:** `mkdir -p docs/adr && echo "# ADR Index" > docs/adr/README.md`

---

### 2. MCP Server Has Zero Test Coverage

[ctx-mcp](file:///Users/mike/.config/zsh/bin/ctx-mcp) (291 lines) implements 5 JSON-RPC tools. No bats or integration tests exist.

- Z-111 (silent error handling) still open
- No schema validation of request/response
- No test for malformed JSON, missing params, or tool dispatch edge cases

**Risk:** MCP is a trust boundary — agents rely on it for knowledge base access. Untested → silent data corruption or lost queries.

---

### 3. MCP Only Registered for Claude Desktop

[ctx-mcp-register](file:///Users/mike/.config/zsh/bin/ctx-mcp-register) writes to `~/Library/Application Support/Claude/claude_desktop_config.json`. No registration path for:
- Gemini CLI (`gm`)
- Aider (`zaider`)
- Pi (`zpi`)

**Impact:** MCP tools (query, hydrate, ingest, status, capabilities) unavailable to 3 of 4 agent personas.

---

### 4. 25 of 40 `bin/` Scripts Untested in Docs Contract

[docs_contract.bats](file:///Users/mike/.config/zsh/tests/docs_contract.bats) covers 15 commands. **25 scripts have no `--help` contract test:**

`bench`, `bootstrap`, `check`, `colima-autostart`, `ctx-mcp`, `ctx-mcp-register`, `docker-reclaim`, `fabric-ai`, `gemini-invoke`, `git-credential-keychain`, `install-bats-helpers`, `llama-model-registry`, `local-state-updater`, `repomix`, `rtk`, `secret-scan`, `zdots-issue`, `zdots-keychain`, `zdots-ruby`, `zdots-update-local`, `zdots-quiz`, `zdots-pattern`, `zdots-status`, `zdots-log-analyze-impl`

**Risk:** Interface drift — scripts change behavior without contract enforcement.

---

### 5. Stale Backlog Task Statuses

| Task | Actual State | Backlog Status |
|---|---|---|
| [Z-115](file:///Users/mike/.config/zsh/backlog/tasks/z-115%20-%20agent-issue-zdash-help-does-not-show-usage-emits-_cmd_list-12-read-only-variable-status-and-falls-through-to-task-list-output-instead-of-documenting-flags-commands.md) | Fixed in `85d4713` | To Do |
| [Z-116](file:///Users/mike/.config/zsh/backlog/tasks/z-116%20-%20agent-issue-zdots-ask-help-prints-usage-but-exits-2-instead-of-0-docs-help-contracts-expect-help-to-be-a-successful-read-only-operation.md) | Fixed in `85d4713` | To Do |

Fixes committed but tasks not closed → backlog is stale.

---

### 6. `setup-matt-pocock-skills` — Dead Artifact

Directory exists at `.agents/skills/setup-matt-pocock-skills/` with `scripts/install.sh` but **no SKILL.md**. Not a usable skill. Either:
- Installer that ran once and should be cleaned up
- Incomplete skill that was never finished

---

### 7. `zoom-out` — Missing Frontmatter Description

[zoom-out SKILL.md](file:///Users/mike/.config/zsh/.agents/skills/zoom-out/SKILL.md) has no `description` in YAML frontmatter. Agents that parse frontmatter for skill routing will skip it.

---

## Risks

### High

| Risk | Detail |
|---|---|
| **MCP error handling** | Z-111 open. Tool handlers may swallow errors → agent gets empty/wrong data → bad decisions. |
| **No MCP tests** | 291 lines of JSON-RPC dispatch with zero test coverage. Any refactor = blind. |
| **PHI via MCP** | `zdots_query` and `zdots_hydrate` return decrypted content. MCP has no auth layer. If MCP transport changes from stdio → HTTP, PHI leaks. |

### Medium

| Risk | Detail |
|---|---|
| **ADR gap** | Skills promise ADR cross-referencing but `docs/adr/` doesn't exist. Skills will silently degrade. |
| **Skill dependency on `backlog` CLI** | 4 skills depend on it (`to-issues`, `to-prd`, `triage`, `zdots`). If `backlog` breaks, half the workflow skills fail. No `backlog` test coverage found. |
| **Ruby coverage at 77.6%** | 34 lines uncovered. Branch coverage 69.7%. Jobs and model edge cases likely untested. |

### Low

| Risk | Detail |
|---|---|
| **MCP protocol drift** | Using `2024-11-05` spec. MCP evolves fast — newer clients may expect features not implemented. |
| **`zdots-status` wrapper** | Z-113 open. Trivial but tracked. |

---

## Unknown Unknowns

> Things we can't see from static analysis alone.

| Area | What We Don't Know |
|---|---|
| **MCP runtime behavior** | Does `ctx-mcp` actually work end-to-end with Claude Desktop? Last tested when? |
| **Skill interaction** | No integration test for skill chains (e.g., `grill-with-docs` → `to-issues` → `triage`). Do they compose? |
| **PHI scrubber coverage** | `etc/phi-patterns.yaml` defines patterns. Are there PHI shapes that slip through? No adversarial/fuzz testing. |
| **Knowledge base quality** | `zdots_query`/`zdots_hydrate` return decrypted content. Is stale/wrong methodology actively harmful? No expiry/review mechanism. |
| **Agent persona drift** | Skills reference 4 agent roles (Pi, Aider, Claude Code, Gemini). Do their actual system prompts honor the same contracts? |
| **Encryption key rotation** | `rekey` command exists. Has it ever been tested with real data? Recovery path if rotation fails mid-stream? |
| **Job queue reliability** | Heartbeat/DLQ/backoff implemented. Load-tested? What happens under sustained queue pressure? |
| **`backlog` CLI** | 4 skills depend on it. Where is it defined? Is it a gem, a script, a function? No `which backlog` result in audit. |
| **Skill discovery** | Agents find skills by directory listing. No registry, no versioning, no deprecation mechanism. |
| **Cross-agent handoff integrity** | `handoff` skill produces markdown. Receiving agent must parse it correctly. No schema or validation. |

---

## Recommendations (Prioritized)

| Priority | Action |
|---|---|
| **P0** | Add MCP test suite (`tests/mcp.bats`). Cover: init, tool list, each tool call, error paths, malformed input. |
| **P0** | Create `docs/adr/` directory. Even empty-with-README unblocks 2 skills. |
| **P1** | Close Z-115, Z-116 in backlog (already fixed). |
| **P1** | Fix Z-111 (MCP silent errors) before any MCP expansion. |
| **P1** | Add `zoom-out` frontmatter description. |
| **P2** | Remove or complete `setup-matt-pocock-skills`. |
| **P2** | Expand docs-contract test to cover remaining 25 scripts (even if just `--help || known-gap`). |
| **P2** | Add MCP registration support for Gemini CLI. |
| **P3** | Add PHI scrubber fuzz/adversarial tests. |
| **P3** | Document skill composition patterns (which skills chain well). |
| **P3** | Add skill registry with version + deprecation fields to frontmatter. |
