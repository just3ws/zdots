# Graphify — Final Assessment

_2026-06-07 · evaluated locally against `~/.config/zsh` (zdots); Rails/bear3 projected (remote, design-only)._

## One-line verdict

Graphify is a **low-cost, local-first code-graph + token-reduction tool worth adopting** for the Pi/Aider/Claude workflow — strongest as a **structural query layer over Ruby code** (so it will pay off most on bear3/Rails) and as a **token-reduced documentation index**. It is **not** a Kubernetes/Docker/CI analyzer and not a security scanner; keep existing tools for those.

## Strengths

- **Genuinely local.** Build + query need no network and no API keys (validated: 0 LLM tokens, 1.77s on zdots). LLM is opt-in and routes to llama.cpp.
- **Real token reduction.** 130.7× fewer tokens/query vs naive corpus, free. Directly helps small local models (Aider/Pi) and cloud-billed Claude.
- **Precise structural queries.** `affected`/`path`/`explain` over symbols are exact and fast (validated: `assert_local!` → its 5 callers; cross-file INFERRED edges in the AI/crypto pipeline).
- **Minimal operational footprint.** One pipx binary, one gitignored dir, ~2s incremental rebuilds, no daemon/container/DB required.
- **Broad parser set + integrations.** ~30 tree-sitter grammars; first-class installers for Claude/Pi/Aider/Codex/OpenCode; MCP + Postgres/Neo4j extras.

## Weaknesses

- **Doc/markdown domination on doc-heavy repos.** On zdots, 74% of nodes were docs and 80% of edges were heading-`contains`; God Nodes were dominated by doc/test artifacts. Needs scoping (`lib/ bin/`, exclude `docs/ backlog/`) for code focus.
- **Text `query` is shallow on non-Ruby code.** "How does the PHI boundary work" returned doc headings, not the enforcing bash. Bash yields thin call graphs. Value concentrates in AST-rich languages (Ruby, JS/TS, Go…).
- **Infra-as-YAML blind spot.** No YAML grammar → K8s/Compose/GHA are document-level only. Not a substitute for `kubectl`/`k9s`/yaml tooling.
- **Community naming needs an LLM** and is slow on a small local model across hundreds of communities; treat as on-demand.
- **Ecosystem hygiene:** the `*-install` commands rewrite tracked `CLAUDE.md`/`AGENTS.md` and add a PreToolUse hook — must be wired manually to coexist with `cc-hook-guard`. Also found a pre-existing drift copy in the mise python.

## Costs & burden

| Dimension | Assessment |
|---|---|
| Install/operational cost | **Very low** — pipx, no service, ~2s builds |
| Maintenance burden | **Low** — pin via pipx; refresh graph on post-commit; one drift copy to remove |
| Token-reduction value | **High** — 130× measured; compounds across agents/sessions |
| LLM/cloud cost | **Zero by default**; local-only when labels wanted |

## Suitability

| Target | Rating | Why |
|---|---|---|
| **Rails monoliths (bear3)** | **High** | Ruby AST → controller→service→model→Sidekiq call graph; `affected`/`path` for blast-radius; `--postgres` folds schema in. Augments (not replaces) rails-erd/railroady/brakeman/rubocop. |
| **Legacy archaeology** | **High** | God Nodes, Import Cycles, `affected`, `path` answer "what is this / what depends on it" without reading. |
| **Kubernetes / infra** | **Low** | YAML is document-level; use k8s-native tools. |
| **zdots itself** | **Medium** | Great for the Ruby subset + doc navigation + token-reduced Q&A; thin as a bash call-graph. |

## Does it beat existing Rails tooling for understanding the codebase?

**It complements, and adds something none of them have:** a fast, queryable, *behavioral* whole-app dependency graph with token-bounded answers. rails-erd/railroady show DB associations; brakeman/bundler-audit/rubocop do security/style. None answer "what calls this / what breaks if I change it / how does A reach B" across the whole app in ~1.4k tokens. That gap is graphify's value — and it is exactly the legacy/forensic question bear3 needs.

## Recommendation: make it permanent?

**Yes, as an opt-in query layer — not as an always-on hook.**

1. **Adopt** the pipx install; remove the mise-python drift copy.
2. **Wire** via slash commands (`/graphify …`) + a SessionStart staleness nudge folded into `cc-hook-session`. Do **not** run `claude install`/`aider install` (they rewrite tracked files / add a competing PreToolUse hook).
3. **Pi/Aider:** use `affected`/`path` to build minimal `/add` sets and ground planning — the biggest practical win for local small models.
4. **bear3:** run the local benchmark there (`rails-graphify-strategy.md`); expect a far richer call graph than zdots showed. Keep `graphify-out/` gitignored and LLM-local (PHI).
5. **Keep** brakeman/bundler-audit/rubocop/rails-erd/k8s tooling — graphify augments them.

Net: low risk, low cost, real token savings, and a structural-query capability that is most valuable precisely where you're headed (Rails/bear3 + legacy archaeology). Worth keeping.
