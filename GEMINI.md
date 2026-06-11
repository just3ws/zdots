# GEMINI.md

Gemini-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines, performance standards, **RTK token-optimization rules**, and **PHI Operating Mode** (Section 8 — non-negotiable on work machines).

## Gemini Context
- This environment is optimized for `gemini-cli` via the `gm` alias.
- **Search Tooling:** `ack` is the preferred search tool due to the user's personal connection to Andy Lester. Ensure `.ackrc` is maintained for high-signal output.
- Follow the **RTK** guidance in [AGENTS.md](AGENTS.md#2-token-optimization-rtk) for all high-output commands.
- Use `tokei` for quick codebase orientation before performing deep analysis.
- Respect the performance budget (< 0.08s) when suggesting shell modifications.

## Agent Context & Observability
- **Traceability**: This is an observable session. Every tool call and command is emitted as an OTel span to the local LGTM stack.
- **System Capabilities**: Use the `capabilities --json` command to verify the environment contract before performing complex operations.
- **Platform Awareness**:
    - **Platform (`zdots`)**: Shell behavior, service lifecycle, real-time observability.
    - **Brain (`my`)**: Long-term context, standards, structured memory.
- **fabric-ai Integration**:
    - **Update Patterns**: Run `fabric-ai --updatepatterns` to pull the latest expert prompts.
    - **Usage**:
        - `zdots-ask --pattern <name>`: One-shot inference using a Fabric pattern.
        - `zdots-pattern`: Interactive browser (`fzf`) for pattern selection.
        - `zdots-pattern --context`: Prepend real-time zdots context to the pattern.
- **Context Writing**: When making significant architectural decisions or recording project observations, utilize the `~/my/context/` directory (e.g., `observations.md` or `next_prompt.md`) to hydrate the "Cerebral Control Plane."

## Database Access

The single database is `my` (PostgreSQL). All access uses role-based users — never connect as the OS superuser for routine work.

| User | Role | Purpose | Connect string |
|------|------|---------|----------------|
| `zdots_ro` | `zdots_reader` | Read-only exploration | `psql -U zdots_ro my` |
| `zdots_rw` | `zdots_writer` | App writes (zdots-ctx, context-engine) | `postgresql://zdots_rw@/my` |
| OS user | superuser | Migrations only — via `ZDOTS_MIGRATION_URL` | automatic via `zdots-ctx migrate` |

**Write path** — all mutations must go through intentional interfaces:
- `zdots-ctx <command>` — CLI (uses `zdots_rw`)
- `context-engine` Rails API (uses `zdots_rw`)

**Read-only exploration** — safe for ad-hoc queries:
- `psql -U zdots_ro my` — direct SQL (SELECT only, no writes possible)
- `zdots-ctx query <term>` — full-text search

`ZDOTS_DATABASE_URL` always resolves to `postgresql://zdots_rw@/my`. Do not set `DATABASE_URL` in the zdots environment — it has no owner here and setting it causes confusion across tools. Use `ZDOTS_DATABASE_URL` for app connections and `ZDOTS_MIGRATION_URL` for migrations.

## Documentation Standards
- **Diagrams**: Use Mermaid (v11+) for all architectural and state visualizations.
- **Supported Types**: Prefer `architecture-beta` for system maps, `erDiagram` for database schema, and `stateDiagram-v2` for job lifecycles.
- **CLI**: Use `mmdc` (v11.15.0) for local rendering of assets.

## Philosophical Values & Frameworks

### Discoverability & System Safety
- **High-Signal Discovery:** All custom tools MUST provide robust `--help` and `-?` documentation.
- **On-Demand Briefing:** The environment acts as an active knowledge partner. Commands like `agent-guide` and `zdots-pulse` are preferred entry points for orientation.
- **Sensible Defaults:** Priority is given to safe, non-destructive actions. Critical or destructive operations MUST require explicit `--yes` or `--force` flags.
- **Context Awareness:** Tools should guide the user toward the "right choice" by providing relevant context in help text and error messages.

### Manifestos & Laws (Delivery & Excellence)
*   **Agile:** Individuals and interactions, working software, customer collaboration, and responding to change.
*   **Software Craftsmanship:** Well-crafted software, steadily adding value, a community of professionals, and productive partnerships.
*   **Gall’s Law:** A complex system that works is invariably found to have evolved from a simple system that worked. A complex system designed from scratch never works.
*   **The Unix Philosophy:** Write programs that do one thing and do it well. Write programs to work together. (Technical version of "Few word do trick").

