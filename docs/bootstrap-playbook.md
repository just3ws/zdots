---
id: bootstrap-playbook
title: "Zdots Machine Bootstrap & AI Agent Orchestration Playbook"
purpose: Deterministic, end-to-end playbook for bootstrapping a fresh machine (work or personal) and delegating execution to an AI agent while preserving platform parity and cross-repo integrity.
audience: Platform Operator & Coding Agents
---

# Zdots Machine Bootstrap & AI Agent Orchestration Playbook

This playbook defines the exact sequence for bringing up a fresh macOS machine to full operational parity across all four platform repositories (`zdots`, `adots`, `vdots`, `my`), while strictly enforcing work/home isolation, security boundaries, and zero personal data leakage.

> [!IMPORTANT]
> **Single-Link AI Agent Entrypoint:** You can hand this file directly to an AI coding agent via its GitHub URL (`https://github.com/just3ws/zdots/blob/main/docs/bootstrap-playbook.md` or raw `https://raw.githubusercontent.com/just3ws/zdots/main/docs/bootstrap-playbook.md`) even before `zdots` is cloned locally. The agent will follow the **Agent Behavioral Contract & Ambiguity Protocol** below, inspect the machine, ask you to resolve any ambiguities, complete Phase 0 with your confirmation, and execute Phases 1 through 6 safely.

> [!WARNING]
> **Pre-Configured or Existing Machines:** If this machine already has existing developer configurations, runtimes (e.g. PostgreSQL 17, mise, Colima), 1Password, an existing `~/.ssh` directory, or an IT onboarding log, the agent MUST switch immediately to the **[Work Machine Migration Playbook](work-migration-playbook.md)** (`https://raw.githubusercontent.com/just3ws/zdots/main/docs/work-migration-playbook.md`). Never run an unconditional `bin/bootstrap` over a pre-configured machine.

---

## 0. Agent Behavioral Contract: Play Nice & Ask on Ambiguity

When an AI agent reads this playbook from GitHub or local disk, it operates under the following non-negotiable behavioral rules:

1. **Ask the User When Ambiguity Exists (Zero Assumptions):**
   - Before writing `.zdots.local` or mutating the system, if any setting is ambiguous or unspecified (such as whether `ZDOTS_CONTEXT` is `work` or `home`, what corporate `GIT_AUTHOR_EMAIL` to configure, whether a corporate proxy is needed, or whether an existing tool/dotfile should be kept), **stop and ask the user directly**.
2. **Auto-Detect New vs. Pre-Existing Machine State First:**
   - Before cloning or running `bin/bootstrap`, probe `~/.zshrc`, `~/.gitconfig`, `~/.ssh/config`, `~/.config/mise/config.toml`, `brew leaves`, `mise ls`, and `pg_isready`.
   - If pre-existing developer toolchains, SSH keys/agents, or custom dotfiles are present, **do not run unconditional `bin/bootstrap`**. Notify the user and transition to `docs/work-migration-playbook.md` so all existing configurations are backed up and three-way merged.
3. **Play Nice with the Host OS & Existing Setup:**
   - Back up any pre-existing `$HOME` dotfiles to `~/.it-backup-$(date +%Y%m%d_%H%M%S)/` before modifying or linking anything.
   - Never overwrite `~/.ssh/config`, 1Password SSH agent sockets, or corporate certificates.
   - Never run `sudo brew services` (which corrupts `/opt/homebrew` permissions); use `nginx-ctl` or `sudo launchctl kickstart` for root daemons.
4. **Strict Work/Personal & PHI Isolation:**
   - On any `work` machine, configure `.zdots.local` with `ZDOTS_CONTEXT=work`, `ZDOTS_AI_MODE=local`, `ZDOTS_CAPTURE_ENABLED=0`, `ZDOTS_CMD_ANALYTICS=0`, and `ZDOTS_HISTORY_REDACT=1` **before** executing `bin/bootstrap`.
   - Never clone the personal `github.com/just3ws/my` vault onto a work machine; always scaffold `~/my` via `adots-my prepare --apply`.
   - Never read `.zdots.secrets`, `.env` files, private keys, or PHI-shaped data into context.
5. **Follow Platform Conventions:**
   - Manage `$HOME` dotfiles strictly through `adots` / `adots-git` wrappers (never raw `git` in `$HOME`, and never look for retired `gdots` or `tdots` repositories, which are consolidated into `adots`).
   - Once `rtk` is installed, proxy high-output git, container, and directory commands through `rtk` (`rtk git status`, `rtk git diff`, `rtk docker ps`).

---

## 1. System Topology & Parity Contract

| Component | Repository / Location | Shared vs Local Role | Parity Mechanism |
|---|---|---|---|
| **zdots** | `~/.config/zsh` | Core control plane, shell, CLI tools, base PHI registry | Git clone from source; posture governed by `ZDOTS_CONTEXT` |
| **adots** | `~/.homegit` (bare, `$HOME`) | Home directory dotfiles, platform bootstrap scripts | Bare git clone; machine profile via `adots-profile` |
| **vdots** | `~/.config/nvim` | Neovim configuration, plugins, keymaps | Git clone from source; local AI adapters verified |
| **my** | `~/my` | Knowledge layer, second brain, cockpit | **Independent repository & database**. Parity via `my.structure.v1` contract; personal vault content is **never cloned to work** |
| **work-ext** | `${ZDOTS_WORK_EXT:-~/.config/zdots-work}` | Work-only extensions, tenant PHI patterns, scripts | Independent external repository; fresh per employer |

---

## Phase 0: Pre-Flight & Context Handshake (Agent or Operator)

If `~/.config/zsh` or `~/.config/zsh/.zdots.local` does not exist yet when the agent starts, the agent executes these steps **after asking the user** to confirm `ZDOTS_CONTEXT` (`work` vs `home`), `GIT_AUTHOR_EMAIL` (if `work`), and whether any existing dotfiles are present.

### Step 0.1: macOS Prerequisites & Baseline Check
Verify Command Line Tools, Homebrew, and check whether the machine already has existing configurations:
```bash
xcode-select -p || xcode-select --install
command -v brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Probe for pre-existing developer state (if found, switch to docs/work-migration-playbook.md):
ls -la ~/.zshrc ~/.gitconfig ~/.ssh/config ~/.config/mise/config.toml 2>/dev/null || true
```

### Step 0.2: Clone `zdots` (The Seed Repo)
Clone `zdots` to its canonical location under XDG config if not already present:
```bash
if [ ! -d "$HOME/.config/zsh/.git" ]; then
  git clone https://github.com/just3ws/zdots.git ~/.config/zsh
fi
cd ~/.config/zsh
```

### Step 0.3: Define Machine Context BEFORE Running Bootstrap
Bootstrap reads `.zdots.local` at launch. **You must configure this before running `bin/bootstrap`**, otherwise `ZDOTS_CONTEXT` defaults to `home`. If `.zdots.local` does not exist, ask the user for any missing values (such as their work email) before creating it:

```bash
cp -n ~/.config/zsh/.zdots.local.example ~/.config/zsh/.zdots.local
```

**For a Work Machine:**
```bash
ZDOTS_CONTEXT=work
ZDOTS_AI_MODE=local
ZDOTS_CAPTURE_ENABLED=0
ZDOTS_CMD_ANALYTICS=0
ZDOTS_HISTORY_REDACT=1
GIT_AUTHOR_EMAIL="first.last@company.com"
GIT_COMMITTER_EMAIL="first.last@company.com"
# If corporate machine runs PostgreSQL 17 (instead of default 18):
# ZDOTS_POSTGRES_VERSION=17
# If corporate proxy is required:
# HTTP_PROXY=http://proxy.company.internal:8080
# HTTPS_PROXY=http://proxy.company.internal:8080
# NO_PROXY=localhost,127.0.0.1,.internal
```

**For a Personal Machine:**
```bash
ZDOTS_CONTEXT=home
```

### Step 0.4: Pre-flight Dotfile Backup
`bin/bootstrap` automatically clones and restores `adots` to `$HOME`. Always back up any pre-existing files first:
```bash
mkdir -p ~/.it-backup-$(date +%Y%m%d_%H%M%S)
cp -p ~/.zshrc ~/.bashrc ~/.gitconfig ~/.zshenv ~/.it-backup-*/ 2>/dev/null || true
```

---

## Phase 1: Single-Prompt AI Agent Invocation

You can launch your coding agent (Claude Code, Gemini CLI, Codex, or Antigravity) from anywhere on the machine and simply point it at this playbook on GitHub:

````markdown
Read https://raw.githubusercontent.com/just3ws/zdots/main/docs/bootstrap-playbook.md and follow it to bootstrap this machine safely. Ask me whenever there is any ambiguity before making changes.
````

If `~/.config/zsh` is already cloned locally:

````markdown
Read ~/.config/zsh/docs/bootstrap-playbook.md and follow it to bootstrap this machine safely. Ask me whenever there is any ambiguity before making changes.
````

---

## Phase 2: Core Platform Bootstrap (`zdots`)

The agent executes the automated bootstrap orchestrator:

```bash
~/.config/zsh/bin/bootstrap
```

### What this executes:
1. Validates Homebrew installation and selects `Brewfile.work` or `Brewfile.home` based on `ZDOTS_CONTEXT`.
2. Creates canonical XDG directory trees (`~/.config`, `~/.local/state/zsh`, `~/.cache`).
3. Clones companion repositories:
   - `adots` bare repository at `~/.homegit` with work-tree `$HOME`.
   - `vdots` Neovim configuration at `~/.config/nvim`.
4. Symlinks shell entry points (`~/.zshenv`, `~/.bashrc`, `~/.bash_profile`).
5. Configures launchd services: `llama.cpp` (local AI model, non-blocking download) and `otel-collector`.
6. Configures local nginx reverse proxy and certificates (`mkcert`).
7. Initializes the `my` PostgreSQL database and runs migrations.

### Agent Verification Gate 2:
```bash
# Verify bootstrap exited cleanly
tail -n 30 ~/.local/state/zsh/bootstrap-latest.log | grep -E "complete|summary|ready"
```

---

## Phase 3: Machine Identity & `adots` Supervision

`adots` tracks dotfiles under `$HOME` via a bare Git repository. The agent sets machine profile and verifies git boundaries:

```bash
# 1. Set machine profile
if [ "$ZDOTS_CONTEXT" = "work" ]; then
  adots-profile work
else
  adots-profile powerstation
fi

# 2. Validate machine profile
adots-profile validate

# 3. Check git work-tree hygiene
GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git status -s
```

---

## Phase 4: The `~/my` Parity Skeleton (Zero Data Leakage)

To retain strict separation, **`~/my` is never cloned from the personal remote on a work machine**. Instead, parity is established through the `my.structure.v1` structural contract:

```bash
# 1. Preview skeleton creation
adots-my prepare --dry-run

# 2. Apply directory scaffolding, template configs, and VERSION epoch marker
adots-my prepare --apply

# 3. Initialize fresh work-local Git repository
if [ ! -d "$HOME/my/.git" ]; then
  cd "$HOME/my"
  git init -b main
  git add .
  git commit -m "chore: initialize clean my.structure.v1 knowledge layer"
fi

# 4. Validate complete structural contract
adots-my doctor
```

### Expected `adots-my doctor` Output:
```text
adots-my: checking /Users/.../my (my.structure.v1)
adots-my: ok: Astronomicon platform epoch (/Users/.../my/VERSION)
adots-my: ok: structure contract (my.structure.v1)
adots-my: ok: contract declaration (/Users/.../my/config/structure.yml)
adots-my: ok: ~/my is a separate Git work tree (/Users/.../my)
adots-my: ok: source registry (/Users/.../my/config/sources.yml)
adots-my: ok: context engine (/Users/.../my/context-engine)
adots-my: ok: private Obsidian vault (/Users/.../my/vaults/personal)
adots-my: ok: archive root (/Users/.../my/.archive)
adots-my: summary: 11 passed, 0 warning(s), 0 failure(s)
```

*(Note: On a fresh work machine without a remote, `adots-my doctor` can accept a local origin or company remote).*

---

## Phase 5: `vdots` & Editor AI Safety Check

Neovim configuration is synchronized from `vdots`. The agent must verify that editor AI integrations respect the machine posture:

```bash
# 1. Headless plugin sync
nvim --headless "+Lazy! sync" +qa

# 2. Verify AI routing
# Ensure CodeCompanion / ai-query defaults to local model or approved endpoint
printenv ZDOTS_AI_MODE
# If work: must be 'local' or 'none'
```

---

## Phase 6: Final Verification & Sanity Matrix

The agent runs the canonical diagnostic suite to prove full readiness:

```bash
# 1. Work Posture Verification
printenv ZDOTS_CONTEXT ZDOTS_AI_MODE ZDOTS_CAPTURE_ENABLED ZDOTS_HISTORY_REDACT ZDOTS_CMD_ANALYTICS

# Work Context Expected Values:
# ZDOTS_CONTEXT=work
# ZDOTS_AI_MODE=local (or none)
# ZDOTS_CAPTURE_ENABLED=0
# ZDOTS_HISTORY_REDACT=1
# ZDOTS_CMD_ANALYTICS=0

# 2. Platform Service Checks
capabilities --json
agent-guide --json
zdots-ctl check
adots-profile validate
adots-my doctor
```

---

## 7. Employer Extension Repository (Work Only)

If your employer requires custom scripts, internal tool wrappers, or company-specific PHI patterns:
1. Create a dedicated repository at `${ZDOTS_WORK_EXT:-~/.config/zdots-work}`.
2. It must have its own remote and history (never nested inside or submodule of `zdots`).
3. Keep it strictly external to `adots`, `zdots`, and `my`.
