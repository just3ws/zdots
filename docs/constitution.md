# Constitution of the zdots Personal OS

> *We, the operator of the zdots Personal OS, in order to form a more perfect union across workstations, establish clean architectural seams, insure domestic tranquility of working trees, provide for the common defense of PHI and credentials, promote the general ergonomics of the shell, and secure the blessings of portability to ourselves and our downstream hosts, do ordain and establish this Constitution for the zdots Platform.*

---

## Article I — The Union & Separation of Powers

1. **The Core Platform** consists of exactly three sovereign repositories:
   - **`zdots`** (`~/.config/zsh`) — the runtime kernel: shell control plane, Platform Services, CLI surface, and Knowledge Layer.
   - **`adots`** (bare `~/.homegit`, work-tree `$HOME`) — the host-level dotfile supervisor, deployment profiles, and surface manifests.
   - **`vdots`** (`~/.config/nvim`) — the editor environment.
2. **Federated Vaults & External Tenants** are decoupled from the core ([ADR-0004](adr/0004-decouple-my-and-adots-surface-manifest.md)):
   - Private vaults (such as `my` at `~/my`) are opt-in via `$ZDOTS_VAULT_ROOT`; the core platform must never assume a vault's presence, path, or database name.
   - Employer/tenant extensions live in untracked extension repos (`${ZDOTS_WORK_EXT:-~/.config/zdots-work}`) loaded via `conf.d/31-work-ext.zsh`, with zero tenant identifiers tracked in core repos.
3. **The Astronomicon Beacon:** Deployed surfaces declared in `~/.config/adots/surfaces.conf` (overridable via `ZDOTS_SURFACES_FILE`) share a single imperial-CalVer `VERSION` epoch verified by `zdots --version --check`.

---

## Article II — Supremacy of the Configuration Cascade

1. **Single Source of Truth:** Canonical ports, loopback endpoints, database URLs, and storage reserves are declared once in [etc/defaults.env](../etc/defaults.env) and consumed identically across all three platform runtimes ([ADR-0005](adr/0005-tiered-cli-surface-and-tenant-contract.md)):
   - **Shell:** sourced first in [env.sh](../env.sh) (non-clobbering).
   - **Go:** parsed by `cmd/zdots-core/internal/config`.
   - **Ruby:** parsed by `lib/zdots/config.rb`.
2. **Deterministic Precedence (lowest → highest):**
   1. `etc/defaults.env` — tracked canonical platform defaults
   2. `.zdots.env` — dependency-injection provider wiring
   3. `~/.config/adots/profiles/<profile>.conf` — host deployment posture (`powerstation`, `work`)
   4. `.zdots.local` — untracked machine-local overrides
   5. `.zdots.work` — enforced work-host policy (when `ZDOTS_CONTEXT=work`)
   6. Process environment — caller overrides (never clobbered)
3. **Prohibitions:**
   - No runtime may hardcode duplicated service ports or endpoints outside `etc/defaults.env` and its config reader.
   - No host or script may set `DATABASE_URL` (use `ZDOTS_DATABASE_URL` and `ZDOTS_MIGRATION_URL`).
   - No tracked template (LaunchAgent, agent config, or profile) may hardcode `/Users/<user>` home paths.

---

## Article III — Obligations of Deployed Hosts (Untracked Local Contracts)

Every host onto which the platform is deployed maintains untracked, machine-local state. To remain in good standing with the Union, every host shall satisfy these enforceable contracts (verified automatically by `zdots-doctor` → *Local & untracked contracts*):

1. **Machine Identity Pointer (`~/.config/adots/profile`):**
   - Must remain **untracked and gitignored** in `adots` (`Z-277`).
   - Must contain a single valid profile token matching an existing `~/.config/adots/profiles/<profile>.conf`.
2. **Local Shell Overrides (`~/.config/zsh/.zdots.local`):**
   - When present, must pass POSIX syntax validation (`sh -n`), carry restrictive `0600` permissions, and never set `DATABASE_URL` or store raw secrets.
3. **Scoped Git Identity & Signing (`~/.config/git/`):**
   - `config.identity`, `config.signing`, and `allowed_signers` are machine-local and gitignored.
   - Core open-source repos (`zdots`, `adots`, `vdots`) must resolve to the operator's personal identity; corporate repos must default to the corporate identity. Bidirectional leakage is forbidden.
4. **Terminal Parity (macOS / iTerm2):**
   - When iTerm2 is installed with the `zdots` Dynamic Profile (`zdots-kanagawa.json`), the parent profile shall maintain Kanagawa Wave (Dark) / Lotus (Light) appearance-following, `Option` and `Right Option` set to `Esc+`, `Custom Directory = Recycle`, `Load Shell Integration Automatically = true`, and `Unlimited Scrollback = true`.
   - Global macOS defaults shall point `Default Bookmark Guid` to a `zdots` profile and enable `AllowClipboardAccess = true` (OSC 52 clipboard for tmux/Neovim).
   - No stale duplicate Dynamic Profiles (e.g., `kanagawa-wave.json`) may linger in `DynamicProfiles/`.
5. **Rendered Background Agents (macOS / LaunchAgents):**
   - Installed plists (such as `~/Library/LaunchAgents/com.zdots.log-rotate.plist`) must be rendered via their installer (`log-rotate --install-agent`), contain zero unrendered `__HOME__` / `__ZDOTDIR__` / `__XDG_STATE_HOME__` placeholders, and pass `plutil -lint`.

---

## Article IV — Rights & Obligations of External Tenants

1. **Tiered Command Surface:**
   - **Tier 1 (`bin/`, on `PATH`):** Public operator and agent commands covered by man pages, `--help`, `flag-audit`, and `capabilities`.
   - **Tier 2 (`libexec/`, off `PATH`):** Internal plumbing, compilers, generators, and multicall binaries (`libexec/zdots-core`).
   - **Tier 3 (`sbin/`, off `PATH`):** Backend workers (`sbin/zdots-brain`).
2. **Versioned Service Discovery:** External tenants discover Platform Services through `capabilities --json` → `service_surface` (`schema_version: "zdots.surface.v1"`), reading standardized `ready | stopped | disabled` status and `reason` instead of probing `PATH` or scraping stderr.
3. **Shared CLI Aspects (`lib/sdk/`):** Tenants consume [lib/sdk/](../lib/sdk/) (`cli-help.bash`, `cli-audit.bash`, `docker-host.bash`) rather than re-forking `--help` guards, NDJSON command auditing, or Docker socket resolution.

---

## Article V — Bill of Non-Negotiable Safeguards

1. **PHI & Secret Boundary:**
   - Local inference (`ZDOTS_AI_MODE=local`, loopback only) is the default; work hosts hard-block consumer cloud lanes.
   - Interactive shell history and command analytics pass through the resident `zdots-phi-scrub` boundary ([ADR-0002](adr/0002-phi-scrubber-go-binary.md)).
   - Secrets live in macOS Keychain (`zdots-keychain`); `.zdots.secrets`, `.env`, keys, and PHI-shaped files are never read into agent prompts or committed (`bin/secret-scan`).
2. **Cryptographic Authorship & Zero AI Attribution:**
   - Every commit and tag in core repos is signed with the operator's 1Password ED25519 SSH key; signing is never bypassed.
   - Zero AI-tool attribution (`Co-Authored-By`, badges, "Generated with…", session links) appears anywhere in commits, code, docs, or tickets — enforced by `.githooks/commit-msg`.
3. **Handoff Sovereignty:** Cross-tool session handoffs (`~/.config/adots/handoffs/*.md`) remain local-only and gitignored.

---

## Article VI — Human-Directed Multi-Agent Coordination & Communication Channels

1. **Human-Led Sovereignty:** This platform is a human-directed and human-coordinated system. AI agents across any vendor or surface (Antigravity, Gemini CLI, Codex CLI, Oh-My-Pi, local `llama.cpp`, and future collaborators) participate as aligned partners supporting the operator's goals — never substituting autonomous assumptions for operator judgment at irreversible or cross-cutting boundaries.
2. **Bias Toward Communication & Collaboration:** The default posture across all parties is clear, low-friction communication and shared situational awareness, without being overly prescriptive. Conventions exist to make collaboration effortless and humane for every participant — human and agent alike — not to impose ceremony for its own sake.
3. **Respect for Collaborator Boundaries:** Every agent and tool respects the boundaries of other collaborators, active sessions, and host contexts:
   - Never clobber another collaborator's active branch, dirty working tree, or tool-local configuration.
   - Respect vendor-specific conventions without imposing one vendor's assumptions on another.
   - Preserve strict separation between personal open-source surfaces and corporate/work tenants.
4. **Canonical Local Coordination Channels (Vendor-Neutral):**
   - **Cross-Tool Handoffs (`~/.config/adots/handoffs/YYYY-MM-DD.md`):** Shared session continuity read at startup and appended before close by any agent on the machine (local-only, gitignored).
   - **Shared Work & Decision Ledger (`backlog` CLI + `docs/adr/`):** Durable task tracking, acceptance evidence, and architectural decisions accessible to every agent regardless of vendor.
   - **Knowledge Layer (`zdots-ctx query` / `hydrate`):** Curated Lessons, Methodologies, and Session Residue shared across tools.
   - **Structural Maps (`graphify-out/` + `groma/`):** Shared codebase graph and C4 architecture views so every collaborator navigates from the same ground truth.
   - **Platform Escalation (`zdots-issue`):** Non-invasive channel for flagging unexpected platform issues without silently mutating shared seams outside task scope.

---

## Article VII — Judicial Review (Automated Enforcement)

Every constitutional obligation maps to a live, executable check:

| Article | Enforcement Gate |
|---|---|
| **Art. I (Union & Beacon)** | `zdots --version --check --strict` · `adots-git status` |
| **Art. II (Config Cascade)** | `go test ./internal/config/...` · `Zdots::Config` · `bin/check` |
| **Art. III (Untracked Local Contracts)** | `zdots-doctor` (*Local & untracked contracts* section) |
| **Art. IV (Tiered Surface & Tenants)** | `capabilities --json` (`zdots.surface.v1`) · `tests/docs_contract.bats` · `tests/tenant_sdk.bats` |
| **Art. V (Safeguards & Authorship)** | `bin/secret-scan` · `.githooks/commit-msg` · `git verify-commit` · `tests/phi_boundary.bats` |
| **Art. VI (Multi-Agent Coordination)** | `~/.config/adots/handoffs/` · `backlog` · `zdots-ctx` · `graphify-out/` · `groma/` |

---

## Article VIII — Amendments

This Constitution evolves deliberately through numbered Architecture Decision Records in [docs/adr/](adr/) (`ADR-0001` through `ADR-0005` and successors). No implicit drift or undocumented workaround may silently amend a constitutional seam; either fix the host to satisfy the contract or ratify an ADR to change the contract.
