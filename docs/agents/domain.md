# Domain Docs

How engineering skills should consume this repo's documentation.

## Before exploring, read these

- **`AGENTS.md`** at the repo root — primary agent guide: architecture, protocols, tool selection, PHI rules, coordination model
- **`CLAUDE.md`** at the repo root — Claude Code-specific conventions and platform control
- **`docs/`** — supplementary docs (llama-cpp, otel, testing, quality rubric)

`CONTEXT.md` exists at the repo root — read it for the domain glossary. `docs/adr/` exists — check it before re-litigating architectural decisions.

## File structure

Single-context repo:

```
/
├── AGENTS.md         ← primary doc: architecture, conventions, rules
├── CLAUDE.md         ← Claude Code-specific overlay
├── docs/             ← service guides and standards
│   ├── agents/       ← skill configuration (this directory)
│   ├── llama-cpp.md
│   ├── otel-collector-guide.md
│   ├── testing.md
│   └── zsh-quality-rubric.md
├── lib/              ← zsh/bash library functions
├── bin/              ← user-facing scripts
├── conf.d/           ← zsh startup config (numbered 01-99)
├── db/migrations/    ← Sequel migrations
└── backlog/          ← task tracker
```

## Vocabulary (key terms)

- **zdots** — the repo itself; a zsh-based shell configuration and local dev platform
- **zdots-brain** — the Ruby CLI that owns DB access (`sbin/zdots-brain`)
- **zdots-ctx** — bash wrapper around zdots-brain; the primary intelligence suite interface
- **context-engine** — the Rails app that reads/writes the `my` PostgreSQL database
- **observable session** — a shell session with `ZDOTS_SESSION_ID` set; enables capture
- **PHI boundary** — the hard rule: all AI stays local, data scrubbed before inference
- **hydrate** — `zdots-ctx hydrate [tag]` fetches methodology context for an AI task

## ADRs

`docs/adr/` contains binding architectural decisions. Read relevant ADRs before proposing changes in their area.

| ADR | Title | Status |
|-----|-------|--------|
| [0001](../adr/0001-nginx-not-in-ai-query-path.md) | nginx is not in the CLI AI-query path | Accepted |
