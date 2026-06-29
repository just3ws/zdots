---
name: docs-sync
description: Propagate a vocabulary, command-surface, or contract change coherently across the tiered AI-initializer family (AGENTS.md, CLAUDE.md, per-tool files, local prompts) and the narrative docs, then verify against docs-contract. The cross-cutting complement to /command-qc (which is per-command). Use after changing a term, a command grammar, or a contract; or with "audit" to report drift without fixing.
---

# /docs-sync — keep the documentation family coherent

`/command-qc` owns the surfaces a single command owes. This skill owns the
surfaces a *concept* owes. When a term, a command grammar, or a contract
changes, it lives in many files at once — and the reliable failure mode
(doc-005 R2) is that docs describe the intended state, slightly ahead of
what is built, in the present tense. This skill is the discipline that
keeps the family honest: change once, propagate by tier, verify against the
contract.

Usage: `/docs-sync <what-changed>` (apply) · `/docs-sync <what-changed> audit`
(report drift only).

## Cross-platform scope (zdots / adots / vdots / my)

This skill's tier model governs the **zdots** repo only. The peer repos differ — this
divergence is **ratified as intentional** (Z-153 AC#6; see `etc/docs-sync-manifest.yaml`
`cross_platform` section for the machine-readable record):

| Repo | Root initializer(s) | Notes |
|---|---|---|
| **zdots** | `AGENTS.md` + `CLAUDE.md` + per-tool files + `etc/prompts/*.md` | This skill's home |
| **my** (`~/my`) | `AGENT.md` (singular) + `HUMAN.md` | Intentional: singular agent, human-facing companion — not a typo |
| **adots** | no root initializer; `capabilities.sh`, profile, wiki | Intentional: home-dir config; no AI-session bootstrap needed |
| **vdots** | — | Named peer; not currently on disk |

**Three rules:**

1. **Local change, stay local.** A change scoped to one repo does not cross repo boundaries. This skill does NOT edit adots/vdots/my.
2. **Platform-wide change, propagate to ALL relevant peers.** Examples: imperial-CalVer version stamp (decision-007), `zdots <noun> <verb> --json` grammar contract (decision-008). File the equivalent issue in each peer repo and note the task IDs.
3. **Naming divergence is intentional — do not "fix" it.** Each repo uses the naming that fits its reader population. Do not rename files across repos. The convention is documented in `etc/docs-sync-manifest.yaml`.

## Step 0 — Classify the change (this picks the surfaces)

Do NOT touch every file. The change *type* selects the targets:

| Change type | Canonical owner | Propagates to |
|---|---|---|
| **Vocabulary / term** | `CONTEXT.md` | AGENTS.md §9 table · any `etc/prompts/*.md` that teaches the term · wiki glossary section. (When the concept registry from decision-009 exists, the registry is canonical — point at `zdots ctx concept`, do NOT write the fictional `GLOSSARY.md`/`ONTOLOGY.md`.) |
| **Command surface / grammar** | `AGENTS.md` §3 | CLAUDE.md · `docs/tooling.md` · `bin/agent-guide`. Defer the per-command surfaces (man, completion, help) to `/command-qc`. |
| **Contract / decision** | the `backlog/decisions/` file | AGENTS.md · the tier files it constrains · README.md only if user-facing |
| **Capability-tier behavior** | the ONE tier file that owns it | nothing else — see tier rule below |

## The tiered AI-initializer family

These are ranked by the capability of the reader. A change belongs at the
*lowest tier it is true for*, and only broadcasts upward when it is universal.

1. **`AGENTS.md`** — core contract, auto-imported into every session. Canonical
   for anything that binds all agents. Edit here first when the change is universal.
2. **`CLAUDE.md`** — Claude Code (frontier) specifics. Imports AGENTS.md, so do
   not duplicate what AGENTS.md already says — add only the frontier-only part.
3. **`PI.md` · `AIDER.md` · `GEMINI.md` · `ROUTER.md`** — per-tool initializers.
   Touch only the one(s) whose tool the change affects.
4. **`etc/prompts/zdots-{default,phi,ruby,shell}.md`** — the **local-model** system
   prompts (lowest tier). Terse, example-driven; the 7B model needs a worked
   example, not prose. A term or pattern lands here only if the local model must
   produce it (precedent: Z-093 added a zdash binding example + llama-ctl table).

**Tier rule:** never broadcast a frontier-only instruction down to the local
prompts, and never bury a universal contract in a single tool file. Mis-tiering
is how the family drifts.

## The narrative + automated surfaces

- **`README.md`** — human entry point. Hand-edited; update only when the change
  alters how a person first understands or installs the system.
- **`CHANGELOG.md`** — **automated. Do NOT hand-edit.** Always regenerate with
  `make changelog` (git-cliff over conventional commits) and commit the result if
  it changed. If your change deserves a changelog line, the fix is the *commit
  message*, not this file. The closing gate (step 4 below) always runs
  `make changelog` — never skip it.
- **`docs/wiki/*.md`** — published via `zdots-pages`. Edit content here; the tool
  publishes. Keep `Command-Reference.md` / `System-Map.md` current with grammar
  changes.
- **`docs/tooling.md`** — the full tool reference (shared with `/command-qc` §4).

## Closing gate (apply mode)

Run, in order — all must pass before reporting done:
1. `make docs-contract` — runs `tests/docs_contract.bats`. This now includes the
   fictional-reference linter (Z-153 AC#2), which reads the tier file list from
   `etc/docs-sync-manifest.yaml` (Z-153 AC#3) and fails on phantom `zdots-*`
   backtick references. No manual phantom scan needed — the linter covers it.
2. **Tier check** — re-read each file you touched and confirm the change is true
   at that tier (no frontier-only text in a local prompt; no universal contract
   stranded in one tool file). Consult `etc/docs-sync-manifest.yaml`
   `change_types` for the canonical propagation targets.
3. `make changelog` — always run this; commit the result if it changed. Never
   skip; never hand-edit `CHANGELOG.md`.
4. `bin/secret-scan` before any commit.

Then report a table: surface → touched / clean / n-a, one line each. Anything
skipped gets a reason in the table, not silence.

## Rules

- Do NOT commit or push — report and await the operator's word.
- Additive: these files have readers you cannot see. If a surface needs
  restructuring (not just updating), file `zdots-issue` (AGENTS.md §5).
- Do NOT invent the missing `GLOSSARY.md`/`ONTOLOGY.md` — terminology is data
  (decision-009 concept registry), not markdown. Point at the tool.
- Few word do trick: every initializer file is loaded at token cost by some
  agent. Dense beats long; a worked example beats a paragraph.
- This skill propagates an *already-decided* change. It does not decide
  vocabulary — that is `grill-with-docs` (planning) and CONTEXT.md (canon).
