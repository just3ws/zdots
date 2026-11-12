---
id: work-migration-playbook
title: "Work Machine Migration & AI Agent Onboarding Playbook"
purpose: Deterministic, safe playbook for an AI agent to evaluate, reconcile, and migrate zdots, adots, and vdots onto a pre-configured work machine without clobbering existing developer setups.
audience: Platform Operator & Coding Agents
canonical: true
---

# Work Machine Migration & AI Agent Onboarding Playbook

This playbook provides deterministic instructions for an AI agent (Claude Code, Gemini CLI, Codex, or Antigravity) to safely evaluate, reconcile, and configure `zdots`, `adots`, and `vdots` on a corporate-managed or pre-existing Mac with prior developer configurations.

> [!IMPORTANT]
> **Single-Link AI Agent Entrypoint:** You only need to tell your AI agent to read this file from GitHub (`https://github.com/just3ws/zdots/blob/main/docs/work-migration-playbook.md` or raw `https://raw.githubusercontent.com/just3ws/zdots/main/docs/work-migration-playbook.md`), even before `zdots` is cloned locally. The agent will follow the **Agent Behavioral Contract & Ambiguity Protocol** below, inspect the existing machine non-destructively, ask you whenever anything is ambiguous, complete Phase 0 with your confirmation, present the Phase 1 Reconciliation Matrix for approval, and execute Phases 2 through 10 safely.

It prevents common migration hazards:
1. **Zero Overwrite of IT Configurations:** Protects pre-existing shell setups, corporate `~/.ssh`, and 1Password integrations.
2. **Postgres 17 Parity:** Seamlessly binds to the machine's existing PostgreSQL 17 without installing or colliding with PostgreSQL 18.
3. **Mise Three-Way Merge:** Preserves work project runtime pins (Node, Ruby, Python, Go) while providing access to platform CLI tools.
4. **Colima Preservation:** Enforces Colima as the container engine while detecting and purging conflicting Docker Desktop remnants.
5. **Homebrew Audit:** Reconciles `Brewfile.work` against the initial setup log, adopting corporate defaults and excluding App Store (`mas`) dependencies.
6. **Zero Personal Data Leakage:** Enforces `my.structure.v1` skeleton scaffolding without ever cloning the personal `~/my` vault.
7. **Local TLS Edge & Nginx Parity:** Sets up `mkcert` and root `nginx` to provide the 6 foundational `*.localhost` service endpoints over HTTPS without corrupting Homebrew file ownership.
8. **Token Optimization (RTK):** Mandates `rtk` proxying for git/container inspection to preserve context window budgets.

---

## 0. Agent Behavioral Contract: Play Nice & Ask on Ambiguity

When an AI agent is pointed to this playbook on GitHub or local disk, it MUST adhere to these rules at every step:

1. **Stop and Ask on Ambiguity (Never Guess):**
   - Whenever an environment value, file conflict, or policy choice is ambiguous (e.g., what corporate `GIT_AUTHOR_EMAIL` to set in `.zdots.local`, where the IT onboarding log is located, whether an existing runtime pin or Homebrew formula is required by a company repo, or how to resolve a dotfile diff), **pause and ask the user before making changes**.
2. **Audit First, Backup Second, Mutate Third:**
   - Never run an unconditional `bin/bootstrap` or `git checkout -- .` in `$HOME` on a pre-existing machine.
   - Complete Phase 1 (non-destructive inventory) and present the **Reconciliation Matrix** to the user. Wait for explicit user confirmation before modifying packages or dotfiles.
   - Always create a timestamped snapshot in `~/.it-backup-$(date +%Y%m%d_%H%M%S)/` (Phase 2) before touching any file.
3. **Play Nice with Pre-Existing Developer Tooling:**
   - **SSH & 1Password:** Never run `github-keygen` if 1Password or corporate SSH keys are present; never overwrite `~/.ssh/config`.
   - **Runtimes (`mise`):** Perform a three-way merge on `~/.config/mise/config.toml` so all corporate project language versions remain intact.
   - **Database (`PostgreSQL`):** Detect the installed PostgreSQL version (`pg_config` / `postgresql@17`) and set `ZDOTS_POSTGRES_VERSION` accordingly instead of forcing a conflicting version.
   - **Homebrew & Nginx:** Never run `sudo brew services` (which corrupts `/opt/homebrew` ownership); manage root `nginx` via `nginx-ctl` or `sudo launchctl kickstart`.
4. **Strict Work/Personal & PHI Isolation:**
   - Enforce `ZDOTS_CONTEXT=work`, `ZDOTS_AI_MODE=local`, `ZDOTS_CAPTURE_ENABLED=0`, `ZDOTS_CMD_ANALYTICS=0`, and `ZDOTS_HISTORY_REDACT=1` in `~/.config/zsh/.zdots.local`.
   - **Never** clone `github.com/just3ws/my` onto a work machine; scaffold `~/my` exclusively with `adots-my prepare --apply`.
   - **Never** read `.zdots.secrets`, `.env` files, private SSH keys, or PHI-shaped files into LLM prompts/context.
   - Configure dual Git identity (`includeIf`) so corporate repositories use the work email while `just3ws/*` platform repositories (`zdots`, `adots`, `vdots`) resolve to `mike@just3ws.com`.
5. **Follow Platform Conventions:**
   - Use `adots` / `adots-git` wrappers for `$HOME` dotfile operations (never raw `git` in `$HOME`, and never search for retired `gdots` or `tdots` repos).
   - Once `rtk` is available, proxy verbose commands through `rtk` (`rtk git status`, `rtk git diff`, `rtk docker ps`).

---

## System Topology & Work Boundaries

| Component | Target Location | Work Role & Parity Mechanism | Isolation & Safety Rules |
|---|---|---|---|
| **zdots** | `~/.config/zsh` | Core control plane, shell, CLI tools | Governed by `ZDOTS_CONTEXT=work`. Local AI only, no residue capture, no command analytics. |
| **adots** | `~/.homegit` (bare, `$HOME`) | Home directory dotfiles | Machine profile `work`. **Selective restore only**; never clobbers pre-existing IT dotfiles. |
| **vdots** | `~/.config/nvim` | Neovim configuration | Pinned to local AI (`ai-query`) or approved company endpoints. |
| **my** | `~/my` | Knowledge layer & second brain | **Independent repo & database**. Generated via `adots-my prepare --apply`. **NEVER cloned from personal remote**. |
| **work-ext** | `${ZDOTS_WORK_EXT:-~/.config/zdots-work}` | Work scripts & tenant PHI patterns | Isolated external repository. Fresh per employer. |

> [!NOTE]
> **Consolidated Historical *dots Repositories (`gdots` & `tdots`):**
> Historical standalone repositories `gdots` (Git configuration) and `tdots` (Tmux configuration) have been **consolidated directly into `adots`**:
> - Git configs live at `~/.config/git/config`, `~/.gitconfig`, `~/.gitignore_global`, `~/.mailmap`.
> - Tmux configs live at `~/.config/tmux/tmux.conf`.
> 
> The agent must NOT search for or attempt to clone separate `gdots` or `tdots` repositories. They are natively delivered and supervised through `adots`.

---

## Hardware Context: Apple Silicon M5 MBP (24GB RAM / 1TB SSD)

The target machine is significantly more capable than the 16GB / 256GB storage-constrained home profile:
* **Memory Headroom (24GB Unified):** Unlike a 16GB machine where running Colima, local AI, and application services concurrently creates swap pressure, a 24GB host can comfortably allocate 8–10 GiB to Colima while retaining 4–6 GiB for local AI models and 8+ GiB for macOS and developer tooling.
* **Storage Freedom (1TB SSD):** The strict 45 GiB disk-starvation guardrail on the home machine does not bind here. Colima disk allocations, Docker build layers, model GGUFs, and toolchain caches have abundant room.
* **M5 Multi-Core Throughput:** Higher core count enables parallel compilation (`MAKEFLAGS="-j$(sysctl -n hw.ncpu)"` and Bundler `--jobs=$(sysctl -n hw.ncpu)`).

---

## Phase 0: Pre-Flight & Context Handshake (Agent or Operator)

If `~/.config/zsh` or `~/.config/zsh/.zdots.local` does not exist yet when the AI agent starts, the agent executes these steps **after asking the user** for their work `GIT_AUTHOR_EMAIL` and (if applicable) the location of any initial IT onboarding log.

### 0.1: Locate Setup Log (If Available)
Check whether an initial developer onboarding log file (e.g. `onboarding.log` or `setup.log`) is present at `~/.local/state/work-onboarding.log`, or ask the user for its path if they have one:
```bash
ls -la ~/.local/state/work-onboarding.log 2>/dev/null || true
```

### 0.2: Clone `zdots` (Seed Repository)
If `~/.config/zsh` is not yet cloned, clone it now:
```bash
if [ ! -d "$HOME/.config/zsh/.git" ]; then
  git clone https://github.com/just3ws/zdots.git ~/.config/zsh
fi
cd ~/.config/zsh
```

### 0.3: Initialize Machine Posture BEFORE Bootstrap
Create and configure `~/.config/zsh/.zdots.local` immediately (ask the user for `GIT_AUTHOR_EMAIL` if not yet known):
```bash
cp -n ~/.config/zsh/.zdots.local.example ~/.config/zsh/.zdots.local
```
Ensure `~/.config/zsh/.zdots.local` contains these minimum entries:
```bash
# Core Machine Posture (NON-NEGOTIABLE)
ZDOTS_CONTEXT=work
ZDOTS_AI_MODE=local
ZDOTS_CAPTURE_ENABLED=0
ZDOTS_CMD_ANALYTICS=0
ZDOTS_HISTORY_REDACT=1

# PostgreSQL 17 Dynamic Binding
ZDOTS_POSTGRES_VERSION=17
# Uncomment if Postgres 17 is already running as a system/brew service:
# ZDOTS_SKIP_POSTGRES_BREW=1

# Corporate Git Identity
GIT_AUTHOR_EMAIL="first.last@company.com"
GIT_COMMITTER_EMAIL="first.last@company.com"

# M5 MBP Hardware Sizing (24GB RAM / 1TB Storage)
ZDOTS_COLIMA_CPU=6                          # Up from 4 on 16GB
ZDOTS_COLIMA_MEMORY=10                      # 10GB for heavy multi-container stacks (up from 8)
ZDOTS_COLIMA_DISK=100                       # 100GB container storage (up from 60)
ZDOTS_AI_PROFILE=work-light                 # 4B always-on reasoning default (~4GB footprint)
# Or for higher reasoning capacity when idle:
# ZDOTS_AI_PROFILE=qwen3-14b
# ZDOTS_SPEC_DECODING=1                     # Speculative decoding fits in 24GB

# Network & Proxy (if required by corporate network)
# HTTP_PROXY=http://proxy.company.internal:8080
# HTTPS_PROXY=http://proxy.company.internal:8080
# NO_PROXY=localhost,127.0.0.1,.internal
```

---

## Single-Prompt AI Agent Invocation

You only need to give your AI agent a single instruction pointing to the GitHub URL (even before cloning anything locally):

````markdown
Read https://raw.githubusercontent.com/just3ws/zdots/main/docs/work-migration-playbook.md and follow it to safely integrate the platform into this pre-existing machine. Play nice with existing configurations and ask me whenever there is any ambiguity before making changes.
````

Or if `~/.config/zsh` is already cloned on disk:

````markdown
Read ~/.config/zsh/docs/work-migration-playbook.md and follow it to safely integrate the platform into this pre-existing machine. Play nice with existing configurations and ask me whenever there is any ambiguity before making changes.
````

---

## Phase 1: Setup Log Ingestion & System Inventory (Audit Before Action)

The agent must inspect and inventory the machine before modifying any file.

### Step 1.1: Parse the Setup Log
Read the provided setup log:
```bash
cat ~/.local/state/work-onboarding.log
```
Extract and catalog:
- Installed Homebrew formulas, casks, and custom corporate taps.
- Installed `mise` plugins, tools, and pinned language runtimes.
- Colima startup parameters and VM allocation (CPU, memory, disk).
- PostgreSQL 17 service name, port, socket directory, and user.
- 1Password CLI / SSH agent setup.
- Any corporate proxy variables or custom SSL root certificates.

### Step 1.2: Audit Live Machine Baseline
Run live non-destructive probes:
```bash
# 1. Package inventory
brew leaves
brew list --cask

# 2. Runtimes
mise ls
cat ~/.config/mise/config.toml 2>/dev/null || true

# 3. Container runtime
colima-status --json 2>/dev/null || colima status 2>/dev/null || true
ls -la /var/run/docker.sock 2>/dev/null || true
cat ~/.docker/config.json 2>/dev/null || true

# 4. PostgreSQL 17 detection
which pg_config || brew --prefix postgresql@17 2>/dev/null || true
pg_isready 2>/dev/null || true

# 5. SSH & 1Password
ls -la ~/.ssh
cat ~/.ssh/config 2>/dev/null | grep -E "IdentityAgent|Host" || true
op whoami 2>/dev/null || true

# 6. Git signing & identity
git config --list --show-origin | grep -E "user\.|gpg\.|commit\."
```

### Step 1.3: Emit the Reconciliation Matrix
The agent must produce a markdown summary table for the operator:
* **Work Defaults to Retain:** Corporate runtimes, existing SSH configs, corporate taps, Postgres 17.
* **Platform Additions to Adopt:** zdots CLI tools (`rtk`, `backlog-md`, `bat`, `eza`, `fzf`, Neovim).
* **Conflicts to Mitigate:** Clobbering `~/.config/mise/config.toml`, Postgres 18 formula collisions, Docker Desktop socket overrides.

---

## Phase 2: Pre-Flight Safety Backup (Zero Destruction)

Before any files are touched or restored, snapshot existing user configurations:

```bash
BACKUP_DIR="$HOME/.it-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup dotfiles that adots or bootstrap might touch
for f in .zshrc .bashrc .bash_profile .profile .gitconfig .npmrc .zshenv; do
  [ -f "$HOME/$f" ] && cp -p "$HOME/$f" "$BACKUP_DIR/"
done

# Backup mise config
if [ -d "$HOME/.config/mise" ]; then
  mkdir -p "$BACKUP_DIR/mise"
  cp -rp "$HOME/.config/mise" "$BACKUP_DIR/"
fi

# Secure backup of ~/.ssh config (metadata and config only, never private keys)
if [ -f "$HOME/.ssh/config" ]; then
  mkdir -p "$BACKUP_DIR/ssh"
  cp -p "$HOME/.ssh/config" "$BACKUP_DIR/ssh/"
fi

echo "Pre-flight snapshot saved to $BACKUP_DIR"
```

---

## Phase 3: Package & Toolchain Reconciliation

### Step 3.1: Audit & Update `Brewfile.work`
1. Check that `Brewfile.work` and `Brewfile.common` contain **no `mas` lines**.
2. If the setup log or `brew leaves` showed useful corporate utilities, add them to `Brewfile.work`.
3. If PostgreSQL 17 is already installed and managed via Homebrew or system launchd:
   - Ensure `ZDOTS_POSTGRES_VERSION=17` is in `~/.config/zsh/.zdots.local`.
   - Set `ZDOTS_SKIP_POSTGRES_BREW=1` if you do not want Homebrew Bundle to attempt service adjustments on Postgres.
4. Run bundle check first:
   ```bash
   brew bundle check --file=~/.config/zsh/Brewfile.work || true
   ```
5. Install missing work packages:
   ```bash
   brew bundle --file=~/.config/zsh/Brewfile.work
   ```

### Step 3.2: Foundational RTK (Reduced Token Kernel) Verification
`rtk` is a core platform requirement for token efficiency. It intercepts verbose terminal outputs and compresses them before they hit LLM context windows:
1. Verify `rtk` binary:
   ```bash
   which rtk && rtk --version
   ```
2. **Mandatory Agent Rule:** All subsequent high-output commands throughout migration and development MUST be proxied through `rtk`:
   - Git: `rtk git status`, `rtk git diff`, `rtk git log`
   - Containers: `rtk docker ps`, `rtk docker logs`
   - Filesystem / Analysis: `rtk tokei`, `rtk summary <cmd>`

### Step 3.3: Reconcile `mise` Configuration & Apple Silicon Ruby Flags
Do **not** replace `~/.config/mise/config.toml` with the version tracked in `adots`. Instead, perform a clean merge:
1. **Preserve Corporate Runtimes:** Keep all existing language version pins (Node, Ruby, Python, Go, Java) from the work machine's `config.toml`.
2. **Apple Silicon Compilation Flags:** When mise builds Ruby from source on an M-series Mac, it must use jemalloc and Homebrew's openssl@3:
   ```bash
   _brew_pfx="$(brew --prefix)"
   RUBY_CONFIGURE_OPTS="--with-jemalloc --with-openssl-dir=${_brew_pfx}/opt/openssl@3" mise install
   ```
3. **Adots Postinstall Hook:** Ensure `~/.config/mise/config.toml` includes the default-gems hook:
   ```toml
   [tools]
   ruby = { version = "4.0.9", postinstall = "bash -lc 'if [ -x \"$HOME/.config/zsh/bin/zdots-ruby-default-gems\" ]; then \"$HOME/.config/zsh/bin/zdots-ruby-default-gems\" \"$MISE_TOOL_VERSION\"; fi'" }
   ```
4. **Trust Repositories:**
   ```bash
   mise trust ~/.config/zsh/mise.toml
   ```

### Step 3.4: Verify Colima & Purge Docker Desktop Conflicts
1. Verify no Docker Desktop socket hijacks exist:
   ```bash
   # If /var/run/docker.sock points to Docker Desktop, remove or repoint to colima
   if [ -L /var/run/docker.sock ] && ls -l /var/run/docker.sock | grep -qi "docker.raw"; then
     echo "WARNING: /var/run/docker.sock points to Docker Desktop"
   fi
   ```
2. Clean `~/.docker/config.json`:
   If `"credsStore": "desktop"` is present, replace with `"colima"` or remove the invalid credsStore entry so the Docker CLI uses standard keychain helpers.
3. Verify authoritative Colima socket:
   ```bash
   colima-status --json
   export DOCKER_HOST="unix://$(colima-status socket)"
   docker ps
   ```

---

## Phase 4: SSH, 1Password & Git Identity

### Step 4.1: Protect & Audit `~/.ssh`
1. Confirm permissions:
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/config 2>/dev/null || true
   chmod 600 ~/.ssh/id_* 2>/dev/null || true
   chmod 644 ~/.ssh/*.pub 2>/dev/null || true
   ```
2. Validate 1Password SSH Agent integration:
   In `~/.ssh/config`, ensure the IdentityAgent stanza matches the macOS 1Password socket:
   ```ssh
   Host *
     IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
   ```

> [!IMPORTANT]
> **Tool Guidance: `github-keygen` vs. 1Password SSH Agent**
> * **Do NOT run `github-keygen` if 1Password manages SSH keys:** `github-keygen` (and `zdots-github-keys`) generates physical private key files on disk and rewrites `~/.ssh/config` managed blocks. On a modern corporate Mac, SSH keys live securely in 1Password's vault.
> * **Transport (SSH) vs. Authorship (Git):**
>   - Host aliases like `work.github.com` or `home.github.com` only control **which SSH key authenticates to GitHub**.
>   - They do **not** control git commit author email. Commit authorship is governed strictly by the Git `includeIf` configuration in Step 4.3 below.
>   - If the corporate setup uses a dedicated work SSH key in 1Password, you can route it via `~/.ssh/config` host blocks without creating physical disk keys.

### Step 4.2: Verify 1Password CLI (`op`)
```bash
op whoami
```

### Step 4.3: Configure Dual Git Identity & Signing (Work Default vs. `just3ws` Repositories)

**The Multi-Context Separation Contract:**
The operator uses their `just3ws` GitHub account for both personal platform repositories and corporate organization repositories:
- Commits to corporate repositories (or any newly created repo on the machine) must strictly use the **work identity** (`GIT_AUTHOR_EMAIL="first.last@company.com"`).
- Commits to personal platform repositories (`zdots`, `adots`, `vdots`, and any `just3ws/*` repo) must strictly use the **personal identity** (`mike@just3ws.com`), avoiding any leak of `mike@just3ws.com` into work projects or corporate emails into public personal repos.

1. **Configure Machine Default Identity (`~/.config/git/config.identity`):**
   ```bash
   WORK_EMAIL="$(git config -f ~/.config/zsh/.zdots.local --get GIT_AUTHOR_EMAIL)"
   cat << EOF > ~/.config/git/config.identity
   [user]
   	name = Mike Hall
   	email = ${WORK_EMAIL}
   EOF
   ```

2. **Configure Personal Identity (`~/.config/git/config.identity.home`):**
   ```bash
   cat << 'EOF' > ~/.config/git/config.identity.home
   [user]
   	name = Mike Hall
   	email = mike@just3ws.com
   EOF
   ```

3. **Verify Automatic Identity Resolution in `~/.config/git/config`:**
   Ensure `~/.config/git/config` contains the scoped `includeIf` directives:
   ```gitconfig
   [include]
   	path = ~/.config/git/config.identity

   # Automatic personal identity scoping for just3ws repositories (SSH and HTTPS):
   [includeIf "hasconfig:remote.*.url:*github.com:just3ws/*"]
   	path = ~/.config/git/config.identity.home
   [includeIf "hasconfig:remote.*.url:*github.com/just3ws/*"]
   	path = ~/.config/git/config.identity.home

   # Directory-based fallback guarantees for platform repositories:
   [includeIf "gitdir:~/.config/zsh/"]
   	path = ~/.config/git/config.identity.home
   [includeIf "gitdir:~/.homegit/"]
   	path = ~/.config/git/config.identity.home
   [includeIf "gitdir:~/.config/nvim/"]
   	path = ~/.config/git/config.identity.home
   ```

4. **1Password SSH Commit Signing:**
   ```bash
   git config --global gpg.format ssh
   git config --global commit.gpgsign true
   # If 1Password SSH signing key was established in the setup log:
   # git config --global user.signingkey "ssh-ed25519 ..."
   ```

5. **Mandatory Identity Verification Gate:**
   The agent MUST prove that both identities resolve cleanly before proceeding:
   ```bash
   # Test A: Personal platform repo (MUST resolve to mike@just3ws.com)
   PLATFORM_EMAIL="$(git -C ~/.config/zsh config user.email)"
   if [ "$PLATFORM_EMAIL" != "mike@just3ws.com" ]; then
     echo "ERROR: Platform repo resolved to unexpected identity: $PLATFORM_EMAIL"
     exit 1
   fi

   # Test B: Corporate/default repo (MUST resolve to work email)
   WORK_EMAIL_CONF="$(git config -f ~/.config/git/config.identity user.email)"
   echo "Platform identity verified: $PLATFORM_EMAIL (in ~/.config/zsh)"
   echo "Work default identity verified: $WORK_EMAIL_CONF (for corporate repositories)"
   ```

---

## Phase 5: Companion Repositories & Selective `adots` Supervision

### Step 5.1: Clone `adots` (Bare Repository)
```bash
if [ ! -d "$HOME/.homegit" ]; then
  git clone --bare https://github.com/just3ws/adots.git "$HOME/.homegit"
fi
```

### Step 5.2: Selective Diff & Restore (DO NOT Run Unconditional Restore)
Inspect differences between `adots` HEAD and the work machine's `$HOME`:
```bash
GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git status -s
```
* **For new utility files (e.g. `.ripgreprc`, `.config/bat`, `.config/ghostty`):**
  Restore safely:
  ```bash
  GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git checkout HEAD -- <path>
  ```
* **For colliding shell files (`.zshrc`, `.bashrc`, `.profile`):**
  Do **not** overwrite. Ensure the work shell sources `~/.config/zsh/.zshenv` or uses standard zdots entrypoints.
* **For `~/.config/mise/config.toml`:** Keep the merged version created in Phase 3.

### Step 5.3: Set Machine Profile
```bash
adots-profile work
adots-profile validate
```

### Step 5.4: Clone `vdots` (Neovim)
```bash
if [ ! -d "$HOME/.config/nvim" ]; then
  git clone https://github.com/just3ws/vdots.git "$HOME/.config/nvim"
fi
# Headless plugin sync
nvim --headless "+Lazy! sync" +qa
```

---

## Phase 6: The `~/my` Structural Skeleton (Zero Data Leakage)

**Strict Rule:** NEVER clone `github.com/just3ws/my` (personal vault) onto a work machine.

Seed the clean `my.structure.v1` skeleton:
```bash
# 1. Preview skeleton creation
adots-my prepare --dry-run

# 2. Apply directory scaffolding and VERSION epoch marker
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

---

## Phase 7: PostgreSQL 17 Dynamic Binding & Ruby Extensions

### Step 7.1: Resolve `pg_config` for Postgres 17
Confirm `pg_config` path:
```bash
PG_CONFIG_BIN="$(which pg_config || printf '%s/opt/postgresql@17/bin/pg_config' "$(brew --prefix)")"
if [ ! -x "$PG_CONFIG_BIN" ]; then
  echo "ERROR: pg_config not executable at $PG_CONFIG_BIN"
else
  echo "Using pg_config: $PG_CONFIG_BIN ($("$PG_CONFIG_BIN" --version))"
fi
```

### Step 7.2: Install Ruby Gems with Native Postgres Extension
Compile the native `pg` gem using the Postgres 17 configuration:
```bash
RUBY_VER="$(cat ~/.config/zsh/etc/ruby-version)"
MISE_BUNDLE="$HOME/.local/share/mise/installs/ruby/${RUBY_VER}/bin/bundle"

if [ -x "$MISE_BUNDLE" ]; then
  BUNDLE_GEMFILE=~/.config/zsh/Gemfile \
  BUNDLE_BUILD__PG="--with-pg-config=${PG_CONFIG_BIN}" \
    "$MISE_BUNDLE" install
fi
```

### Step 7.3: Initialize `my` Database Migrations
Ensure the `my` database exists on Postgres 17 and run migrations:
```bash
createdb my 2>/dev/null || true
~/.config/zsh/bin/zdots-ctx migrate
```

---

## Phase 8: Local TLS Edge & Nginx Reverse Proxy Setup (Full Machine Parity)

To establish full operational parity with the primary machine, local services must be fronted over secure HTTPS via `*.localhost` (RFC 6761, no `/etc/hosts` editing needed).

### Step 8.1: Install & Trust Local CA (`mkcert`)
`mkcert` creates a local certificate authority and installs it into the macOS System Keychain and local browser NSS stores:
```bash
# This requires macOS admin/sudo password once:
mkcert -install
```
Verify the CA was installed and trusted:
```bash
security verify-cert -c "$(mkcert -CAROOT)/rootCA.pem"
```

### Step 8.2: Mint Local Multi-SAN Certificates
Mint or regenerate the unified certificate covering all platform endpoints:
```bash
if [ -x ~/.config/zsh/bin/nginx-regen-certs ]; then
  ~/.config/zsh/bin/nginx-regen-certs
else
  mkdir -p "$(brew --prefix)/etc/nginx/certs"
  mkcert -cert-file "$(brew --prefix)/etc/nginx/certs/zdots-local.pem" \
         -key-file "$(brew --prefix)/etc/nginx/certs/zdots-local-key.pem" \
         llama.localhost embed.localhost o2.localhost jaeger.localhost \
         zdots.localhost gemstash.localhost my.localhost localhost 127.0.0.1
fi
```

### Step 8.3: Validate & Start Nginx LaunchDaemon (Root Domain)
Nginx must bind privileged ports 80 and 443, so it runs as a root LaunchDaemon (`/Library/LaunchDaemons/homebrew.mxcl.nginx.plist`).

> [!CAUTION]
> **DO NOT USE `sudo brew services restart nginx`**
> Running `sudo brew services` executes Homebrew commands as root, corrupting ownership across `/opt/homebrew` and breaking subsequent `brew install` / `brew link`.
> ALWAYS use `nginx-ctl` or `sudo launchctl kickstart -k system/homebrew.mxcl.nginx`.

1. Validate nginx configuration syntax:
   ```bash
   nginx-ctl validate || $(brew --prefix)/opt/nginx/bin/nginx -t
   ```
2. Bootstrap and start the root daemon:
   ```bash
   sudo launchctl load /Library/LaunchDaemons/homebrew.mxcl.nginx.plist 2>/dev/null || sudo launchctl kickstart -k system/homebrew.mxcl.nginx
   ```
3. Verify nginx status:
   ```bash
   nginx-ctl status
   ```

### Step 8.4: Verify the 6 Foundational HTTPS Local Endpoints
The platform edge routes friendly HTTPS `.localhost` domains to their local runtime ports:

| Service | Friendly Local URL | Destination Port | Health Probe |
|---|---|---|---|
| **Local AI Inference** | `https://llama.localhost` | `127.0.0.1:11500` | `curl -sk https://llama.localhost/health` |
| **Local Embeddings** | `https://embed.localhost` | `127.0.0.1:11501` | `curl -sk https://embed.localhost/health` |
| **OpenObserve (Telemetry UI)** | `https://o2.localhost` | `127.0.0.1:5080` | `curl -sk https://o2.localhost/` |
| **Jaeger (Tracing UI)** | `https://jaeger.localhost` | `127.0.0.1:16686` | `curl -sk https://jaeger.localhost/` |
| **Status / Control Plane** | `https://zdots.localhost` | `127.0.0.1:11600` | `curl -sk https://zdots.localhost/healthz` |
| **Knowledge Layer Cockpit** | `https://my.localhost` | Socket/Port 5432 / app | `curl -sk https://my.localhost/` |

---

## Phase 9: Final Sanity Verification & Posture Matrix

Run the verification suite to prove full platform readiness and posture compliance:

```bash
# 1. Posture Variables Check
printenv ZDOTS_CONTEXT ZDOTS_AI_MODE ZDOTS_CAPTURE_ENABLED ZDOTS_HISTORY_REDACT ZDOTS_CMD_ANALYTICS

# Expected Output:
# ZDOTS_CONTEXT=work
# ZDOTS_AI_MODE=local (or none)
# ZDOTS_CAPTURE_ENABLED=0
# ZDOTS_HISTORY_REDACT=1
# ZDOTS_CMD_ANALYTICS=0

# 2. Platform Capability & Service Verification
capabilities --json
agent-guide --json
zdots-ctl check
adots-profile validate
adots-my doctor
colima-status --json
```

### Post-Migration Sign-Off Checklist
- [ ] No personal vault content or credentials cloned to the work machine.
- [ ] Pre-existing corporate `~/.ssh` and 1Password integration intact.
- [ ] `Brewfile.work` audited, adopted useful company defaults, zero `mas` references.
- [ ] `rtk` verified and operational for LLM command output compression.
- [ ] `mise` configuration preserved all work project language versions.
- [ ] Colima healthy with authoritative socket discovery and tuned M5 sizing.
- [ ] PostgreSQL 17 bound cleanly to native gems and `my` database migrated.
- [ ] Local TLS (`mkcert`) and root `nginx` active with 6 HTTPS `.localhost` endpoints verified.
- [ ] `adots-my doctor` reports 0 failures.

---

## Phase 10: Upstream Reconciliation & Delta Report Generation

The AI agent must synthesize all modifications and learnings into a structured, exportable report. This enables the operator to review the deltas, backport generic improvements, and keep the upstream repository aligned with real-world work environments.

### Step 10.1: Generate the Delta Report
Create the report file at:
```bash
REPORT_FILE="$HOME/.config/zsh/docs/reports/work-migration-delta-$(date +%Y%m%d).md"
mkdir -p "$(dirname "$REPORT_FILE")"
```

The agent writes the following markdown structure into `$REPORT_FILE`:

```markdown
# Work Machine Migration Delta Report: YYYY-MM-DD

## 1. Executive Summary
- **Execution Date:** YYYY-MM-DD
- **Target OS / Architecture:** macOS <version> (<arch>)
- **Migration Outcome:** [Success | Warnings | Blockers]
- **Key Services Active:** Postgres 17, Colima, local AI, nginx, context-engine

## 2. Package & Runtime Deltas (Brewfile.work & mise)
### Homebrew Adopted Packages (Company Defaults)
- List each formula/cask added to `Brewfile.work` and its justification.

### Homebrew Deferred / Excluded Packages
- List any packages from `Brewfile.common` or `Brewfile.work` that were omitted, skipped, or unavailable (e.g. App Store / `mas`).

### mise Toolchain Merges
- Table of runtimes discovered in work baseline vs. retained in `~/.config/mise/config.toml`:
  | Runtime | Company Baseline Version | Platform Version | Effective Setting |
  |---|---|---|---|

## 3. Configuration & Integration Seams
### SSH & 1Password
- Details of 1Password socket verification and Git SSH signing configuration.
- Any custom host configurations or bastions preserved.

### Database Wiring
- PostgreSQL 17 socket path, `pg_config` resolution path, and native gem build flags used.

### Container & Networking
- Colima VM configuration, DOCKER_HOST socket path, proxy/DNS settings applied.

### Local TLS & Edge Routing
- `mkcert` CA status and nginx HTTPS `.localhost` endpoint health.

## 4. Upstream Candidate Patches (Safe to Upstream)
*Extract clean, PHI-scrubbed diffs that should be merged back into upstream `zdots`, `adots`, or `Brewfile.work`.*

```diff
# Paste unified diff of generic changes (e.g. Brewfile.work updates, script robustness)
```

## 5. Local-Only Configurations (NEVER Upstream)
*List all settings that are strictly local to this employer/machine and must remain gitignored:*
- Tenant identities in `~/.config/zsh/.zdots.local`
- Private work extension scripts in `${ZDOTS_WORK_EXT:-~/.config/zdots-work}`
- Corporate internal hostnames, CIDRs, or proxy addresses
```

### Step 10.2: PHI and Secret Scan Verification
Before finalizing the report, the agent must run the zdots secret scanner to ensure no tenant secrets, tokens, or credentials were accidentally embedded in the report:

```bash
~/.config/zsh/bin/secret-scan "$REPORT_FILE" || gitleaks detect --no-git --source="$REPORT_FILE"
```

### Step 10.3: Operator Presentation
Present the summary of `$REPORT_FILE` directly in the session so the operator can inspect the deltas before signing off.
