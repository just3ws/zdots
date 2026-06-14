# Zdots System Audit — Skills × MCP × Implementation

> Corroboration of what's promised, what's built, and what's missing.
>
> Last updated: 2026-06-13 — session follow-up audit after gap-closing work.

---

## Status: Items Resolved Since Original Audit

| Item | Original Gap | Status |
|---|---|---|
| `docs/adr/` | Directory didn't exist; 2 skills required it | **DONE** — 2 ADRs committed (nginx-not-in-ai-query-path, phi-scrubber-go-binary) |
| MCP test coverage | Zero tests for 291-line JSON-RPC server | **DONE** — `tests/mcp.bats` has 30 tests across 5 groups (A–E) |
| Docs contract | 15 commands tested; 25 untested | **DONE** — 51 commands now covered (--help list + tested array); 2 known-gaps added |
| Z-115, Z-116 | Fixed in `85d4713` but still "To Do" | **TO CLOSE** — fixes confirmed; tasks still open in backlog |
| `zoom-out` frontmatter | Missing `description` field | **DONE** — description present |
| `setup-matt-pocock-skills` | No SKILL.md; dead artifact | **RESOLVED** — retained as installer archive; `.claude/commands/` has the actual skills |
| Platform dependency graph | No cross-system map existed | **DONE** — `docs/platform-dependency-graph.md` created with Mermaid + seams index |

---

## Active Defects Found During Audit Work

### D-1: `zshaddhistory` Silent `scrub_failure` Loop (HIGH)

`shell_hook_metrics` shows **21 `scrub_failure` events** — `zdots-phi-scrub` was not found
on PATH when the `zshaddhistory` hook fired. Each failure suppressed the command from
history rather than redacting it (correct safe-fail behavior), but:

- 21 commands were silently dropped from history without user visibility
- Error message `zshaddhistory:17: command not found: zdots-phi-scrub` appeared on `reload`
- Root cause: PATH state is different in some hook execution contexts (likely during
  `reload` → `exec zsh` transition or `zsh-defer` race)
- **Applied fix**: added `2>/dev/null` to line 66 of `55-phi-history.zsh` — eliminates
  the visible error; safe-fail suppression already handled by `scrub_status` check
- **Deeper fix needed**: instrument when scrub_failures occur (timestamp, cwd, cmd prefix)
  to identify the PATH race; track in backlog as `zdots-issue`

### D-2: `phi-history` Hook Overhead Spike (MEDIUM)

Hook metrics show max overhead of **256ms** on a single command (threshold is 20ms).
Avg is 16.8ms — high for a PHI check. The Go binary startup cost on each command call
adds latency. Consider:
- Persistent `zdots-phi-scrub` daemon mode (keep-alive server, pipe commands)
- Or coprocess to avoid subprocess-per-command cost

---

## Confirmed Outstanding Gaps

### 1. Command History Intelligence Layer — BUILT (Seam ⑦, 2026-06-13)

`bin/history-intelligence` (Python, stdlib-only) now reads all three stores and
synthesizes them into interface signals. The Infer step of the Virtuous Loop is
closed.

| Store | Contents | Consumer |
|---|---|---|
| atuin | Full command history (all commands) | `history-analyze`, `alias-suggest`, **`history-intelligence`** |
| SQLite `command_runs` | opt-in subset (exit_code, duration_ms, cwd) | **`history-intelligence`** |
| SQLite `shell_hook_metrics` | hook timing + status per command | **`history-intelligence`** |

**Delivered:**
- **PHI accountability surface**: `history-intelligence --phi` reports redacted /
  clean / suppressed / scrub_failure counts. Confirmed it surfaces the real **21
  scrub_failure events** (audit D-1) as a high-severity signal.
- **Hook health + performance**: per-hook status counts, avg/max timing, slow
  outliers over a configurable floor (`--slow-ms`, default 50ms) — surfaces D-2.
- **Reliability inference**: recurring command failures (`command_runs`) raised as
  signals when opt-in capture is on.
- **zmorning integration**: signals surfaced in the daily briefing (`recipes/morning`).
- **Agent + CI surfaces**: `--json` (schema `zdots.history-intelligence.v1`) for
  agents; `--gate` exits non-zero on a high-severity signal for hooks/CI.
- **14 bats tests** (`tests/history_intelligence.bats`), docs-contract entry.

**Remaining**: `session-debrief` (write synthesized lessons back to the Knowledge
Layer) closes the loop back to Capture/Curate — still unbuilt.

---

### 2. Z-111: MCP Silent Error Handling — STILL OPEN

`ctx-mcp` catches subprocess failures and returns error text (tested in D2–D4 groups
of `mcp.bats`). But the error format is minimal: `"Error: zdots-ctx failed"` with no
context. Agents reading this get no actionable information.

**Needed:**
- Structured error responses: tool name, exit_code, stderr snippet
- Agent-readable `isError: true` + human-readable `text` in content array
- Timeout errors distinguished from data errors

---

### 3. MCP Registration — 3 of 4 Agents Unregistered

`ctx-mcp-register` writes to Claude Desktop config only. Gemini CLI, Aider (`zaider`),
and Pi (`zpi`) have no MCP registration. Agents cannot reach the Knowledge Layer except
via Claude Code.

---

### 4. Z-141: `zdots-gh` Auth Precheck Broken (HIGH — BLOCKING)

`gh auth status >/dev/null 2>&1` exits 1 even when auth is good. Blocks gh-based harvest
commands. Root cause unknown — needs `gh auth status` output inspected directly.

---

### 5. Z-142: Bridge Verification Gap — zsynod Ratchet (HIGH)

No automated test-gate for zsynod Ratchet. `experiments/zsynod/` contains the Raft-
inspired ledger implementation but no CI gate proves it's working. Commit c250f90
moved `bin/zsynod` to experiments; `zsynod` tracked as a known-gap integration point.

---

## Dependency Graph Validation (2026-06-13)

`docs/platform-dependency-graph.md` — all 6 seams verified to exist:

| Seam | Key File | Validation |
|---|---|---|
| ① AI Invocation | `lib/ai-invoke.bash` | ✓ exists |
| ② PHI Boundary | `lib/phi_scrubber.bash`, `lib/ai_boundary.bash` | ✓ both exist |
| ③ Knowledge Layer | `bin/zdots-ctx` | ✓ exists |
| ④ MCP Transport | `bin/ctx-mcp` | ✓ exists |
| ⑤ Observability | `bin/otel-collector`, `bin/openobserve-ctl` | ✓ both exist |
| ⑥ History Capture | `conf.d/55-phi-history.zsh`, `conf.d/56-cmd-analytics.zsh` | ✓ both exist |

**Graph corrections needed (update `platform-dependency-graph.md`):**

1. **Missing: atuin** — primary history store; parallel to zdots SQLite but used by
   `history-analyze` and `alias-suggest`. Not shown in graph.
2. **Missing: Intelligence Layer** — there is no synthesis node between "History Capture"
   and "CLI Entry Points". The data exists in SQLite + Redis but nothing aggregates it.
3. **Clarify: `otel-collector`** appears as both a Platform Service (under `zsvc`) and
   in the Observability Pipeline. This is correct but the dual role should be annotated.

---

## Skill Gaps — Missing Claude Code Skills for zdots

The 21 installed skills (`.claude/commands/`) cover code quality, backlog, architecture,
and handoff. None of the following zdots-specific capabilities have a skill:

| Missing Skill | What It Would Do |
|---|---|
| `history-intelligence` | Query `command_runs` + `shell_hook_metrics` + atuin → surface: top failing commands, slowest hooks, PHI suppression events, alias candidates; formatted for agent and human |
| `phi-audit` | Report suppression/redaction counts per session; surface D-1 events; link to `zdots-issue` if scrub_failures spike |
| `session-debrief` | End-of-session: create Session Residue (`zdots-ctx capture`), surface lessons, suggest backlog tasks, update methodologies |
| `mcp-debug` | Walk through MCP call end-to-end with real `ctx-mcp` + mock and live `zdots-ctx`; surface errors clearly |
| `zdots-diagnose` | Runs `zdots-doctor --quiet`, `zdots-ctl check`, checks hook metrics, checks scrub_failure count — one-shot system health for AI-assisted triage |
| `zsynod-onboard` | Register a new AI agent into the zsynod forum; generate charter entry, assign agent ID, seed initial exchange |
| `interface-recommend` | Read `command_runs` + atuin frequency data → recommend new aliases, workflow improvements, or gaps in tooling; feeds back into backlog |

**Why this matters:**  
The Skills layer is currently weighted toward code review and architecture. zdots is an
_observable control plane_ — its intelligence value comes from accumulated session data.
Without skills that read and surface that data, the loop is: Work → Capture → (silence).

---

## Risks (Updated)

### High

| Risk | Detail | Change |
|---|---|---|
| **MCP error handling (Z-111)** | Tool handlers return minimal error text; agents get no actionable context | Unchanged |
| **PHI suppression gap (D-1)** | 21 commands silently dropped; no audit trail for which commands were lost | **NEW** |
| **Intelligence loop broken** | `command_runs` has 14 entries; `shell_hook_metrics` has 1,164 — data captured but no synthesis | **NEW** |
| **Z-141: gh auth precheck** | Blocks harvest commands; affects `zdots-gh` and any downstream skill using it | Unchanged |

### Medium

| Risk | Detail |
|---|---|
| **Hook overhead (D-2)** | 256ms max on phi-history; Go binary startup cost; may degrade interactive feel |
| **MCP registration gap** | 3 of 4 agents can't reach Knowledge Layer |
| **Skill coverage gap** | No intelligence/debrief/audit skills; data accumulates but isn't synthesized |

### Low

| Risk | Detail |
|---|---|
| **MCP protocol drift** | `2024-11-05` spec; newer clients may expect newer features |
| **`backlog` CLI dependency** | 4 skills depend on it; still no test coverage for the CLI itself |

---

## Recommendations (Updated)

| Priority | Action |
|---|---|
| **P0** | Close Z-115, Z-116 in backlog (fixes confirmed in `85d4713`) |
| **P0** | File `zdots-issue` for D-1 (scrub_failure root cause investigation — PATH race) |
| **P0** | `zdots-gh` Z-141: inspect `gh auth status` output; fix precheck logic |
| **DONE** | ~~Build `history-intelligence`~~ — `bin/history-intelligence` ships (Seam ⑦); wired into zmorning; 14 tests |
| **DONE** | ~~Add atuin + intelligence layer to `platform-dependency-graph.md`~~ — Seam ⑦ documented + realized |
| **P1** | Fix Z-111 (MCP structured errors) before expanding MCP to other agents |
| **P1** | Build `session-debrief` skill — write `history-intelligence` signals back to the Knowledge Layer; closes the Virtuous Loop |
| **P2** | Register MCP for Gemini CLI |
| **P2** | Investigate D-2 (phi-history 256ms spike) — consider `zdots-phi-scrub` daemon mode |
| **P3** | Build remaining 5 missing skills (phi-audit, mcp-debug, zdots-diagnose, zsynod-onboard, interface-recommend) |
| **P3** | Add PHI scrubber adversarial/fuzz tests |
| **P3** | Add skill registry frontmatter (version + deprecation) |

---

## Lessons Learned from This Audit Cycle

1. **Audit data goes stale fast.** Most "confirmed gaps" were already fixed by the time
   work began. Keep audit docs short-lived or timestamped; don't treat them as ground truth.

2. **Metrics reveal what static analysis can't.** The 21 `scrub_failure` events in
   `shell_hook_metrics` were invisible until the database was queried. Intelligence gaps
   don't appear in code — they appear in runtime data.

3. **The dependency graph has no tests.** The seams index is documentation; nothing
   enforces it. Add a `tests/seams.bats` that verifies each seam file exists and responds
   to a minimal probe.

4. **Data without synthesis is dead weight.** `command_runs` and `shell_hook_metrics`
   exist but have no consumer other than raw SQL queries. The next investment should be
   in the intelligence layer, not more data capture.

5. **zsynod as integration point.** Moving `zsynod` to experiments without a gap marker
   would have lost track of a planned integration. The known-gap pattern works; apply it
   to any planned future command that gets deferred.
