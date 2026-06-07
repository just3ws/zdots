# Rails × Graphify Strategy

Scope note: app is a Rails app on another machine and is **out of scope for execution** here (no app content in prompt context). This strategy is a grounded projection from (a) graphify's validated Ruby AST behavior on `lib/zdots/` and (b) graphify's declared grammar/feature set. Run the benchmarks locally on app to confirm.

## Why Rails inverts the zdots result

On zdots the graph was 74% documents / 9% call-edges, because zdots is bash+docs. A Rails monolith is the opposite: mostly **Ruby**, which graphify parses with `tree-sitter-ruby` into method-level `defines`/`calls`/`method`/`inherits`/`includes` edges. The validated zdots Ruby subset already produced exact call edges (`gate→assert_local!`, `vectorize→embed_client`, `encrypted_attribute→current_key`) and exact reverse-deps (`affected "assert_local!"` → 5 callers). At Rails scale that becomes a real cross-cutting call graph: controllers → services → models → jobs.

## Capability map (honest)

| Rails surface | Graphify coverage | How |
|---|---|---|
| Models, services, POROs | **Strong** (Ruby AST) | classes/methods/`calls`/`inherits`/`includes` |
| Controllers → service → model flows | **Strong** | `path "Foo#create" "Order.charge"`, `affected` |
| Sidekiq workers | **Strong** (they're Ruby classes) | `perform` call edges, `affected "SomeWorker"` |
| DB schema ↔ models | **Strong** | `extract --postgres "$DSN"` maps tables/views/FK into the same graph (column-level not represented) |
| Routes | **Weak/indirect** | `routes.rb` is Ruby (DSL), parsed as code but not resolved to controller actions; pair with `rails routes` |
| Docker / Compose | **Weak** (no Dockerfile/compose grammar) | indexed as documents (text), not structurally |
| Kubernetes manifests | **Weak** (no YAML grammar) | YAML → document nodes only; structural K8s analysis is not graphify's strength |
| GitHub Actions | **Weak** (YAML) | document-level only |
| Terraform | **Medium** | `tree-sitter-hcl` is available (resources/refs) |
| Wiki / Markdown docs | **Strong as navigation** | heading graph + `contains` (this is what dominated zdots) |

**Takeaway:** graphify is a **code (Ruby) + docs** graph. It is excellent for Rails app-logic correlation and wiki navigation; it is **not** a Kubernetes/Docker/GHA analyzer (those are YAML → text). For K8s, keep `kubectl`/`k9s` + a YAML-aware tool; graphify only ties their *names* in as document nodes.

## Compare / augment existing Ruby tooling

| Tool | What it gives | Graphify overlap / gap |
|---|---|---|
| `rails-erd` / `railroady` | model & association **ER diagrams** (DB-shaped) | graphify adds **behavioral** call edges (service→model→job) ER diagrams miss; ERD still better for pure association topology |
| `brakeman` | security taint analysis | **no overlap** — keep brakeman; graphify ≠ security scanner |
| `bundler-audit` | gem CVEs | no overlap — keep |
| `rubocop` | style/complexity per file | no overlap; graphify gives cross-file structure rubocop can't |
| `graphviz` | rendering | graphify emits its own `graph.html`/Mermaid (`export callflow-html`); graphviz optional |

**Verdict:** graphify **augments**, doesn't replace. It fills the gap none of the above cover: *fast, queryable, whole-app behavioral dependency graph* with token-bounded answers. Run it alongside `ruby-audit` (the zdots suite already wraps brakeman/rubocop/etc.).

## Recommended app workflow (to run there, local-only)

```sh
graphify update .                              # build Ruby call graph (no LLM)
graphify extract . --postgres "$DATABASE_URL"  # fold DB schema into the graph (local DB)
graphify affected "PatientsController#update"  # blast radius before a risky change
graphify path "BillingService" "Invoice"       # how billing reaches the model
graphify benchmark                             # confirm token reduction at app scale
```

All local. For community naming use `--backend openai` → llama.cpp, never cloud (PHI). Treat `graphify-out/` as sensitive (gitignore; never commit a graph of an EMR codebase).

## Forensic / legacy-archaeology value

For a legacy Rails monolith, the highest-value queries are `affected` (what breaks), `path` (how does A reach B), God Nodes (the untouchable hubs), and Import Cycles. These answer "what is this code and what depends on it" faster than reading — the core of legacy archaeology. This is the strongest argument for graphify on app.
