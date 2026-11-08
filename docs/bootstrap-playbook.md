---
id: bootstrap-playbook
title: "Zdots Machine Bootstrap & AI Agent Orchestration Playbook"
purpose: Deterministic, end-to-end playbook for bootstrapping a fresh machine (work or personal) and delegating execution to an AI agent while preserving platform parity and cross-repo integrity.
audience: Platform Operator & Coding Agents
---

# Zdots Machine Bootstrap & AI Agent Orchestration Playbook

This playbook defines the exact sequence for bringing up a fresh macOS machine to full operational parity with your existing environment across all four platform repositories (`zdots`, `adots`, `vdots`, `my`), while strictly enforcing work/home isolation, security boundaries, and zero personal data leakage.

It is structured in two parts:
1. **Phase 0: The Human Handshake**: Manual prerequisites you perform at the keyboard before delegating.
2. **Phases 1–6: The Agent Playbook**: Deterministic steps, prompts, and verification gates that an AI coding agent (Claude Code, Antigravity, etc.) can execute autonomously.

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

## Phase 0: The Human Handshake (Manual Setup)

Perform these steps before starting any AI agent session.

### Step 0.1: macOS Prerequisites
Open Terminal and install Command Line Tools and Homebrew:
```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Step 0.2: Clone `zdots` (The Seed Repo)
Clone `zdots` to its canonical location under XDG config:
```bash
git clone https://github.com/just3ws/zdots.git ~/.config/zsh
cd ~/.config/zsh
```

### Step 0.3: Define Machine Context BEFORE Running Bootstrap
Bootstrap reads `.zdots.local` at launch. **You must configure this before running `bin/bootstrap`**, otherwise `ZDOTS_CONTEXT` defaults to `home`.

```bash
cp ~/.config/zsh/.zdots.local.example ~/.config/zsh/.zdots.local
$EDITOR ~/.config/zsh/.zdots.local
```

**For a Work Machine:**
```bash
ZDOTS_CONTEXT=work
GIT_AUTHOR_EMAIL="first.last@company.com"
GIT_COMMITTER_EMAIL="first.last@company.com"
# If corporate proxy is required:
# HTTP_PROXY=http://proxy.company.internal:8080
# HTTPS_PROXY=http://proxy.company.internal:8080
# NO_PROXY=localhost,127.0.0.1,.internal
```

**For a Personal Machine:**
```bash
ZDOTS_CONTEXT=home
```

### Step 0.4: Corporate IT Dotfile Pre-flight
`bin/bootstrap` automatically clones and restores `adots` to `$HOME`. On a corporate Mac with pre-installed IT management profiles, back up any collision-prone files:
```bash
mkdir -p ~/.it-backup-$(date +%Y%m%d)
cp -p ~/.zshrc ~/.bashrc ~/.gitconfig ~/.it-backup-*/ 2>/dev/null || true
```

---

## Phase 1: AI Agent Handoff

Once Phase 0 is complete, start your coding agent (e.g. `claude`, `agy`, or Antigravity IDE) in `~/.config/zsh` and provide the following prompt:

````markdown
You are bootstrapping this machine to full platform parity.
Follow the playbook at `~/.config/zsh/docs/bootstrap-playbook.md`.

Context:
- `~/.config/zsh/.zdots.local` has been created.
- Review `ZDOTS_CONTEXT` from `.zdots.local`.
- If `ZDOTS_CONTEXT=work`:
  - Never clone `github.com/just3ws/my` onto this machine.
  - Create the `~/my` skeleton using `adots-my prepare --apply`.
  - Maintain PHI-safe defaults: no session residue capture, local AI only.
  - Set `adots-profile work`.

Execute Phases 2 through 6 sequentially, verifying each gate before continuing.
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
