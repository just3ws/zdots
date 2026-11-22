# ADR-0005: Tiered CLI Surface, Centralized Platform Defaults, and Versioned Tenant Contract

- **Status:** Accepted (Phases 1 & 2 complete; Phase 3 pending)
- **Date:** 2026-11-22
- **Related:** `Z-184`, `Z-185`, `Z-183`, `Z-249`, `Z-263`, `Z-264`, `Z-273`, [ADR-0004](0004-decouple-my-and-adots-surface-manifest.md), `backlog/decisions/decision-008`

## Context

[ADR-0004](0004-decouple-my-and-adots-surface-manifest.md) drew a clean boundary **between repositories** (`zdots` + `adots` + `vdots` as the 3-repo core platform, with optional vaults and declarative host manifests). The next structural bottleneck sits **inside `zdots` itself**:

1. **Flat `bin/` sprawl (121 executables):** `bin/` currently mixes 57 `zdots-*` nouns and 64 unprefixed commands in one flat namespace on `PATH`. Daily-driver verbs (`zdots ctl`, `zdots ctx`, `zdots doctor`, `zdots status`) sit beside internal daemons, one-off backfill scripts, linters, cert generators, and MCP stdio servers (`zdots-backfill-boundaries`, `zdots-buffer-drain`, `zdots-otel-phi-compile`, `zdots-sql-lint`, `zdots-typecheck`, `embed-model-tripwire`, `nginx-regen-certs`, `commit-msg`, `idiot-test`). Meanwhile `sbin/` holds only `zdots-brain`, and `libexec/` does not exist.
2. **Noisy discoverability:** `zdots help` (`Z-264`, already implemented via `bin/zdots-help` and `functions/enabled/_zdots`) enumerates every `bin/zdots-*` binary, producing a 57-line wall where core operator verbs are buried in internal plumbing.
3. **Unversioned external-tenant seam (`Z-184`, `Z-185`):** External tenants (starting with `work-*`) consume `zdots` services (`ai-query`, `zdots-ctx`, `zdots-gh`, OpenObserve, Whisper) by probing `PATH` and scraping stderr/exit codes — unable to distinguish `ZDOTS_AI_MODE=none` from a stopped server. They also re-fork generic CLI plumbing (`_work-audit.sh`, `_work-help.sh`, legacy `~/.colima` socket resolution, man-page generation) that `zdots` already owns.
4. **Contract maintenance drag (`Z-183`, `Z-249`, `Z-273`):** `flag-audit`, man-page contracts, completions, and `capabilities` attestation must cover all 121 flat `bin/` entries, and parser artifacts in `etc/capabilities.sh` / `lib/peer-bootstrap.bash` produce false attestation misses.
5. **Duplicated constants across Shell, Go, and Ruby:** A live scan of `bin/`, `lib/`, `conf.d/`, `cmd/`, `etc/`, and `env.sh` shows core endpoints, ports, and paths repeated across dozens of files instead of derived from one source of truth:
   - Port `11500` / `127.0.0.1:11500` (AI inference): **42 files** (37 with full URL)
   - Port `4318` (OTel collector): **17 files** · Port `11501` (embeddings): **15 files** · Port `16686` (Jaeger): **14 files** · Port `5080` (OpenObserve): **13 files** · Port `6379` (Redis): **10 files**
   - Paths: `.zdots.local` (**15 files**), `phi-patterns.yaml` (**13 files**), `history.sqlite3` (**9 files**), `postgresql://zdots_rw` (**7 files**), plus hardcoded `/Users/mike` in `etc/launchd/com.zdots.log-rotate.plist` (`Z-263`).
   Changing a port, DB URL, or state path currently risks silent drift across three runtimes.

## Decision

### 1. Three-Tier Command Taxonomy (`bin/` vs. `libexec/` vs. `sbin/`)

Separate public operator/agent verbs from internal plumbing so `PATH` and `zdots help` only expose intentional contracts:

| Tier | Directory | On `PATH`? | Contract Scope | Examples |
|---|---|---|---|---|
| **Tier 1: Public Surface** | `bin/` | Yes | Man page, `--help`, `flag-audit`, completions, `capabilities` | `zdots`, primary `zdots-*` nouns (`ctl`, `ctx`, `doctor`, `status`, `logs`, `hygiene`, `storage`, `version`, `help`, `endpoints`, `platform`, `issue`, `gh`, `ingest-media`, `sanitize`, `keychain`, `ask`, `o2-query`, `update-local`), ergonomic/service commands (`zsvc`, `ztask`, `zmorning`, `zdash`, `zmetrics`, `tx`, `ai-query`, `capabilities`, `agent-guide`, `colima-status`, `*-ctl`) |
| **Tier 2: Internal Plumbing & Daemons** | `libexec/` | No | Invoked via `$ZDOTDIR/libexec/<cmd>` or `zdots-core` | `zdots-core` (with Tier-1 symlinks pointing to `../libexec/zdots-core`), `zdots-statusd`, `zdots-buffer-drain`, `zdots-otel-phi-compile`, `zdots-backfill-boundaries`, `zdots-index-tools`, `zdots-man-gen`, `zdots-schema`, `zdots-sql-lint`, `zdots-typecheck`, `zdots-theme-gen`, `embed-model-tripwire`, `colima-autostart`, `nginx-regen-certs`, `nginx-repair`, `commit-msg`, `idiot-test`, `otel-smoke`, `trace-verify`, `gemstash-metadata`, `*-mcp`, `pi-ctx-*`, `ruby-audit*` |
| **Tier 3: Backend Workers** | `sbin/` | No | Invoked only by `zdots-ctx` / `zdots-worker` | `zdots-brain` |

- `bin/zdots` and `bin/zdots-help` continue to follow `decision-008` (additive thin router; Tier-1 `zdots-*` commands remain directly invocable), but `zdots help` only lists Tier-1 nouns (~15–20 commands instead of 57).
- Target `bin/` footprint after migration: **~45–50 intentional public commands** (down from 121).

### 2. Versioned Service Surface in `capabilities --json` (`Z-184` + `Z-273`)

Publish a stable, versioned `service_surface` object inside `capabilities --json`:

```json
{
  "service_surface": {
    "schema_version": "zdots.surface.v1",
    "services": {
      "inference":   { "endpoint": "http://127.0.0.1:11500", "mode": "local", "status": "ready", "reason": "" },
      "embeddings":  { "endpoint": "http://127.0.0.1:11501", "mode": "local", "status": "ready", "reason": "" },
      "jaeger":      { "endpoint": "http://127.0.0.1:16686", "status": "ready", "reason": "" },
      "knowledge":   { "db": "my",                           "status": "ready", "reason": "" },
      "warehouse":   { "path": "...",                        "status": "ready", "reason": "" },
      "whisper":     { "endpoint": "http://127.0.0.1:11502", "status": "stopped", "reason": "on-demand" },
      "colima":      { "docker_host": "unix://...",          "status": "ready", "reason": "" }
    }
  }
}
```

- Standardized `status` enum: `ready` | `stopped` | `disabled` | `misconfigured`, with a machine- and human-readable `reason` (e.g. `ZDOTS_AI_MODE=none` vs. `connection_refused`).
- Fix `etc/capabilities.sh` and `lib/peer-bootstrap.bash` attestation parser artifacts (`Z-273`: malformed `cmd | ai-query`, brace-literal `pi-ctx-{...}`, `metadata:*`, and function entries) so attestation counts are honest.
- External tenants validate against `zdots.surface.v1` rather than probing `PATH` or scraping stderr.

### 3. Shared Tenant CLI SDK (`lib/sdk/`, `Z-185`)

Expose a small, versioned, sourceable Bash/Zsh library directory (`$ZDOTDIR/lib/sdk/`) for external tenants (starting with `zdots-work`), eliminating forked CLI plumbing:

- `lib/sdk/cli-help.bash` — header-comment `-h`/`--help` renderer that runs before side effects (promoted from `lib/cli-help.bash`).
- `lib/sdk/cli-audit.bash` — NDJSON command-audit shim (`read-only` | `lake-write` | `db-mutating` taxonomy, `START`/`END`/`INVOKE` records, chained `EXIT` trap).
- `lib/sdk/docker-host.bash` — thin wrapper over `colima-status socket`, eliminating legacy `~/.colima` path drift.
- `libexec/zdots-man-gen` — documented with `--src <dir> --out <dir>` so tenants can generate man pages for their own `bin/` directories without forking the generator.

### 4. Centralized Platform Defaults (`etc/defaults.env`)

Establish **`etc/defaults.env`** as the single source of truth for canonical ports, loopback endpoints, and state/registry paths across Shell, Go, and Ruby:

- **Format:** Simple POSIX `KEY=VALUE` assignments (no shell logic, no external parser required).
  - Shell (`env.sh`) loads it at startup in ~0 ms with zero subprocess forks, exporting defaults only when unset (`${VAR:=default}` semantics via a tiny loader or non-clobbering defaults).
  - Go (`cmd/zdots-core/internal/config/`) and Ruby (`lib/zdots/config.rb`) parse the same `etc/defaults.env` via stdlib (~15 lines) as their fallback when invoked outside a login shell.
- **Deterministic precedence cascade (lowest → highest):**
  1. `etc/defaults.env` — tracked canonical platform defaults (ports, loopback endpoints, state DB paths, PHI registry path, default DB URL)
  2. `~/.config/adots/profiles/<profile>.conf` — host deployment posture (`powerstation`, `work`)
  3. `.zdots.local` / `.zdots.work` — untracked machine-local overrides
  4. Process environment — caller overrides (never clobbered)
- **Zero hardcoded home paths:** Convert `etc/launchd/com.zdots.log-rotate.plist` (`Z-263`) to a templated plist rendered with `$HOME` / `$ZDOTDIR` at install time.

## Phased Rollout

1. **Phase 1 — Centralized Defaults, Contract & Honesty (`etc/defaults.env`, `Z-184`, `Z-273`, close `Z-264`):**
   - Create `etc/defaults.env` and wire it into `env.sh` + `cmd/zdots-core` as the base of the config cascade.
   - Add `service_surface` (`zdots.surface.v1`) to `capabilities --json` (`Z-184`), reading endpoints from the centralized config.
   - Fix `etc/capabilities.sh` + `lib/peer-bootstrap.bash` attestation accuracy (`Z-273`) and close `Z-264` (already implemented in `bin/zdots-help` + `functions/enabled/_zdots`).
2. **Phase 2 — Tenant SDK & Constant Consolidation (`Z-185`, `Z-263`):**
   - Create `lib/sdk/` (`cli-help.bash`, `cli-audit.bash`, `docker-host.bash`) with Bats contract tests.
   - Migrate high-fanout callers (`lib/svc-registry.bash`, `cmd/zdots-core`, `lib/zdots/`, `conf.d/`) off duplicated hardcoded ports/paths onto `etc/defaults.env`, and template `com.zdots.log-rotate.plist` (`Z-263`).
3. **Phase 3 — `bin/` → `libexec/` Diet:**
   - Audit all callers (launchd plists, `conf.d/`, `bin/`, `tests/`, `adots`, `zdots-work`) before moving each batch.
   - Move Tier-2 internals into `libexec/` in 3–4 small, test-verified commits (daemons/hooks → CI/lint/gen tools → MCP/one-offs), updating `etc/capabilities.sh` and `tests/docs_contract.bats` alongside each batch.

## Consequences

- **Positive:** Cuts the public `bin/` surface by more than half (~121 → ~45–50), makes `zdots help` genuinely scannable, gives external tenants a single versioned discovery schema (`zdots.surface.v1`) and shared CLI SDK, and reduces `flag-audit` / man-page contract overhead to real user-facing commands.
- **Trade-offs / Risks:** Moving scripts from `bin/` to `libexec/` requires checking launchd plists, `adots`, cron/hooks, and `zdots-work` callers first; each Phase 3 batch must be preceded by a cross-repo caller grep and verified with `make check-fast` + Bats.
- **Non-goals:** Breaking muscle-memory Tier-1 `zdots-*` direct invocations (`decision-008` stays intact) or rewriting working shell scripts in Go unless latency/correctness justifies it.
