# Graphify Benchmarks

_Target: `~/.config/zsh` (zdots), commit `ebd6bc67`, 2026-06-07. Build: `graphify update .` (local, no LLM)._

bear3 / bear3.wiki / external repos were **not** benchmarked here — bear3 lives on another machine and the constraint is no bear3 content in prompt context. This audit benchmarks the local zdots repo; the Rails projections for bear3 are in `rails-graphify-strategy.md`.

## Build run — zdots

| Metric | Value |
|---|---|
| Runtime | **1.77s** wall (2.7s user, 10 workers), warm tree-sitter cache |
| Files scanned | 506 (402 code files extracted) |
| Corpus | ~264,725 words |
| Nodes | 2,745 |
| Edges | 2,509 |
| Communities | 419 (318 shown, 101 thin) |
| Extraction | 99% EXTRACTED (AST) · 1% INFERRED (21 edges, avg conf 0.8) |
| LLM token cost | **0** (no backend used) |
| Import cycles | none |
| graph.json | 1.8 MB · graph.html 1.8 MB · GRAPH_REPORT.md 72 KB |

## Token reduction (`graphify benchmark`)

| | |
|---|---|
| Naive full corpus | ~183,000 tokens |
| Avg graph query | ~1,400 tokens |
| **Reduction** | **130.7×** |

Per-question (BFS over graph.json):

| Question | Reduction |
|---|---|
| how does authentication work | 120.2× |
| what is the main entry point | 133.1× |
| how are errors handled | 248.6× |
| what connects the data layer to the api | 111.9× |
| what are the core abstractions | 105.5× |

## Graph composition — the important finding

The graph is **document-dominated**, because zdots is doc-heavy and graphify indexes markdown headings as nodes:

| Node `file_type` | Count | Share |
|---|---|---|
| document (markdown) | 2,030 | 74% |
| code | 715 | 26% |

| Edge relation | Count | Share | Meaning |
|---|---|---|---|
| `contains` | 2,007 | 80% | markdown heading nesting (doc structure) |
| `defines` | 265 | 11% | symbol definitions |
| `calls` | 155 | 6% | **actual call graph** |
| `method` | 75 | 3% | method membership |
| `requires_env` / `references` | 7 | <1% | env + refs |

Parsed code: **bash** (361 nodes: 191 functions, 48 entrypoints, 48 files) plus the **Ruby** under `lib/zdots/` (source of the `calls` edges). 

**Interpretation:** on zdots, ~80% of the graph is document structure and only ~9% of edges (`calls`+`method`) are a true code call-graph. So for zdots, graphify is mostly a **token-reduced documentation index** + a thin code call-graph over the Ruby/bash. The code call-graph is small here because bash yields few cross-function call edges and zdots' Ruby surface (`lib/zdots/`) is modest — this ratio inverts on a Rails app (see Rails strategy).

## Analysis outputs

**God nodes** (most-connected) — skewed to docs/test artifacts, confirming the doc-domination:
`ReportBuilder` (21), `Full Assertion API` (17), `_Test File Types:_` (17), `SliceBuilder` (16), `Detector` (15), `skills` (15), `SETUP.md` (15), `ai-query` doc (14), `Aider` doc (14).

**Surprising connections** (INFERRED, the genuinely useful code edges):
- `gate() → assert_local!()`  (`lib/zdots/ai/pipeline.rb` → `client.rb`)
- `vectorize() → embed_client()`  (pipeline → client)
- `encrypted_attribute() → current_key()`  (`models/encrypted_content.rb` → `crypto/key_store.rb`)
- `db() → connect()`  (`lib/zdots.rb` → `db.rb`)

**Query example** — `affected "assert_local!"` (reverse call graph, exact):
`client()`, `embed_client()`, `gate()`, `infer()`, `vectorize()` — every AI-pipeline entrypoint routes through the local-only gate. This is the highest-value query type on zdots.

**Counter-example** — text `query "how does the PHI boundary work"` returned mostly SETUP.md / docs/aider.md / decision-002 headings, not the enforcing code (`lib/ai_boundary.bash`, `lib/phi_scrubber.bash`). Bash enforcement logic isn't surfaced by semantic text query; `affected`/`path` over symbols is.

## Takeaways for zdots usage

1. **Scope matters.** For code understanding, build over `lib/ bin/` (or exclude `docs/ backlog/`) so doc headings don't dominate god-nodes and queries.
2. **Best query types here:** `affected`, `path`, `explain` over symbols (precise, structural). Text `query` is better as doc navigation.
3. **Token reduction is real** (130×) and free (0 LLM).
4. **Community naming** needs an LLM — point `label --backend openai` at llama.cpp to keep it local (419 communities are unlabeled until then).
