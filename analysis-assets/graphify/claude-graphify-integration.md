# Claude Code × Graphify Integration

## What `graphify claude install` does (and why not to run it blindly)

It (1) appends a graphify section to **`CLAUDE.md`** and (2) installs a **PreToolUse hook**. Both collide with zdots' curated setup:

- `CLAUDE.md` / `AGENTS.md` are tracked and hand-maintained.
- A PreToolUse hook already exists: `bin/cc-hook-guard` (blocks `git commit/push` on work, `brew services nginx`, `rm -rf` home/root). zdots also has `cc-hook-lint` (PostToolUse) and `cc-hook-session` (SessionStart), wired in `.claude/settings.json`.

Graphify's PreToolUse hook injects graph context before tool calls. Two hooks on the same event must **chain**, not clobber. So: design the wiring, don't let `claude install` overwrite.

## Recommended wiring

**1. Graph context, not auto-injection.** Rather than a PreToolUse hook that fires on every tool call (latency + token cost on a PHI box), expose graphify as **slash commands** the operator/agent calls deliberately. The graph is a queryable index, pulled on demand.

**2. Slash commands** (`.claude/commands/`, the existing skills dir):

| Command | Wraps | Use |
|---|---|---|
| `/graphify` | `graphify update .` then summary | (re)build the graph for the current repo |
| `/graphify query "<q>"` | `graphify query --budget 1500` | token-budgeted BFS answer from graph.json |
| `/graphify explain "<sym>"` | `graphify explain` | a node + its neighbors in plain language |
| `/graphify path "A" "B"` | `graphify path` | shortest dependency path between two symbols |
| `/graphify affected "<sym>"` | `graphify affected` | reverse impact (what breaks if I change this) |

Each is a thin shell wrapper → deterministic, local, ~1.4k tokens/answer.

**3. If you do want a hook**, make it a **SessionStart** addition (not PreToolUse): on session start, if `graphify-out/graph.json` is stale vs `git rev-parse HEAD`, print a one-line "graph stale — run /graphify" nudge. Fold this into the existing `bin/cc-hook-session` (append after `pi-ctx-brief`) so there is still exactly one SessionStart hook. Never add a second PreToolUse matcher that could shadow `cc-hook-guard`.

**4. CLAUDE.md** — add a short "Code graph" subsection by hand (not via `claude install`): "Before broad code reads, try `/graphify query` / `/graphify affected` — 130× fewer tokens than reading files. Graph is local (`graphify-out/`, gitignored), rebuilt with `graphify update .`."

## Graph caching

- `graph.json` is committed-out (gitignored); rebuild is **1.8s** so caching across sessions is cheap.
- `graphify check-update <path>` is cron-safe — a `zsvc`/launchd or git post-commit hook can flag staleness.
- `built_at_commit` in graph.json lets the SessionStart nudge compare against HEAD.

## Use cases (validated against zdots)

| Use case | Command | zdots evidence |
|---|---|---|
| Onboarding | `/graphify query "what are the core abstractions"` | 105× token cut; surfaces hub docs/modules |
| Dependency tracing | `/graphify affected "assert_local!"` | exact: 5 AI-pipeline callers found |
| Architecture discovery | `/graphify explain "<service>"` + God Nodes report | found AI-pipeline + crypto call edges |
| Rails debugging | `/graphify path "Controller#x" "Model.y"` | (projection — see Rails strategy) |
| K8s analysis | graph over `*.yaml`/HCL (tree-sitter-hcl) | grammar present; design in Rails strategy |

## Guardrails (PHI)

- Slash commands run `graphify` (local binary) only — no cloud. Keep it that way: do **not** set cloud API keys for the community-`label` step; use `--backend openai` → llama.cpp if labels are wanted.
- `graphify-out/` is gitignored — never commit a graph of a sensitive repo.
- On a work machine, the same help-only posture applies: query the graph, don't let graphify's `*-install` commands rewrite tracked files.
