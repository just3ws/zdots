# Aider × Graphify Integration

Aider is the local edit/commit agent (llama.cpp via `zaider`/`laid`). Its weak point on a 7B/8B local model is **context budget** — it can only hold a few files. Graphify's job here is to tell Aider *exactly which files/symbols matter* for an edit, so the small model spends its context on the right code.

## Install surface

`graphify aider install` writes a graphify section to **`AGENTS.md`** — a tracked, curated zdots file. Do **not** run it blindly; add a short hand-written note to `AGENTS.md` instead (see below). The capability is just the `graphify` CLI; no plugin is required for Aider.

## Designed workflows

| Workflow | Mechanism |
|---|---|
| **pre-index** | `graphify update .` before a session so the graph is fresh (~2s) |
| **graph-aware edits** | `graphify affected "<sym>"` → the exact set of callers to `/add` to Aider, nothing more |
| **graph-assisted refactor** | `graphify path "A" "B"` + `affected` → the full blast radius; `/add` only those files, `/drop` the rest |
| **graph-assisted onboarding** | `graphify query "where is <feature>"` → entry files to `/add` |
| **graph-assisted test gen** | `affected "<sym>"` → which call sites need tests; `explain` → the contract to assert |

## The core pattern: graph → `/add` set

Local Aider's context discipline (from `AGENTS.md`: `/add` only what you edit, `/tokens`, `/clear`). Graphify makes that selection precise:

```sh
# Want to change assert_local!()? Find its blast radius, add exactly those:
graphify affected "assert_local!"
#   → client(), embed_client(), gate(), infer(), vectorize()  (lib/zdots/ai/*)
# In aider:  /add lib/zdots/ai/client.rb lib/zdots/ai/pipeline.rb
```

This replaces "add the whole `lib/zdots/ai/` dir and blow the budget" with a 2-file, graph-justified context. On the validated zdots example that is the difference between fitting and overflowing a 7B window.

## AGENTS.md note (hand-add, don't `aider install`)

> **Code graph (graphify):** before adding files, run `graphify affected "<sym>"`
> or `graphify path "A" "B"` to get the minimal `/add` set. Graph is local
> (`graphify-out/`, gitignored), rebuilt with `graphify update .`. No cloud.

## Boundary & PHI

- Aider edits + commits, but graphify itself only reads + writes the gitignored `graphify-out/`.
- All graphify use stays local (no cloud backend). On a work machine the existing commit/push restrictions still apply via `cc-hook-guard`; graphify changes nothing there.
- For Rails/app the same pattern is far more powerful (rich Ruby call graph) — see `rails-graphify-strategy.md`.
