---
name: zdots
description: Operational context for working inside the zdots zsh configuration and local dev platform. Use when working in /Users/mike/.config/zsh, operating zdots tools, checking services, handling local AI/PHI boundaries, or following zdots project protocols.
---

# /zdots — Zdots Operational Context

You are working inside **zdots** — a zsh-based shell configuration and local dev platform.
Read `AGENTS.md` first. This skill adds operational detail for common tasks.

---

## Agent Roles

| Agent | Role |
|-------|------|
| Pi (`zpi`) | Explore, read, explain, plan — no file mutations |
| Aider (`zaider`) | Edit files, write code, commit — execution only |
| Claude Code (`cl`) | Architecture, review, multi-file reasoning |

Pi's output → Aider's input. Context budget (Pi, 7B): ~32k tokens per session.

---

## Key Commands

| Command | What it does |
|---------|-------------|
| `zdots-ctl status` | Live status of all services |
| `zdots-ctl up / down` | Start / stop everything |
| `zdots-ctl check` | Deep health diagnostic |
| `zdots-ctx hydrate [tag]` | Fetch methodology context by tag |
| `zdots-ctx query <term>` | Search methodology DB |
| `zdots-ctx add-methodology` | Add a methodology record |
| `zdots-ask "prompt"` | One-shot AI query via ai-query |
| `zdots-ask --context "prompt"` | Same, with hydrated methodology context |
| `llama-ctl status` | llama.cpp server status |
| `capabilities --json` | Environment contract |
| `agent-guide` | Full agent usage guide |

---

## Intelligence Suite

The local DB (`my` PostgreSQL) holds methodologies and lessons.
Access is via `zdots-brain` (Ruby Sequel) — never raw psql for writes.

**From Pi's bash tool, always use the `pi-ctx-*` wrappers** — they PHI-scrub inputs
and cap output to fit Pi's context budget. Never call `zdots-ctx` raw from Pi.

```bash
pi-ctx-status                          # KB counts + AI stack health
pi-ctx-hydrate                         # all methodologies, no tag filter
pi-ctx-hydrate shell                   # filter by tag "shell"
pi-ctx-query "Kevin's Law"             # full-text search
pi-ctx-query "database migration" --semantic   # vector search
```

Content is PGP-encrypted at rest. `zdots-brain` handles decrypt transparently.

---

## PHI Rules (non-negotiable)

1. `ZDOTS_AI_MODE=local` — all inference stays on device.
2. No patient record excerpts in any prompt.
3. `lib/phi_scrubber.bash` scrubs before any AI call.
4. `lib/ai_boundary.bash` blocks cloud egress.
5. Never store secrets in tracked files.

---

## Workflow Pattern

```bash
# 1. Hydrate context for current topic
zdots-ctx hydrate <tag>

# 2. Explore with Pi
zpi "explain the capture pipeline and identify gaps"

# 3. Plan fix
zpi "how should we fix the phi_scrub return value?"

# 4. Execute with Aider
zaider --message "fix phi_scrub to always return 0 on success"
```

---

## Backlog

Tasks live in `backlog/tasks/`. Use `backlog task view Z-NNN` to read a task.
File issues with `zdots-issue "description"` — auto-attaches `agent-reported` label.

---

## When Something Breaks

Apply the Schrute Test: would an idiot fix zdots infrastructure directly?
If yes — stop. File a `zdots-issue`. Do not mutate lib/, conf.d/, or bin/ without operator coordination.
