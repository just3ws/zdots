---
id: platform-raci
title: "Platform RACI Matrix"
purpose: Defines operational ownership, responsibilities, and synchronization workflows across the four personal-OS repos and subsystems.
rationale: Prevents amnesia, cross-repo breakage, and silent failures when modifying platform-wide capabilities.
audience: agents, operator
updated: "2026-09-05"
---

# Platform RACI Matrix

The personal OS is an ecosystem of four synchronized repositories, backing services, and clear boundaries:

```text
         ┌────────────────────────────────────────────────────────┐
         │                    Operator (Mike)                     │
         └───────────┬────────────────────────────┬───────────────┘
                     │                            │
         ┌───────────▼───────────┐    ┌───────────▼───────────┐
         │         zdots         │    │         adots         │
         │ (Kernel/Services/CLI) │    │  (Home Config/Bare)   │
         └───────────┬───────────┘    └───────────┬───────────┘
                     │                            │
         ┌───────────▼───────────┐    ┌───────────▼───────────┐
         │         vdots         │    │          my           │
         │     (Editor/NVIM)     │    │ (Knowledge/Context-UI)│
         └───────────────────────┘    └───────────────────────┘
```

- **`zdots`** (`~/.config/zsh`): **Kernel & Control Plane**. Services, OTel collector, CLI tools, message bus, PHI scrubbers.
- **`adots`** (`~/.homegit`, bare repo, work-tree `$HOME`): **Home Configuration & Dotfiles**. User-space defaults, profile startup, shell entrypoints.
- **`vdots`** (`~/.config/nvim`): **Editor Seam**. Neovim configuration, Mason LSPs, DAP, test runners, linters, and formatters.
- **`my`** (`~/my`): **Knowledge Vault & Context Engine**. Private knowledge base, PostgreSQL database, Rails management console (`my.localhost`).

---

## 1. Primary Component Ownership

| Subsystem / Layer | zdots | adots | vdots | my | Operator |
|---|:---:|:---:|:---:|:---:|:---:|
| **Shell Startup & Hook Lifecycle** (`.zshenv`, `conf.d/`, `env.sh`) | **R / A** | C | I | I | A |
| **User-Space Dotfiles & Home Layout** (`$HOME/.zshrc`, `.gitconfig`, ssh) | C | **R / A** | I | I | A |
| **Editor Tooling & Language Workspaces** (LSP, DAP, Treesitter, Linters) | I | I | **R / A** | I | A |
| **Private Knowledge Base & Vault Content** (`vaults/`, notes) | I | I | I | **R / A** | A |
| **Database Schema & Migrations** (`my` PostgreSQL, Sequel) | C | I | I | **R / A** | A |
| **Knowledge Layer CLI & Models** (`zdots-ctx`, Ruby Sequel models) | **R / A** | I | I | C | A |
| **Observability Engine & Collector Config** (`etc/otel-collector.yaml`) | **R / A** | I | I | C | A |
| **Context Engine UI & Visual Cockpit** (`my.localhost/panoramic`) | C | I | I | **R / A** | A |
| **Platform Services Lifecycle** (`zsvc`, `zdots-ctl`, `llama.cpp`) | **R / A** | I | I | C | A |
| **Communication Bus Infrastructure** (`Zdots::Bus`, tokens, schema) | **R / A** | I | I | C | A |
| **Imperial CalVer & Beacon Stamp** (`VERSION`, release sync) | **R** | **R** | **R** | C | **A** |
| **Work Extension Seam** (`$ZDOTS_WORK_EXT`, untracked tenant configs) | **R** | C | I | I | **A** |

*Definitions:*
- **R (Responsible):** Does the implementation and executes verification.
- **A (Accountable):** Sole authority for final sign-off, merge, or architectural change. (Mike is globally Accountable; subsystem stewards are locally Accountable).
- **C (Consulted):** Must be checked for callers, contracts, or upstream impacts before mutating.
- **I (Informed):** Kept notified via docs, handoffs, or Bus events.

---

## 2. Change Propagation Checklist (What to Update When)

When changing one part of the platform, use this table to verify what downstream repos and seams must be reconciled.

### Scenario A: Adding a new system binary or global CLI tool
1. **`zdots` (`R`)**: Place script in `~/.config/zsh/bin/`. Provide `--help` and `-?` conforming to Unix philosophy.
2. **`zdots` (`R`)**: Update `zdots-ctx hydrate tooling-catalog` if intended for agent automation.
3. **`adots` (`I`)**: Verify no `$HOME/bin` or path collision.
4. **`vdots` (`C`)**: If the tool is an LSP server, formatter, or linter, register in `lua/editor/mason.lua` or `lua/plugins.lua`.

### Scenario B: Adding or mutating an environment variable or path
1. **`zdots` (`R`)**: Add default definition in `env.sh` or specific `conf.d/` module.
2. **`adots` (`C`)**: If required during login shell before Zsh interactive bootstrap, source via `$HOME/.zprofile` or `$HOME/.zshenv`.
3. **`my` (`C`)**: If variable alters database access or service discovery, update `ZDOTS_DATABASE_URL` or context-engine `.env`.
4. **`vdots` (`I`)**: Ensure terminal sessions inherit the variable without shell restarting.

### Scenario C: Modifying OTel Collector or adding an app log receiver
1. **`zdots` (`R`)**: Update `etc/otel-collector.yaml` or define generic env receptor (`${env:ZDOTS_APP_LOG}`).
2. **`zdots` (`R`)**: Run `otel-collector validate` and `otel-collector restart`.
3. **`my` (`C`)**: Verify `context-engine` RuntimeEvidence (`Panoramic::RuntimeEvidence`) parses new fields.
4. **Tenant Repos (`I`)**: Inform external repos (e.g. `phalanxduel`, `wwworkremote`) of accepted schema and port.

### Scenario D: Database Schema Migration
1. **`my` (`R`)**: Add Sequel migration to `db/migrations/`.
2. **`zdots` (`R`)**: Run `zdots-ctx migrate` using `ZDOTS_MIGRATION_URL`.
3. **`zdots` (`C`)**: If schema modifies `lessons`, `methodologies`, or `bus_*`, update Ruby models in `lib/zdots/models/`.
4. **`my` (`C`)**: Update Rails models in `context-engine/app/models/` if context-engine directly references the table.

### Scenario E: Imperial CalVer Release ("The Beacon")
1. **`zdots` (`R`)**: Run `imperial-date > VERSION`, commit, generate changelog.
2. **`adots` (`R`)**: Stamp matching CalVer in `VERSION`.
3. **`vdots` (`R`)**: Stamp matching CalVer in `VERSION`.
4. **`my` (`C`)**: Conforms by contract (does not break API compatibility).
5. **Verification**: Run `zdots-doctor` to ensure 0 beacon drift across all peers.

---

## 3. The Cross-Repo Seams

To prevent architectural decay, changes must respect the formal seams:

1. **The Dotfiles Seam (`adots` ↔ `zdots`):**
   - `adots` tracks dotfiles in `$HOME` via bare git repo.
   - `zdots` is cloned at `~/.config/zsh` and loaded by `$HOME/.zshenv` / `.zshrc`.
   - Never place zdots-internal operational scripts into `adots`.

2. **The Editor Seam (`zdots` ↔ `vdots`):**
   - `zdots` provides runtime tools via `PATH` and mise shims.
   - `vdots` must not install tools into system directories; it manages Neovim-specific plugins and Mason servers locally in `~/.local/share/nvim`.

3. **The Knowledge Seam (`zdots` ↔ `my`):**
   - Writes to `my` PostgreSQL must go through `zdots-ctx` or `context-engine` using role `zdots_rw`.
   - Never execute ad-hoc SQL writes via OS superuser.
   - PGP encryption at rest is owned by `zdots-brain`.

4. **The Work Extension Seam (`zdots` ↔ `$ZDOTS_WORK_EXT`):**
   - Untracked workspace for tenant-specific configuration.
   - None of the four platform repos carries proprietary tenant strings or employer identifiers.
