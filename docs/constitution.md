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
3. **The Astronomicon Beacon:** Deployed surfaces declared in `~/.config/adots/surfaces.conf` (overridable via `ZDOTS_SURFACES_FILE`) share a single imperial-CalVer `VERSION` epoch verified by `zdots --version --check` and `zdots-doctor`.

---

## Article II — Supremacy of the Configuration Cascade

1. **Single Source of Truth:** Canonical ports, loopback endpoints, database URLs, and storage reserves are declared once in [etc/defaults.env](../etc/defaults.env) and consumed identically across all three platform runtimes ([ADR-0005](adr/0005-tiered-cli-surface-and-tenant-contract.md)):
   - **Shell:** sourced first in [env.sh](../env.sh) using non-clobbering `${VAR:-default}` assignments.
   - **Go:** parsed by `cmd/zdots-core/internal/config` (process environment overrides defaults).
   - **Ruby:** parsed by `lib/zdots/config.rb` (process environment overrides defaults).
2. **Precedence Order (lowest → highest in login shell startup):**
   1. `etc/defaults.env` — tracked canonical platform defaults (non-clobbering)
   2. `.zdots.env` — dependency-injection provider wiring
   3. `~/.config/adots/profiles/<profile>.conf` — host deployment posture (`powerstation`, `work`)
   4. `.zdots.local` — untracked machine-local overrides
   5. `.zdots.work` — enforced work-host policy (when `ZDOTS_CONTEXT=work`; intentionally overrides weaker local settings)
   6. Per-command caller environment — overrides at invocation time after shell startup
3. **Prohibitions:**
   - No runtime may hardcode duplicated service ports or endpoints outside `etc/defaults.env` and its config reader.
   - No host or script may set `DATABASE_URL` (use `ZDOTS_DATABASE_URL` and `ZDOTS_MIGRATION_URL`).
   - No tracked template (LaunchAgent, agent config, or profile) may hardcode `/Users/<user>` home paths.

---

## Article III — Obligations of Deployed Hosts (Untracked Local Contracts)

Every host onto which the platform is deployed maintains untracked, machine-local state. Essential contracts are mandatory across all supported hosts; host-profile preferences apply only where the corresponding OS/application is present (and report explicitly as *not applicable* otherwise).

### Essential Contracts (All Hosts)
1. **Machine Identity Pointer (`~/.config/adots/profile`):**
   - Must remain **untracked and gitignored** in `adots` (`Z-277`).
   - Must contain a single valid profile token matching an existing `~/.config/adots/profiles/<profile>.conf`.
2. **Local Shell Overrides (`~/.config/zsh/.zdots.local`):**
   - When present, must pass POSIX syntax validation (`sh -n`), carry restrictive `0600` permissions, and never set `DATABASE_URL` or store raw secrets.
3. **Scoped Git Identity & Signing (`~/.config/git/`):**
   - `config.identity`, `config.signing`, and `allowed_signers` are machine-local and gitignored.
   - Core open-source repos (`zdots`, `adots`, `vdots`) must resolve to the operator's personal identity; corporate repos must default to the corporate identity. Bidirectional leakage is forbidden.
4. **Rendered Background Agents (macOS):**
   - Installed plists (such as `~/Library/LaunchAgents/com.zdots.log-rotate.plist`) must be rendered via their installer (`log-rotate --install-agent`), contain zero unrendered `__HOME__` / `__ZDOTDIR__` / `__XDG_STATE_HOME__` placeholders, and pass `plutil -lint`.

### Host-Profile Preferences (macOS / iTerm2, Optional by Host)
- On macOS hosts using iTerm2 with the `adots` Dynamic Profile (`zdots-kanagawa.json`), the host profile expects: Kanagawa Wave (Dark) / Lotus (Light) appearance-following, `Option` and `Right Option` set to `Esc+`, `Custom Directory = Recycle`, `Load Shell Integration Automatically = true`, `Default Bookmark Guid` pointing to a `zdots` profile, no stale duplicate `kanagawa-wave.json`, and explicit OSC 52 clipboard policy (`AllowClipboardAccess`, enabled on trusted workstations via `bin/bootstrap`).
- Non-macOS or non-iTerm hosts report this contract as **not applicable** rather than silently passing or failing.

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
   - Local storage of tenant/work material does **not** by itself authorize sharing its contents with every model or cloud provider; respect each host's data boundary.
2. **Cryptographic Authorship & Zero AI Attribution:**
   - Every commit and tag in core repos is signed with the operator's SSH signing key (1Password on macOS workstations); signing is never bypassed.
   - Zero AI-tool attribution (`Co-Authored-By`, badges, "Generated with…", session links) appears anywhere in commits, code, docs, or tickets — enforced by `.githooks/commit-msg`.
3. **Handoff Sovereignty:** Cross-tool session handoffs (`~/.config/adots/handoffs/*.md`) remain local-only and gitignored.

---

## Article VI — Human-Directed Multi-Agent Coordination & Communication Channels

1. **Human-Led Sovereignty & Bounded Autonomy:** This platform is a human-directed and human-coordinated system. AI agents across any vendor or surface (Antigravity, Gemini CLI, Codex CLI, Oh-My-Pi, local `llama.cpp`, and future collaborators) operate as aligned partners:
   - Escalate irreversible, destructive, or cross-cutting architectural decisions to the operator.
   - Complete already-authorized, reversible work cleanly without unnecessary back-and-forth.
2. **Bias Toward Communication & Collaboration:** Default to clear, low-friction communication and shared situational awareness without over-prescriptive bureaucracy. Conventions exist to make collaboration humane and reliable for every participant.
3. **Respect for Collaborator Boundaries:**
   - Never clobber another collaborator's active branch, dirty working tree, or tool-local configuration.
   - Respect vendor-specific conventions without imposing one vendor's assumptions on another.
   - Preserve strict separation between personal open-source surfaces and corporate/work tenants.
4. **Observability Under Sandbox Restrictions:** A sandboxed agent's inability to reach a local socket or loopback port (e.g., `Operation not permitted` causing services to appear `stopped`) is a **client visibility restriction**, not proof of a host outage. Report restricted-view probes as unverified rather than declaring a service down or starting workers.
5. **Lightweight Handoff & Coordination Protocol:**
   - **Append-only handoffs (`~/.config/adots/handoffs/YYYY-MM-DD.md`):** Read the latest file at session start; append a new dated heading before closing (use `YYYY-MM-DD-2.md` sibling if concurrent writes risk collision).
   - **Minimum handoff fields:** timestamp + timezone, host, repo + HEAD SHA, scope/owner, **verified evidence** (distinct from intentions/proposals), requested action (if any), and recipient acknowledgment when closing a cross-agent handoff.
   - **Unavailable channels:** Report inability to reach a channel concisely without mutating shared infrastructure or starting background daemons.
   - **Map freshness:** Before treating `graphify-out/` or `groma/` as current ground truth, verify their commit/timestamp freshness against `HEAD` (and note whether `groma/` is curated vs. raw first scan).
6. **Canonical Local Coordination Channels (Vendor-Neutral):**
   - **Cross-Tool Handoffs:** `~/.config/adots/handoffs/YYYY-MM-DD.md` (durable async continuity; optional manual bus is separate).
   - **Work & Decision Ledger:** `backlog` CLI + `docs/adr/`.
   - **Knowledge Layer:** `zdots-ctx query` / `hydrate`.
   - **Structural Maps:** `graphify-out/` + `groma/`.
   - **Platform Escalation:** `zdots-issue`.

---

## Article VII — Judicial Review (Enforcement Matrix)

Each obligation is classified honestly as **`enforced`** (automated gate fails on violation), **`partial`** (automated gate checks a subset; remainder is operator/review discipline), or **`manual`** (review/convention):

| Obligation | Coverage | Gate & Severity |
|---|---|---|
| **Art. I:** Astronomicon alignment across declared surfaces | **enforced** | `zdots --version --check --strict` (pre-push fail) · `zdots-doctor` (warn) |
| **Art. II:** `etc/defaults.env` parsing & precedence | **enforced** | `go test ./internal/config/...` · `Zdots::Config` |
| **Art. III:** `~/.config/adots/profile` exists & matches `.conf` | **partial** | `zdots-doctor` (fail/warn; gitignore verified via `adots-git check-ignore`) |
| **Art. III:** `.zdots.local` syntax, `0600` perms, no `DATABASE_URL` | **partial** | `zdots-doctor` (fail/warn; raw-secret absence checked via `bin/secret-scan` / review) |
| **Art. III:** `git/config.{identity,signing}` syntax | **partial** | `zdots-doctor` (fail on syntax; per-repo resolved email checked before commit) |
| **Art. III:** iTerm2 Dynamic Profile & defaults (macOS) | **partial** | `zdots-doctor` (warn on drift; `not applicable` off macOS/iTerm2) |
| **Art. III:** Rendered `com.zdots.log-rotate.plist` | **enforced** | `zdots-doctor` (`plutil -lint` + placeholder check, fail) |
| **Art. IV:** Tier-1 `--help`, man pages, `zdots.surface.v1`, `lib/sdk/` | **enforced** | `tests/docs_contract.bats` · `tests/tenant_sdk.bats` · `go test ./internal/capabilities/...` |
| **Art. V:** Secret scan, commit signing, zero AI attribution, PHI scrubber | **enforced** | `bin/secret-scan` · `.githooks/commit-msg` · `git verify-commit` · `tests/phi_boundary.bats` |
| **Art. VI:** Handoff protocol, boundary respect, sandbox honesty | **manual** | Cross-agent review & acknowledgment in `~/.config/adots/handoffs/` |

---

## Article VIII — Amendments

- **Architectural contract changes** (new seams, new tiers, breaking schema changes, or changes to core invariants) are ratified via numbered Architecture Decision Records in [docs/adr/](adr/).
- **Editorial and accuracy corrections** (fixing stale paths, tightening enforcement labels, or clarifying prose without changing contracts) may be committed directly with normal signed-commit review.
