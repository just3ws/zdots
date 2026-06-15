---
id: decision-008
title: Command-Surface DSL — zdots <noun> <verb> --json contract
date: '2026-06-15 01:48'
status: proposed
---
## Context

The command surface has **88 binaries, 33 of them `zdots-*`**. Those hyphens are a
*fake namespace*: `zdots-ctl`, `zdots-ctx`, `zdots-doctor`, `zdots-status`,
`zdots-config`, `zdots-logs` all read as `zdots <noun>`, but **no bare `zdots`
dispatcher exists**. CLAUDE.md and AGENTS.md already document `zdots doctor` and
`zdots-ctl status` as if the grammar were real — the docs describe a DSL the
binaries have not grown into. That gap is the felt incoherence: too many entry
points, insufficiently composable, gaps and burrs in the syntax.

The AI surface is the worst site: `ai-query`, `zdots-ask`, `zai`, `zpi`, `zaider`,
`llama-ctl`, `llama-caps`, `llama-mcp`, `pi-ctx-{query,hydrate,status,brief}` —
nine-plus front doors to one capability.

The substrate for composition already exists: **30 commands emit `--json`/`--plain`**.
The pieces of a DSL are present; what is missing is the grammar that names them as
one language. Traversing `backlog sequence` produced no insight on completing the
CLI syntax because the unification work was never a node — it is the implicit
Wave-0 substrate under every task, never filed.

## Decision

Adopt one canonical grammar for the platform command surface:

```
zdots <noun> <verb> [--json]
```

**Invariants (the contract):**

1. **Noun = domain, verb = action.** Nouns name domains (`ctl`, `ctx`, `svc`,
   `task`, `doctor`, `ai`, `config`, `phi`, `ruby`, …). Verbs name lifecycle/query
   actions (`up`, `down`, `status`, `check`, `query`, `hydrate`, `start`, `done`).
2. **`--json` on every leaf.** Machine-readable output is the composability seam —
   one output contract, pipeable, agent-readable. `--plain` for AI-text where JSON
   is wrong-shaped.
3. **Short aliases are preserved, not removed.** `zsvc`, `ztask`, `cl`, `zpi`
   remain the *accessible* front doors (wu wei — the right action stays the most
   obvious one) but resolve to the same grammar underneath. Ergonomics are kept;
   a backbone is gained.
4. **`zdots task` makes the backlog→done statechart a first-class noun** — the
   pipeline stops being a parallel tool (`ztask` + `backlog`) and becomes a verb in
   the same language as everything else.
5. **Convergence over proliferation.** The 33 flattened `zdots-*` binaries are
   convergence *targets* for the dispatcher, migrated by kaizen — not a rewrite.
   New capabilities are added as nouns/verbs under the spine, never as a new
   top-level binary.

The dispatcher (`bin/zdots`, task **Z-149**) is the additive Wave-0 root: it
resolves `zdots <noun>` to the existing `zdots-<noun>` binary (or alias) with arg
passthrough. Every current entry point keeps working; the grammar becomes real and
the docs stop lying.

## Consequences

- **Z-149 becomes the new Wave-0 root** in the dependency graph (doc-003): the
  substrate the 33 `zdots-*` binaries converge into. The graph can finally surface
  "complete the CLI syntax" as the foundation it always was.
- **Docs must be reconciled to the grammar** (CLAUDE.md, AGENTS.md): every command
  example becomes a real, dispatchable invocation — no fictional `zdots doctor`.
- **The AI-surface collapse** (`zdots ai <query|ask|chat>`) and the alias policy
  are follow-on design under this contract, not settled here.
- **Sister disease flagged:** AGENTS.md §9 references `GLOSSARY.md`/`ONTOLOGY.md`
  that **do not exist** — the vocabulary contract is fictional in the docs the same
  way the command grammar was. Addressed by the Knowledge Ingestion & Terminology
  contract (decision-009).
- **Reversible:** purely additive. If the grammar proves wrong, the dispatcher is
  deleted and the binaries stand alone again.
