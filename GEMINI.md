# GEMINI.md

Gemini-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines, performance standards, and **RTK token-optimization rules**.

## Gemini Context
- This environment is optimized for `gemini-cli` via the `gm` alias.
- **Search Tooling:** `ack` is the preferred search tool due to the user's personal connection to Andy Lester. Ensure `.ackrc` is maintained for high-signal output.
- Follow the **RTK** guidance in [AGENTS.md](AGENTS.md#rtk-rust-token-killer---history-aware-optimizations) for all high-output commands.
- Use `tokei` for quick codebase orientation before performing deep analysis.
- Respect the performance budget (< 0.08s) when suggesting shell modifications.

## Agent Context & Observability
- **Traceability**: This is an observable session. Every tool call and command is emitted as an OTel span to the local LGTM stack.
- **System Capabilities**: Use the `capabilities --json` command to verify the environment contract before performing complex operations.
- **The Trinity Awareness**:
    - **Anchor (`adots`)**: For root-level system state.
    - **Platform (`zdots`)**: For shell behavior and real-time observability.
    - **Brain (`my`)**: For long-term context, standards, and structured memory.
- **Context Writing**: When making significant architectural decisions or recording project observations, utilize the `~/my/context/` directory (e.g., `observations.md` or `next_prompt.md`) to hydrate the "Cerebral Control Plane."

## Database Access

The single database is `my` (PostgreSQL). All access uses role-based users — never connect as the `mike` superuser for routine work.

| User | Role | Purpose | Connect string |
|------|------|---------|----------------|
| `zdots_ro` | `zdots_reader` | Read-only exploration | `psql -U zdots_ro my` |
| `zdots_rw` | `zdots_writer` | App writes (zdots-ctx, context-engine) | `postgresql://zdots_rw@/my` |
| `mike` | superuser | Migrations only — via `ZDOTS_MIGRATION_URL` | automatic via `zdots-ctx migrate` |

**Write path** — all mutations must go through intentional interfaces:
- `zdots-ctx <command>` — CLI (uses `zdots_rw`)
- `context-engine` Rails API (uses `zdots_rw`)

**Read-only exploration** — safe for ad-hoc queries:
- `psql -U zdots_ro my` — direct SQL (SELECT only, no writes possible)
- `zdots-ctx query <term>` — full-text search

`DATABASE_URL` always resolves to `postgresql://zdots_rw@/my`. Do not override it to point at any other database — the `my` database is the only authoritative source.

## Documentation Standards
- **Diagrams**: Use Mermaid (v11+) for all architectural and state visualizations.
- **Supported Types**: Prefer `architecture-beta` for system maps, `erDiagram` for database schema, and `stateDiagram-v2` for job lifecycles.
- **CLI**: Use `mmdc` (v11.15.0) for local rendering of assets.

## Philosophical Values & Frameworks

### Manifestos & Laws (Delivery & Excellence)
*   **Agile:** Individuals and interactions, working software, customer collaboration, and responding to change.
*   **Software Craftsmanship:** Well-crafted software, steadily adding value, a community of professionals, and productive partnerships.
*   **Gall’s Law:** A complex system that works is invariably found to have evolved from a simple system that worked. A complex system designed from scratch never works.
*   **The Unix Philosophy:** Write programs that do one thing and do it well. Write programs to work together. (Technical version of "Few word do trick").

