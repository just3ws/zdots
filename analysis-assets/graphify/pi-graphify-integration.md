# Pi × Graphify Integration

Pi is the local explore/plan agent (read-only, wired to llama.cpp at `:11500`). Graphify gives Pi a **persistent structural index** so its planning is grounded in the real call graph instead of re-reading files each turn.

## Install surface

`graphify pi install` writes a skill to `~/.pi/agent/skills/graphify/` — additive and untracked, so it is safe to run (unlike the Claude/Aider installers that edit tracked `CLAUDE.md`/`AGENTS.md`). It teaches Pi when to call graphify and how to read its output.

## Designed workflows

| Workflow | Mechanism | Notes |
|---|---|---|
| **graph build** | `graphify update <repo>` | local, no LLM, ~2s; run once per repo |
| **graph refresh** | `graphify check-update` + `graphify update` | incremental (caches per-file AST); cron/post-commit safe |
| **graph query** | `graphify query "<q>" --budget N` | Pi feeds the ~1.4k-token answer into its context instead of `repomix` of the whole tree |
| **hotspot detection** | God Nodes section of `GRAPH_REPORT.md` | most-connected symbols = refactor/risk hotspots |
| **ownership mapping** | community clusters + `source_file` | each community ≈ a subsystem; map to owners/dirs |
| **dependency discovery** | `graphify affected "<sym>"` / `path "A" "B"` | exact reverse/forward deps (validated: `assert_local!` → 5 callers) |

## Local LLM enrichment (keep llama.cpp)

Community naming (`label`) and deep semantic edges (`extract --mode deep`) are the only LLM-using steps. Configure them for llama.cpp, never cloud:

```sh
# OpenAI-compatible backend pointed at the local server
OPENAI_BASE_URL=http://127.0.0.1:11500/v1 OPENAI_API_KEY=local \
  graphify label . --backend openai --max-concurrency 1
```

`--max-concurrency 1` is graphify's own recommendation for local LLMs. With the
work-light 4B model this is slow over 419 communities — prefer labeling **on demand**
(a specific community) or skip naming (`cluster-only --no-label`) for routine use.

## Pi session ritual

1. `graphify update .` (or rely on the post-commit refresh).
2. Pi answers "where does X live / what calls Y / what would Z break" from `graphify query`/`affected` — token-bounded, no full-tree reads.
3. Pi plans the change; hands a graph-aware task to Aider.

## Boundary

Pi stays read-only. Graphify here is a **read** capability (index + query). No graphify `*-install` that mutates repo files should run from a Pi planning session — building/refresh (`update`) is the only write, and only to the gitignored `graphify-out/`.
