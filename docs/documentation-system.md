---
id: documentation-system
title: "Documentation System"
purpose: Canonical documentation model for keeping live behavior, operator docs, manpages, wiki pages, and AI context aligned.
---

# Documentation System

Zdots documentation has one job: make the live system legible enough that a human operator and an AI agent can predict behavior before touching it.

## Authority

| Layer | Source | Purpose |
|---|---|---|
| Live state | `zdots-ctl status --json`, `capabilities --json`, `agent-guide --json` | What is true right now |
| Interface inventory | `docs/generated/interface-inventory.json` | Command, flag, env var, file, and risk index |
| Manpages | `man/` | Stable operator reference |
| Repo docs | `docs/` | Architecture, workflows, policy, troubleshooting |
| Evolution views | `docs/repository-evolution.md` | Git-derived timelines, histograms, velocity charts, and branch-flow context |
| AI context | `AGENTS.md`, `CONTEXT.md`, `PI.md`, inventory | Agent operating contract |
| Wiki source | `docs/wiki/` | Public handbook pages, versioned in this repo |
| Backlog | `backlog/` | Work state and known gaps |

Policy lives in `AGENTS.md`. Facts that can drift belong in generated or contract-checked files.

Live-state fields must expose provenance when they summarize another command. Disk space reports the `df -h /` `Avail` column, service health distinguishes HTTP readiness from socket presence, and trace-derived fields include age so stale context is visible.

Architecture diagrams are documentation contracts, not decoration. Use
[architecture-diagram-audit-plan.md](architecture-diagram-audit-plan.md) when
adding or reviewing Mermaid diagrams, and include source-file and validation
provenance near diagrams whose behavior can drift.

Repository evolution diagrams are architecture context when they explain why
the system changed shape. Keep [repository-evolution.md](repository-evolution.md)
aligned with `git log --all` whenever velocity, timeline, or branch-flow claims
are used to guide planning.

## Manpage Rules

Command pages go in section 1 unless they primarily administer services. Service/admin tools go in section 8. File formats and configuration live in section 5. Cross-command concepts live in section 7.

Every public command manpage should include:

- `NAME`
- `SYNOPSIS`
- `DESCRIPTION`
- `COMMANDS` or `OPTIONS`
- `ENVIRONMENT`
- `FILES`
- `EXIT STATUS`
- `EXAMPLES`
- `SEE ALSO`

Zdots-specific pages also include `PHI SAFETY`, `DESTRUCTIVE ACTIONS`, or `LIVE STATE` when those affect operator decisions.

## Help Rules

Every executable in `bin/` that is operator-facing must support `--help`.

Help output must document:

- usage
- commands and flags
- env vars that change behavior
- destructive behavior
- JSON output, if supported
- service dependencies, if relevant

`--help`, manpages, and the interface inventory must agree.

## Wiki Rules

`docs/wiki/` is the versioned source for the public wiki. The GitHub wiki may mirror it, but repo files win.

Wiki pages are for navigation, narrative, and operator workflows. They are not the canonical source for command contracts.

## Contract

Run:

```sh
make docs-contract
```

The contract checks that:

- core commands have working `--help`
- known help gaps are explicit
- manpages exist and render with `mandoc -Tlint`
- generated inventory exists
- wiki source exists
- live JSON probes are parseable when commands return success

Known gaps are tracked in `docs/generated/docs-contract-known-gaps.txt`.
