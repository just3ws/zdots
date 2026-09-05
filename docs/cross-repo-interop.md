# Cross-Repo Interop Registry

zdots is the coordination hub for a small set of **external, non-platform**
repos that have a real, evidence-backed dependency on it (or on each other,
routed through it). "The platform" (`zdots`/`adots`/`vdots`/`my`, see
`/platform-sync`) is a different, closed set — this registry is for everything
*outside* that set which still talks to zdots.

Every row here was added because of **found evidence** (an O2 trace, a
documented protocol in the other repo) — never because a relationship seemed
plausible. See `/interop-registry` for the audit and change procedure.

**Bus traffic is not evidence — for anything posted before 2026-08-23.** It was
treated as such here until 2026-08-22. Participant identity was unauthenticated:
any caller could post under any name, so a message proved content, not
authorship. Rows that rested on bus traffic are retracted below rather than
quietly deleted.

Z-310 closed the hole on 2026-08-23 — posting now requires a registered name and
its token. That fixes the future, not the past: historical traffic is still
unattributable, and the pre-Z-310 participants (`agent-just3ws`,
`agent-wwworkremote`) remain frozen until deliberately re-registered. Even after
the fix, promoting a row on bus traffic alone needs care — the Keychain is
per-user, so a determined local process can still forge. O2 traces and the other
repo's own committed docs stay the primary admissible kinds.

## Members

| Repo | Path | Relationship | Evidence | Documented on their side |
|---|---|---|---|---|
| `wwworkremote/core` | `~/github.com/wwworkremote/core` | Calls zdots' `llama-server` (`POST :11500/v1/chat/completions`) as its LLM backend | O2 trace `c86ecb0429740c07c3f1053378b18cbe`, 200 OK, 2026-08-17 | `docs/architecture/ruby_llm.md`, `docs/configuration.md`, `docs/troubleshooting.md` |
| `wwworkremote/core` | (same) | **Claimed only.** Documented on their side as posting to the `job-leads` channel; not verified from this side | ~~Live bus traffic (`agent-antigravity`, 2026-08-17)~~ — **retracted 2026-08-22**: that message was posted by `agent-antigravity`, a different participant, so it never evidenced wwworkremote at all. Messages under `agent-wwworkremote` (2026-08-22) were posted by another actor, and the live wwworkremote session states it has never registered or posted. Bus attribution is unauthenticated (Z-310) and cannot serve as evidence here | `docs/just3ws-interop-protocol.md`, `docs/agents/interop.md` |
| `just3ws.github.io` | `~/github.com/just3ws/just3ws.github.io` | Same `job-leads` bus channel | Documented in their own protocol doc. Bus traffic exists under `agent-just3ws` but proves only that *something* posted using that name — see Z-310 | `docs/inter-tool-communication-protocol.md` |
| `just3ws.github.io` | (same) | Exports static `resume.json` / `exports/*.md`; `wwworkremote` fetches by plain GET | O2 trace: `wwworkremote` → `https://just3ws.github.io/resume.json` | `docs/inter-tool-communication-protocol.md` (their side); `docs/just3ws-interop-protocol.md` (wwworkremote's side) |
| `phalanxduel` | `~/github.com/phalanxduel/game` | PVL (Panoramic View Labs) integration: emits match-scoped JSONL telemetry via `ZDOTS_APP_LOG` to zdots host OTel collector (`filelog/app` receiver) → OpenObserve; cross-repo coordination via `phalanxduel` bus channel (`pavel` ↔ `phalanxduel-ai`) | Authenticated Z-310 bus registration for `phalanxduel-ai` and `pavel`, active message traffic on `phalanxduel` channel (2026-09-05), server-side implementation and tests in `phalanxduel/game` | `docs/agents/profiles/pavel-agent.md`, `docs/observability/gameplay-panoramic-view.md` |

## Explicitly NOT members (checked, no evidence found)

- **`my`/context-engine** — zero O2 traces to/from it, no interop doc on any
  side mentions it. Don't assume a dependency exists without checking first
  (this was wrongly assumed once already this session and had to be corrected).

## Agent RACI Matrix (Platform & Cross-Repo)

| Role / Entity | Operator (Mike) | Pi (`zpi`) | Aider (`zaider`) | Claude Code / Antigravity | Pavel (`pavel`, PVL specialist) | Tenant Agent (`phalanxduel-ai`, etc.) |
|---|---|---|---|---|---|---|
| **Platform Governance & Security** | **A** | I | I | C | C | I |
| **System Exploration & Briefing** | I | **R** | I | C | C | I |
| **Code Implementation & Commits** | A | I | **R** | C | I | **R** (in tenant repo) |
| **Architecture & Multi-file Review** | A | C | I | **R** | C | C |
| **PVL Technique & Telemetry Seams** | A | I | I | C | **R / A** | C (domain inputs) |
| **Domain Logic & Tenant Tests** | A | I | I | I | C | **R / A** (in tenant repo) |
| **Cross-Repo Bus Coordination** | A | I | I | C | **R** (on `phalanxduel` channel) | **R** (on tenant channel) |

*Key:* **R**esponsible (does the work), **A**ccountable (final decision/sign-off), **C**onsulted (two-way input), **I**nformed (kept updated).

## zdots-side documentation of these relationships

- `docs/llama-cpp.md` — "Known external consumer" note (wwworkremote)
- `docs/local-url-routing.md` — topology table includes wwworkremote.localhost
  / just3ws.localhost, notes the static-export-only nature of just3ws
- `docs/message-bus.md` — `job-leads` and `phalanxduel` flagged as active external channels
- `etc/otel-collector.yaml` — `filelog/app` receiver consuming tenant JSONL via `$ZDOTS_APP_LOG`
- Knowledge Layer: `zdots-ctx query pvl` / `zdots-ctx query "Cross-repo RACI"`

Corresponding Lessons are in context-engine — the durable, queryable version of this registry.
This file is the human-readable/skill-readable one; keep both in sync when either changes.
