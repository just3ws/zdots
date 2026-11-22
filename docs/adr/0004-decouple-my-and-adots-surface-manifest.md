# ADR-0004: Decouple `my` from `zdots` and Drive Platform Surfaces from `adots`

- **Status:** Accepted & Implemented
- **Date:** 2026-11-22
- **Related:** `~/.config/adots/my-directory-setup-consolidation-plan.md`, `backlog/decisions/decision-007`

## Context

`zdots` is the runtime kernel (shell, local services, CLI tooling), `adots` is the
host-level dotfile/profile supervisor (`~/.homegit` -> `$HOME`), and `my` is a
private knowledge vault. Over time, `my` became hardcoded across `zdots` along four
seams:

1. **Filesystem paths (`$HOME/my`)** in `zdots-version`, `zdots-platform`,
   `zdots-doctor`, `capabilities`, `agent-guide`, `zdots-my-sync`, and
   `zdots-skills-sync`.
2. **Database name (`my`)** in `zdots-ctx`, `zdots-doctor`, `zdots-ctl`, and
   `lib/svc-registry.bash`.
3. **Ingress vhost (`my.localhost`)** in `nginx-ctl`, `zdots-endpoints`, and
   `statusd`.
4. **Cross-repo surface lists** hardcoded as a fixed 7-repo set even on `work` or
   standalone hosts where `my`, `ztranscribe`, `media-pipeline`, or
   `just3ws.github.io` are intentionally absent.

Meanwhile, `adots` tracks a flat `$HOME` work-tree with a single profile string
(`~/.config/adots/profile`), so host-specific tweaks (npm, codex, work git/SSH)
surface as permanent dirty diffs in `adots-git status`.

## Decision

### 1. Narrow `adots` -> `zdots` Contract via Declarative Manifests

- **`~/.config/adots/surfaces.conf`** (overridable via `ZDOTS_SURFACES_FILE`)
  declares which versioned/managed surfaces are deployed on a host:
  ```text
  # name<TAB>version_file_path<TAB>repo_kind
  zdots	$ZDOTDIR/VERSION	git
  adots	$HOME/VERSION	bare:$HOME/.homegit
  ```
- **`~/.config/adots/profiles/<profile>.conf`** defines per-deployment postures
  (e.g. `powerstation`, `work`): `ZDOTS_CONTEXT`, `ZDOTS_VAULT_ROOT`,
  `ZDOTS_SURFACES_FILE`, and `ZDOTS_UPDATE_LOCAL_SKIP`.
- **`zdots` consumes the manifest, never assumes `~/my`:**
  - **Phase 1 (implemented):** `bin/zdots-version` reads `ZDOTS_SURFACES_FILE`
    (defaulting to `$XDG_CONFIG_HOME/adots/surfaces.conf` if present, otherwise
    falling back to the legacy 7-surface list). Hosts without `my` can declare a
    minimal manifest and pass `zdots --version --check --strict`.
  - **Phase 2 (planned):**
    - Replace hardcoded `$HOME/my` in `zdots-doctor`, `capabilities`,
      `zdots-platform`, and `zdots-skills-sync` with `ZDOTS_VAULT_ROOT` (optional)
      and `surfaces.conf`.
    - Derive the Postgres DB name in `zdots-doctor` / `zdots-ctl` from
      `ZDOTS_DATABASE_URL` instead of hardcoding `my`.
    - Move `my.localhost` to a drop-in nginx vhost directory
      (`~/.config/zdots/vhosts.d/*.conf`) supplied by `adots`/`my`.
    - Move `zdots-my-sync` ownership into `adots`.
    - Keep tracked `adots` configs machine-agnostic with `*.local` includes so
      `adots-git status` stays clean across all deployed profiles.

## Consequences

- Standalone and `work` deployments no longer carry false drift or missing-vault
  warnings for personal repos (`my`, `media-pipeline`, `just3ws.github.io`).
- Adding or removing a deployed surface on a host becomes a single-file manifest
  change in `adots` instead of editing multiple `zdots` scripts and Go binaries.
