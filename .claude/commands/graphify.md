---
name: graphify
description: >
  Query the local code graph (graphify) instead of reading many files. Use for
  "/graphify", "/graphify query ...", "/graphify explain ...", "/graphify path
  ...", "/graphify affected ...", or when the user asks how code connects, what
  calls/depends on a symbol, the path between two symbols, or for a token-cheap
  architecture overview. Local-only (no cloud); ~130x fewer tokens than reading.
---

Use the local `graphify` code graph to answer structural questions cheaply.
Arguments: `$ARGUMENTS`

## Routing

Parse `$ARGUMENTS` and run the matching local command (all read `graphify-out/graph.json`):

| Input | Run |
|---|---|
| _(empty)_ or `build` / `update` | `graphify update .` (rebuild graph; local, no LLM, ~2s) |
| `query <question>` | `graphify query "<question>" --budget 1500` |
| `explain <symbol>` | `graphify explain "<symbol>"` |
| `path <A> <B>` | `graphify path "<A>" "<B>"` |
| `affected <symbol>` | `graphify affected "<symbol>"` |

## Procedure

1. If `graphify-out/graph.json` is missing in the repo, run `graphify update .` first, then the requested command. If it exists but the user said `build`/`update`, rebuild.
2. Run the single matching command above via the shell. Do not read large file sets to answer — the graph is the point (it is ~130x cheaper).
3. Summarize the result for the user: the key nodes/edges/path, with `file:line` references (graphify prints `src=… loc=…`). Keep it tight.
4. Prefer `affected`/`path`/`explain` (exact, structural) for "what calls / what breaks / how does A reach B". Use `query` for fuzzy "where is X / how does X work" — note that on doc-heavy repos `query` returns doc headings, so fall back to symbol queries for code.

## Rules

- **Local only.** Never set a cloud LLM backend. If community naming is ever needed, use `--backend openai` with `OPENAI_BASE_URL=http://127.0.0.1:11500/v1` (llama.cpp). Default workflow uses no LLM.
- `graphify-out/` is gitignored — never commit it; never build a graph of a sensitive repo into a shared location.
- Do **not** run `graphify claude install` / `aider install` — they rewrite tracked CLAUDE.md/AGENTS.md and add a competing PreToolUse hook.
