# ROUTER.md

Design doc for the `zai` engine router — the integration layer across the local
LLM, Pi, Aider, Claude Haiku, and Claude Code.

**Status:** Phase 1 IMPLEMENTED (2026-06-05) — `zai` routes local/Pi/Aider with a
local advisory classifier, `--dry-run`, and trace logging; `--haiku` and
`--claude-code` are declared but refuse pending Phases 2–3. Implementation:
`providers/tools/router.zsh`, lazy stub in `conf.d/95-ai.zsh`, completion
`functions/enabled/_zai`, tests `tests/zai_router.bats`. Phases 2–4 remain
design-only below.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for architecture, performance
standards, **RTK token rules**, and **PHI Operating Mode** (Section 8). The
router is subordinate to the AI boundary in [lib/ai_boundary.bash](lib/ai_boundary.bash);
it never relaxes the gate.

## Why

Today engine selection is implicit — you pick by which command you type
(`ai`, `zdots-ask`, `zpi`, `zaider`, `cl`). The local LLM, Pi, and Aider all
run against llama.cpp; Claude Code (`cl`) is a separate island with no PHI
scrub; and `ZDOTS_AI_MODE=cloud` is a gate state with **no consumer** — nothing
wires Anthropic. `zai` adds one thin, explicit dispatcher that keeps the local
LLM as the default while making escalation deliberate, scrubbed, and logged.

## Non-negotiable constraints

- **Local LLM stays the default.** No flag → local inference. Always.
- **No silent escalation.** External engines (Haiku, Claude Code) require an
  explicit flag *and* an interactive confirm. They are never a fallback.
- **Haiku is the ceiling.** No Sonnet/Opus auto-selection from the router.
- **One scrub chokepoint.** Any external call routes through
  `zdots_ai_infer_raw` / `bin/ai-query`, inheriting normalize → PHI scrub →
  size ceiling. Nothing reaches a cloud model unscrubbed.
- **Pi and Aider stay local-only.** They read whole files with their own tools;
  never give them a cloud endpoint or they ship repo contents off-box.
- **Small, reversible, native zsh.** No framework, no new runtime deps for
  Phases 1–2. Lazy-loaded exactly like `zpi`/`zaider`.

## Interface

```
zai [ENGINE] [--dry-run] "task"

ENGINE (optional; default = local):
  --local         local llama.cpp via zdots_ai_infer_raw          (default)
  --pi            hand to zpi      — explore / read / plan         (local)
  --aider         hand to zaider   — edit / patch / commit         (local)
  --haiku         Claude Haiku via ai-query   (cloud + confirm + scrub)
  --claude-code   hand a scrubbed brief to cl  (cloud + confirm)

  --dry-run       print the routing decision + system prompt; no inference
```

### Default behaviour (no engine flag)

1. Run a **local advisory classifier** (small 8B call) that prints a one-line
   recommendation, e.g. `zai: this looks like a multi-file refactor → consider --claude-code`.
2. **Execute locally anyway.** The recommendation is advice, not an action. The
   only way an external engine runs is an explicit flag. This is the
   "no silent escalation" rule made concrete.
3. Log `engine=local model=… intent=…` via `zdots_trace_log`.

> Decision (2026-06-05): the classifier **uses a local inference call** rather
> than keyword-only heuristics — better intent detection is worth ~1–3s and one
> local 8B call, and it costs nothing externally. Make it skippable with
> `ZAI_NO_CLASSIFY=1` for latency-sensitive scripted use.

## Routing policy

| Task shape | Engine | Why |
|---|---|---|
| Summarize shell output, classify files, explain a snippet, generate a simple command, rewrite text, low-risk automation | **local** | Cheap, private, fast enough. The default. |
| Shell-oriented coordination, local system interrogation, small workflow automation, context lookup | **`--pi`** | Pi's read/bash/explore tools, local. |
| Repo-aware edits, test-driven changes, scoped refactors, patch generation | **`--aider`** | Aider mutates + commits, local. |
| Medium reasoning, ambiguous shell/repo triage, summarizing larger context, planning edits before Aider | **`--haiku`** | More headroom than 8B without going heavyweight. Cloud + confirm. |
| Complex multi-file investigation, Rails/Postgres/Kubernetes debugging, architecture analysis, full dev workflow | **`--claude-code`** | Heaviest reasoning; interactive session. Cloud + confirm. |

Pi ↔ Aider boundary is unchanged from [PI.md](PI.md): **Pi reads and reasons,
Aider writes and commits.** `zai --pi` then `zai --aider` is the same workflow,
just funneled through one entrypoint with logging.

## Security model

The router adds **zero** new bypass of the boundary. It composes existing gates:

1. `zdots_ai_gate_check` — `ZDOTS_AI_MODE=none` blocks everything (inherited).
2. `zdots_assert_local_endpoint_check` — local mode still forbids non-local
   endpoints for the local/Pi/Aider paths.
3. **`zdots_ai_confirm_external TOOL`** *(new, Phase 2)* — interactive y/N +
   audit log. Required before `--haiku` and `--claude-code`. Distinct from the
   locality assert: this guards *intent to leave the box*, not endpoint shape.
4. External engines require `ZDOTS_AI_MODE=cloud`. In `local`/`none` mode,
   `--haiku`/`--claude-code` refuse with a clear message — no silent downgrade
   to local, no silent escalation to cloud.
5. PHI scrub (`zdots_message_hygiene`) runs on every prompt that crosses to a
   cloud model. Connection strings still fail hard.

### Risks this design must hold the line on

- **R1 — Claude Code is unscrubbed today.** `--claude-code` must hand `cl` a
  *scrubbed brief*, not raw repo files. It does not auto-attach files.
- **R3 — context size to cloud.** `--haiku` inherits `AIQ_MAX_BYTES` (32KB).
  Pi/Aider never get a cloud endpoint, so whole-file reads stay local.
- **R5 — runaway cost / silent escalation.** External is opt-in per invocation,
  confirmed, and logged. No automatic retry-on-cloud.
- **R7 — models.json drift.** Adding the Anthropic transport lives in
  `bin/ai-query`, **not** in Pi's `~/.pi/agent/models.json`. Pi stays
  llama.cpp-only; no new sync burden on that file.

## Planned files (when built)

| File | Change | Phase |
|---|---|---|
| `providers/tools/router.zsh` | new — `zai()`, `_zai_classify()`, dispatch | 1 |
| `conf.d/95-ai.zsh` | register lazy `zai` stub (mirror `zpi`/`zaider`) | 1 |
| `lib/ai_boundary.bash` | add `zdots_ai_confirm_external` | 2 |
| `bin/ai-query` | add `--model haiku` Anthropic transport, gated | 3 |
| `bin/zproj-health` | new — read-only Rails/Docker/k8s/PG summary | 4 (stretch) |
| `tests/` | router smoke test (dry-run asserts engine; refuses cloud when MODE≠cloud) | each phase |

## Phased rollout

- **Phase 1** — ✅ DONE. `zai` with `--local/--pi/--aider`, local advisory
  classifier, `--dry-run`, engine logging. No cloud, no new deps. Pure rewiring.
- **Phase 2** — `zdots_ai_confirm_external` + `--claude-code` scrubbed handoff.
- **Phase 3** — `--haiku` backend in `ai-query` behind `cloud` + confirm +
  scrub. Reads `ANTHROPIC_API_KEY` from Keychain (already tracked by
  `zdots-keychain`). Capped at Haiku.
- **Phase 4 (stretch)** — `zproj-health`: Gemfile Ruby/Rails versions,
  Dockerfile/compose/Colima detection, k8s manifest glob, `bin/dev`/rake/
  rspec/rubocop presence, Postgres reachability **without printing
  credentials**. Pure inspection, feeds a scrubbed brief to the chosen engine.

Each phase is independently revertible (delete the file / drop the stub).

## Cross-references

- [PI.md](PI.md) — Pi usage, the Pi↔Aider boundary, context budget.
- [AIDER.md](AIDER.md) — Aider usage and capability limits.
- [CLAUDE.md](CLAUDE.md) — Claude Code session conventions.
- [lib/ai_boundary.bash](lib/ai_boundary.bash) — the gate this router obeys.
- [lib/ai-invoke.bash](lib/ai-invoke.bash) — the scrub/inference chokepoint.
- [bin/ai-query](bin/ai-query) — hardened CLI; future home of the Haiku transport.
