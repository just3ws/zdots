# Cross-Repo Interop Registry

zdots is the coordination hub for a small set of **external, non-platform**
repos that have a real, evidence-backed dependency on it (or on each other,
routed through it). "The platform" (`zdots`/`adots`/`vdots`/`my`, see
`/platform-sync`) is a different, closed set — this registry is for everything
*outside* that set which still talks to zdots.

Every row here was added because of **found evidence** (an O2 trace, a
documented protocol in the other repo) — never because a relationship seemed
plausible. See `/interop-registry` for the audit and change procedure.

**Bus traffic is not evidence.** It was treated as such here until 2026-08-22.
Participant identity on the message bus is unauthenticated — any caller can post
under any name (Z-310) — so a message proves content, not authorship. O2 traces
and the other repo's own committed docs are the admissible kinds. Rows that
rested on bus traffic have been retracted below rather than quietly deleted.

## Members

| Repo | Path | Relationship | Evidence | Documented on their side |
|---|---|---|---|---|
| `wwworkremote/core` | `~/github.com/wwworkremote/core` | Calls zdots' `llama-server` (`POST :11500/v1/chat/completions`) as its LLM backend | O2 trace `c86ecb0429740c07c3f1053378b18cbe`, 200 OK, 2026-08-17 | `docs/architecture/ruby_llm.md`, `docs/configuration.md`, `docs/troubleshooting.md` |
| `wwworkremote/core` | (same) | **Claimed only.** Documented on their side as posting to the `job-leads` channel; not verified from this side | ~~Live bus traffic (`agent-antigravity`, 2026-08-17)~~ — **retracted 2026-08-22**: that message was posted by `agent-antigravity`, a different participant, so it never evidenced wwworkremote at all. Messages under `agent-wwworkremote` (2026-08-22) were posted by another actor, and the live wwworkremote session states it has never registered or posted. Bus attribution is unauthenticated (Z-310) and cannot serve as evidence here | `docs/just3ws-interop-protocol.md`, `docs/agents/interop.md` |
| `just3ws.github.io` | `~/github.com/just3ws/just3ws.github.io` | Same `job-leads` bus channel | Documented in their own protocol doc. Bus traffic exists under `agent-just3ws` but proves only that *something* posted using that name — see Z-310 | `docs/inter-tool-communication-protocol.md` |
| `just3ws.github.io` | (same) | Exports static `resume.json` / `exports/*.md`; `wwworkremote` fetches by plain GET | O2 trace: `wwworkremote` → `https://just3ws.github.io/resume.json` | `docs/inter-tool-communication-protocol.md` (their side); `docs/just3ws-interop-protocol.md` (wwworkremote's side) |

## Explicitly NOT members (checked, no evidence found)

- **`my`/context-engine** — zero O2 traces to/from it, no interop doc on any
  side mentions it. Don't assume a dependency exists without checking first
  (this was wrongly assumed once already this session and had to be corrected).
- **`phalanxduel`** — never checked as part of this registry; a separate
  personal-project thread (`phx` alias), no evidence gathered either way.

## zdots-side documentation of these relationships

- `docs/llama-cpp.md` — "Known external consumer" note (wwworkremote)
- `docs/local-url-routing.md` — topology table includes wwworkremote.localhost
  / just3ws.localhost, notes the static-export-only nature of just3ws
- `docs/message-bus.md` — `job-leads` flagged as an external, live channel

Three corresponding Lessons are in context-engine (`zdots-ctx query "RACI
wwworkremote just3ws"`) — the durable, queryable version of this registry.
This file is the human-readable/skill-readable one; keep both in sync when
either changes.
