# Architecture Diagram Audit Plan

This plan turns the zdots codebase into a durable set of GitHub-rendered
Mermaid diagrams so humans and AI agents can reason about the system without
reconstructing architecture from scattered scripts.

GitHub renders Mermaid in Markdown, issues, pull requests, discussions, and
wikis. Before adding a new diagram type, verify it against the Mermaid version
GitHub currently runs and prefer stable Mermaid syntax over beta syntax unless
the beta diagram provides unique value.

References:

- GitHub diagram rendering: <https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams>
- Mermaid syntax reference: <https://mermaid.js.org/intro/syntax-reference.html>

## Goals

1. Make every important runtime relationship visible in versioned Markdown.
2. Give agents a canonical map before they edit infrastructure.
3. Use the right diagram type for the reasoning question, not one generic graph.
4. Keep diagrams close to source files and tests that prove the behavior.
5. Require render verification in GitHub before marking the diagram inventory done.

## Audit Inputs

Use these sources as the diagram ground truth:

| Source | What To Extract |
|---|---|
| `bin/` | CLI grammar, lifecycle commands, service manager calls |
| `lib/` | shared primitives, boundaries, contracts |
| `conf.d/` | shell hook order, interactive surfaces |
| `providers/` | dependency-injection bindings |
| `env.sh`, `.zdots.env`, `.zdots.work` | boot profile and environment flow |
| `etc/` | model config, PHI registry, managed config inputs |
| `db/migrations/`, `lib/zdots/` | Brain schema, jobs, credential paths |
| `tests/*.bats` | verified behavior and E2E coverage |
| `man/` | operator-facing command contracts |
| `docs/`, `docs/wiki/`, `backlog/` | current narrative, decisions, known gaps |

Recommended discovery commands:

```bash
rg --files bin lib conf.d providers etc db tests docs man backlog
rg -n "source |launchctl|curl|psql|redis|zdots-ctx|llama|otel|nginx|colima|traceparent|phi|capture|hydrate" \
  bin lib conf.d providers etc db tests docs man
```

## Mermaid Type Coverage

The audit should consider every Mermaid diagram family and either use it or
record why it is not useful for this repo.

| Mermaid Type | Use In zdots | Candidate View |
|---|---|---|
| `flowchart` / `graph` | Yes | service plane, command routing, PHI boundaries, bootstrap phases |
| `sequenceDiagram` | Yes | shell startup, `ztask start`, `zdots-ctx capture`, credential rotation |
| `classDiagram` | Yes | Ruby Brain classes, CLI facade contracts, service manager abstractions |
| `stateDiagram-v2` | Yes | service lifecycle, job broker lifecycle, task lifecycle, credential states |
| `erDiagram` | Yes | PostgreSQL Brain schema and analytics sync tables |
| `journey` | Yes | operator workflows: bootstrap, daily start, task pickup, incident isolation |
| `gantt` | Yes | rollout plan for config drift, PR promotion, CI hardening |
| `pie` | Maybe | test coverage distribution by subsystem; use only with measured counts |
| `quadrantChart` | Yes | risk/effort map for remaining architecture gaps |
| `requirementDiagram` | Yes | PHI safety requirements and service-readiness contracts |
| `gitGraph` | Yes | branch/PR lifecycle and task auto-commit behavior |
| `mindmap` | Yes | repo conceptual map and agent orientation tree |
| `timeline` | Yes | bootstrap/update/local platform lifecycle milestones; repository evolution |
| `C4Context` / C4 variants | Maybe | context/container/component views if GitHub supports current syntax |
| `sankey-beta` | Maybe | telemetry, command analytics, and context-flow volumes if data is available |
| `xyChart-beta` | Maybe | startup latency, token budget, queue depth over time |
| `block-beta` | Maybe | physical/runtime layout across macOS, LaunchAgents, Colima, Keychain |
| `packet-beta` | Rare | OTLP/HTTP or traceparent packet anatomy if useful |
| `architecture-beta` | Maybe | high-level service placement; already used in README, verify rendering |
| `kanban` | Maybe | backlog states if GitHub supports it; otherwise use flowchart/state |

If GitHub does not render a beta diagram, keep the reasoning view but translate
it to `flowchart`, `stateDiagram-v2`, or `sequenceDiagram`.

## Diagram Inventory To Produce

### Platform And Runtime

| Diagram | Type | Primary Files | Reasoning Question |
|---|---|---|---|
| Host/container topology | `flowchart` or `architecture-beta` | `bin/zdots-ctl`, `bin/zsvc`, `bin/openobserve-ctl` | What runs where? |
| Service lifecycle state machine | `stateDiagram-v2` | `bin/zsvc`, service ctl scripts | What states can a service occupy? |
| Startup orchestration | `sequenceDiagram` | `bin/zdots-ctl` | What starts first and why? |
| Registration vs health | `stateDiagram-v2` | `bin/zsvc`, tests | How can a service be running but unhealthy? |
| Local URL routing | `flowchart` | `bin/nginx-ctl`, `docs/local-url-routing.md` | Which hostname maps to which backend? |

### Shell And Environment

| Diagram | Type | Primary Files | Reasoning Question |
|---|---|---|---|
| Shell boot order | `sequenceDiagram` | `env.sh`, `.zshrc`, `conf.d/` | What loads before interactive code? |
| Provider injection map | `classDiagram` or `flowchart` | `.zdots.env`, `providers/` | Which implementation satisfies each service? |
| PATH construction | `flowchart` | `env.sh`, provider scripts | Why does a command resolve to this binary? |
| Hook execution order | `sequenceDiagram` | `conf.d/*` | What runs on `preexec`, `precmd`, history write? |

### AI, PHI, And Knowledge

| Diagram | Type | Primary Files | Reasoning Question |
|---|---|---|---|
| AI boundary | `flowchart` | `bin/ai-query`, `lib/ai_boundary.bash`, `lib/phi_scrubber.bash` | Can data leave loopback? |
| Prompt routing | `flowchart` | `bin/zdots-ask`, `etc/prompts/` | Which system prompt applies? |
| Capture pipeline | `sequenceDiagram` | `bin/zdots-ctx`, Brain code | How does session residue become knowledge? |
| Brain schema | `erDiagram` | migrations, `lib/zdots/` | Which tables own each concept? |
| Job broker lifecycle | `stateDiagram-v2` | migrations, job code | How do async jobs move and fail? |
| PHI safety requirements | `requirementDiagram` | `AGENTS.md`, PHI docs, checks | Which controls are mandatory? |

### Backlog, Agents, And Tasks

| Diagram | Type | Primary Files | Reasoning Question |
|---|---|---|---|
| Task lifecycle | `stateDiagram-v2` | `bin/ztask`, `backlog/config.yml` | How does task status change? |
| `ztask start` | `sequenceDiagram` | `bin/ztask`, `backlog`, `zdots-ctl`, `zdots-ctx` | What side effects happen on pickup? |
| Agent coordination | `journey` | `AGENTS.md`, `docs/agents/*` | What does an agent do from issue to PR? |
| Backlog auto-commit path | `gitGraph` | `backlog/config.yml`, `ztask` | How do task edits enter Git history? |

### Tests, Contracts, And Operations

| Diagram | Type | Primary Files | Reasoning Question |
|---|---|---|---|
| Test coverage matrix | `flowchart` or `mindmap` | `tests/*.bats`, `docs/testing.md` | Which suite proves which subsystem? |
| Live E2E path | `flowchart` | `tests/platform_e2e.bats` | What does "ready to run" mean? |
| Docs contract | `flowchart` | `tests/docs_contract.bats` | How do docs stay aligned with interfaces? |
| Incident isolation | `flowchart` | `docs/troubleshooting.md`, `docs/platform-service-plane.md` | What should an operator check first? |
| Remaining gap map | `quadrantChart` | backlog tasks, local-url-routing gaps | What is high-risk and cheap to fix? |

### Repository Evolution

| Diagram | Type | Primary Files | Reasoning Question |
|---|---|---|---|
| Repository evolution timeline | `timeline` | Git history, `docs/repository-evolution.md` | When did zdots become a platform? |
| Commit velocity histogram | `xyChart-beta` plus table fallback | Git history | Where are the modernization bursts? |
| Annual velocity table | Markdown table | Git history | How concentrated is current development? |
| Commit subject mix | `pie` | Git subject prefixes | What kind of work dominates history? |
| PR branch flow | `gitGraph` | Git branch history | How does this stability branch relate to main? |
| Diagram rollout plan | `gantt` | Backlog task Z-121, docs plan | What should be diagrammed next? |

## Execution Plan

1. Inventory current diagrams:

   ```bash
   rg -n "```mermaid|flowchart|sequenceDiagram|stateDiagram|erDiagram|architecture-beta" README.md docs docs/wiki backlog
   ```

2. Build a source-to-diagram matrix:
   - one row per subsystem
   - one column per useful Mermaid type
   - include source files and validating tests

3. Add or update diagrams in this order:
   - `docs/platform-service-plane.md`
   - `docs/repository-evolution.md`
   - `docs/architecture.md`
   - `docs/local-ai.md`
   - `docs/backlog.md`
   - `docs/testing.md`
   - `docs/wiki/System-Map.md`
   - targeted `man/` pages only when a diagram directly improves operator use

4. For every diagram, add nearby provenance:
   - source files reviewed
   - command/test that validates the behavior
   - date-sensitive or machine-local assumptions

5. Verify renderability:
   - run docs contract locally
   - inspect the PR on GitHub for Mermaid rendering
   - replace unsupported beta diagrams with stable alternatives

6. Keep AI memory current:
   - link this plan from `README.md`, `docs/documentation-system.md`, and `docs/wiki/System-Map.md`
   - file a Backlog task with this document as the implementation plan
   - add lessons/methodologies through `zdots-ctx` only after the plan is executed and proven

## Acceptance Criteria

- Every Mermaid type in the coverage table is marked `used`, `translated`, or `not useful`.
- Every major subsystem has at least one diagram and one linked validation source.
- GitHub PR rendering is checked for every added Mermaid block.
- Unsupported beta syntax is removed or translated to stable Mermaid.
- `docs/documentation-system.md` remains the canonical rule for keeping diagrams current.
