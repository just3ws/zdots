# Graphify Local-First Strategy

Goal: persistent, queryable code graphs with **zero required cloud calls**, fast incremental rebuilds, and minimal operational complexity — consistent with zdots' local-first + PHI posture.

## Why it fits local-first cleanly

- Build + query are **100% local** (tree-sitter AST + networkx). Validated: 0 LLM tokens, 1.77s build on zdots.
- LLM is **opt-in** and only for community *naming* / deep semantic edges. When wanted, it routes to **llama.cpp** (`--backend openai`, `OPENAI_BASE_URL=http://127.0.0.1:11500/v1`) — never cloud.
- Output is a plain `graph.json` on disk — inspectable, diffable, scriptable.

## Cache policy

| Concern | Policy |
|---|---|
| Per-file AST cache | graphify caches by file; only changed files re-extract (`update` showed "uncached files (%)"). Keep `graphify-out/cache`. |
| Build artifact | `graphify-out/` is **gitignored** — regenerate, never commit (also avoids committing a graph of sensitive code). |
| Staleness signal | `graph.json.built_at_commit` vs `git rev-parse HEAD`; `graphify check-update` is cron/hook-safe. |
| Cross-repo | `~/.graphify/global-graph.json` via `graphify global add` — a persistent multi-repo index (zdots + tooling now; app + wiki later, on that machine). |

## Incremental rebuild

```sh
graphify update .          # re-extracts only changed files (fast)
graphify check-update .    # exits/notifies if a semantic re-extract is pending
graphify watch .           # optional: rebuild on file change (dev loop)
```

Wire a **git post-commit hook** (`graphify hook install`, or fold into zdots' own hook policy) so the graph tracks HEAD with no manual step. Build is fast enough (~2s) that post-commit is cheap.

## graph.json reuse

- One graph per repo at `<repo>/graphify-out/graph.json`; all query verbs (`query/path/explain/affected/benchmark/tree`) read it.
- Agents (Pi/Aider/Claude) read the **same** file — single source of truth, no per-agent re-index.
- `merge-graphs` / `global add` build a federated graph for cross-repo questions without re-parsing.

## Minimal LLM calls

- Default workflow uses **none**. Treat naming as a luxury: `cluster-only --no-label` keeps communities numbered.
- If labeling: do it **on demand** for a single community, `--max-concurrency 1`, local model. Avoid bulk-labeling 400+ communities on a 4B model (slow, low value).

## Local query workflows (the daily driver)

| Question | Command | Cost |
|---|---|---|
| What calls/breaks if I touch X? | `graphify affected "X"` | ~local, instant |
| How does A reach B? | `graphify path "A" "B"` | instant |
| What is X? | `graphify explain "X"` | instant |
| Where is <feature>? | `graphify query "<q>" --budget 1500` | ~1.4k tokens |
| What are the hubs/risks? | God Nodes + Import Cycles in `GRAPH_REPORT.md` | free |

## Operational footprint

- One binary (pipx), one gitignored output dir, ~2s rebuilds, no daemon required (`watch` optional, not a service).
- No new launchd service, no container, no DB required (Postgres/Neo4j persistence are optional extras). **This is the opposite of the LGTM-style operational weight** just removed in Z-134 — a good sign for "minimal operational complexity."
