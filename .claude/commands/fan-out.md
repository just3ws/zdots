---
name: fan-out
description: Dispatch parallel work the right way — LOCAL LLM FIRST, then the smallest cloud subagent that fits, with worktree isolation for code, diff-review before merge, and two-signal verification. Use when batching backlog tasks, parallelizing independent work, or whenever tempted to spawn a subagent. Encodes the ROUTER.md local-first law for agent dispatch.
---

# /fan-out — dispatch work at the right altitude, local-first

Spawning a cloud subagent is the **expensive, PHI-leaking** path: it costs
tokens and it bypasses the local `phi_scrub`/`ai_boundary` pipeline. The
platform law (ROUTER.md) is *local LLM is the default; escalation is
deliberate.* This skill applies that law to **how you fan work out** — so the
default answer to "spawn a subagent?" is first "can a local tool do this?"

Usage: `/fan-out <batch or task>` — plan and dispatch · `/fan-out audit` —
report what a proposed batch should route where, without dispatching.

## Step 0 — Can a LOCAL tool do this? (ask before every spawn)

The local stack runs on-box (127.0.0.1:11500), PHI-safe, no cloud tokens.
Reach here FIRST. Confirm it's up: `curl -sf http://127.0.0.1:11500/v1/models`.

| Task shape | Local tool | Note |
|---|---|---|
| Classify / extract / transform / summarize text | `ai-query "task"` or `cmd \| ai-query "task"` | scripted; normalize→PHI-scrub→size-ceiling built in |
| Domain Q&A, draft prose, prompt routing | `zdots-ask "prompt"` | domain-aware local router |
| Edit / patch / commit within a repo | `zaider` (or `laid` = nice+19) | whole-file, local-only, never give it a cloud endpoint |
| Explore / read / plan a codebase | `zpi` | local; reads files with its own tools |

If the 14B local model can do it reliably AND the data is PHI-adjacent, it
**stays local**. Bulk NL grunt-work (summarize N logs, classify M commands,
extract fields) is exactly what the local model is for — do not burn a cloud
subagent on it.

## Step 1 — If it needs a cloud subagent, right-size it

Escalate only for what the local model genuinely can't do: multi-file
reasoning, architecture, nuanced security tradeoffs, ambiguous scope. Then pick
the **smallest** model that fits (kaizen / wu wei — the right option is the
least one that works):

| Model | Use for | Examples this lineage |
|---|---|---|
| **haiku** | mechanical, single-axis, verifiable | doc-edit, registration, syntax fix (mmdc), find-replace, AC bookkeeping |
| **sonnet** | multi-file code leaf with tests | a backlog code task: implement + bats + run green |
| **opus** | architecture, security calibration, judgment, cross-cutting | scanner weight calibration (Z-041), contract design, ambiguous tradeoffs |

When unsure between two tiers, try the lower first; promote only on evidence it
underperformed. Do not default to sonnet/opus out of habit — that is the same
"reach for the expensive path" reflex this skill exists to break.

## Step 2 — Isolation and boundaries

- **Code task → `isolation: worktree`.** Parallel agents on isolated copies, no
  conflicts. **Read-only audit/eval → no worktree** (it only reports).
- **Agents touch code only.** The operator owns the board: agents must NOT edit
  `backlog/` task files. You (the parent) do AC checks / status on main after
  merge — the board-on-main rule.
- **PHI:** a cloud subagent prompt bypasses the scrub pipeline. Never paste
  secrets/PHI/keys into a spawn prompt. Hand it file paths, not contents.

## Step 3 — Review before merge (never trust a clean report)

Diff-review every agent's output for overreach before cherry-picking to main.
This lineage caught: an agent that gutted detection weights for all callers; an
agent that replaced two phantom *files* with a phantom *command*; an agent that
reported tests green it never had. The discipline:

1. Read the actual `git diff` — not the agent's summary of it.
2. **Verify the load-bearing claim with an INDEPENDENT signal.** Re-run the
   test/build/probe yourself.
3. **Two-signal rule — false greens AND false reds both happen.** An agent
   "passes" can be fabricated; your own probe can be the broken one (e.g.
   `mmdc -o /dev/null` fails on output-format inference, not on parse — a false
   RED). When two signals disagree, find which is wrong before acting on either.
4. Discard overreach; merge only what the task scoped. A locally-correct diff
   that weakens an unseen caller is still a regression.
5. `bin/secret-scan` before any commit. Mark the task Done on the board only
   after the merge is verified green in the main tree.

## Step 4 — Drain the worktrees

Prune merged/discarded worktrees (`git worktree remove --force <path>` +
`git branch -D`). Before pruning, rescue any orphan file the agent left — but
if the target already exists on main as a tracked, newer superset, do NOT
clobber it (filesystem doctrine: verify the target before any hard-to-reverse
op).

## Rules

- Local-first is not a suggestion. The cheapest, safest, fastest inference is
  the one that never leaves the box. Spend cloud tokens only on what needs them.
- No silent cloud escalation (ROUTER.md). Right-size deliberately, log what went
  where, report the tally.
- One verified merge beats three optimistic ones. Land the open thread before
  opening the next (doc-005 R3).
- Few word do trick — terse spawn prompts with the verified facts handed in, so
  the agent doesn't re-derive context cold (the expensive path).
