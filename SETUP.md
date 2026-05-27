# SETUP.md — Clone-to-Running on a Fresh Machine

This is the authoritative guide for standing up zdots on a new macOS machine.
All steps are idempotent — safe to re-run.

## Prerequisites

1. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```

2. **Homebrew**
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

## Clone

```bash
git clone <your-remote> ~/.config/zsh
```

## Bootstrap (automated)

```bash
~/.config/zsh/bin/bootstrap
```

This single command:
- Creates XDG directory structure with correct permissions
- Links shell entry points (`~/.zshenv`, `~/.bashrc`, `~/.bash_profile`)
- Installs all Homebrew packages from `Brewfile`
- Registers llama.cpp launchd service and downloads the AI model (~4.7 GB)
- Installs Ruby dependencies via Bundler
- Creates `.zdots.local` from the example template (gitignored)
- Creates and migrates the `my` PostgreSQL database

## Machine identity (required after bootstrap)

Edit `.zdots.local` — this file is **gitignored** and never committed:

```bash
$EDITOR ~/.config/zsh/.zdots.local
```

At minimum, set your context:

```bash
ZDOTS_CONTEXT=home   # or: work
```

For a **work machine**, also add corporate identity and network config:

```bash
ZDOTS_CONTEXT=work
GIT_AUTHOR_EMAIL=firstname.lastname@company.com
GIT_COMMITTER_EMAIL=firstname.lastname@company.com
HTTP_PROXY=http://corporate-proxy:8080
HTTPS_PROXY=http://corporate-proxy:8080
NO_PROXY=localhost,127.0.0.1,.internal
```

See `.zdots.local.example` for the full reference.

## Database

The `bootstrap` script runs `zdots-ctx init-db` automatically. If it was
skipped (PostgreSQL wasn't running), run it manually after starting PostgreSQL:

```bash
brew services start postgresql@18
zdots-ctx init-db
```

`ZDOTS_MIGRATION_URL` defaults to `postgresql:///my`, which uses peer
authentication as the OS user. On macOS with Homebrew PostgreSQL, the
installing user is automatically a superuser — this works out of the box.

If your setup differs (different PostgreSQL port, username, or auth method),
override it in `.zdots.local`:

```bash
ZDOTS_MIGRATION_URL=postgresql://yourusername@localhost/my
```

## PHI safety — work machine checklist

If `ZDOTS_CONTEXT=work` or this machine will touch protected health information,
complete this checklist **before running any AI tooling**.

### How the PHI-safe mode works

Setting `ZDOTS_CONTEXT=work` in `.zdots.local` activates `.zdots.work`, which is
sourced **after** `.zdots.local` and hard-enforces the following regardless of any
other overrides:

| Variable | Enforced value | Effect |
|----------|---------------|--------|
| `ZDOTS_CAPTURE_ENABLED` | `0` | Session capture blocked (exit 2) |
| `ZDOTS_HISTORY_REDACT` | `1` | SSN/MRN/DOB/connection-string suppression in history |
| `ZDOTS_AI_MODE` | `local` (min) | Cloud mode reset to local if set in .zdots.local |
| `ZDOTS_CONTEXT` | `work` | Activates PHI assertions in `zdots-ctl check` |

These are enforced values, not defaults. `.zdots.local` cannot override them.

---

### Step 1 — Declare work context

Add one line to `.zdots.local`:

```bash
ZDOTS_CONTEXT=work
```

That is the only required change. All PHI-safe defaults activate automatically.

---

### Step 2 — Provision the database encryption key

The key must live in the macOS Keychain only — never in any file.

```bash
# Generate a fresh key (skip if migrating an existing key)
openssl rand -hex 32

# Store in Keychain
zdots-keychain add ZDOTS_DB_ENCRYPTION_KEY <value>

# Verify the key is reachable
zdots-keychain verify
```

Then run the DB migration so encrypted columns are created:

```bash
zdots-ctx migrate
```

`zdots-ctx migrate` hard-fails if `ZDOTS_DB_ENCRYPTION_KEY` is unset. After it
runs, `lessons.content`, `methodologies.content`, and
`session_residue.{summary,intent,result}` are encrypted at rest with pgcrypto.
`zdots_ro` sees ciphertext only.

**Agent sessions:** if another AI agent reports the key is missing:
```bash
export ZDOTS_DB_ENCRYPTION_KEY=$(zdots-keychain get ZDOTS_DB_ENCRYPTION_KEY)
```

---

### Step 3 — Migrate secrets from file to Keychain (upgrade path)

Skip this step on a fresh machine with no `.zdots.secrets`.

If `.zdots.secrets` exists with literal values:

```bash
# Import all literal export VAR=value lines into Keychain
zdots-keychain migrate

# Confirm all critical secrets resolve
zdots-keychain verify

# Delete the file — Keychain is now the only source
rm ~/.config/zsh/.zdots.secrets
```

After deletion, `env.sh` loads all secrets directly via `zdots-keychain_load`.
`zdots-ctl check` will PASS the "Secrets file absent" assertion.

---

### Step 4 — Verify security posture

```bash
zdots-ctl check
```

On a work machine this runs a full PHI posture check in addition to service
health. All of the following must pass before the machine is safe for PHI work:

| Check | Passes when |
|-------|-------------|
| FileVault | `fdesetup status` returns "FileVault is On" |
| SIP | `csrutil status` returns "enabled" |
| Application Firewall | enabled (WARN, not FAIL, if off) |
| AI mode | `local` or `none` |
| Capture | `ZDOTS_CAPTURE_ENABLED=0` |
| History redaction | `ZDOTS_HISTORY_REDACT=1` |
| Secrets file | `.zdots.secrets` absent |
| DB encryption key | `ZDOTS_DB_ENCRYPTION_KEY` non-empty |

`zdots-ctl check` **hard-fails** (exit 1) if FileVault or SIP is disabled, or if
the DB encryption key is missing. Fix before proceeding.

---

### Step 5 — Zero-AI mode for unknown network environments

If the corporate proxy situation is unresolved or llama.cpp is not yet running,
disable AI entirely. The system runs fully without it:

```bash
# .zdots.local
ZDOTS_AI_MODE=none
```

All AI commands (`ai-query`, `zaider`, `zdots-ctx capture`) exit cleanly with a
human-readable message and exit code 2. No hangs, no timeouts, no curl errors.
This is the safe baseline — not a degraded state.

Once the proxy situation is resolved and the local model is running:

```bash
zdots-ctl up              # start llama.cpp and supporting services
ZDOTS_AI_MODE=local       # back in .zdots.local
ai-query "hello"          # smoke test
```

---

### Step 6 — Understand what the PHI scrubber covers

**History hook** (`conf.d/55-phi-history.zsh`) runs before every command is
written to `~/.local/state/zsh/history`. Commands matching these patterns are
suppressed entirely (not redacted — the line is not written):

| Pattern | Action |
|---------|--------|
| DB connection strings with credentials | Suppress |
| SSN `NNN-NN-NNNN` | Redact in-place → `[REDACTED-SSN]` |
| `MRN: <digits>` | Redact in-place → `[REDACTED-MRN]` |
| `DOB: <date>` | Redact in-place → `[REDACTED-DOB]` |

Every suppression emits a `history_redacted` entry to macOS Unified Logging.
Stream live: `log stream --predicate 'subsystem == "com.zdots"'`

**AI call scrubber** (`lib/phi_scrubber.bash`) applies the same patterns to all
content before it is sent to the inference endpoint or stored in the DB.

Site-specific patterns (patient account numbers, employee IDs) belong in
`etc/phi-patterns.yaml` — the **PHI Pattern Registry** and sole source of truth
for all patterns. Add a YAML entry:

```yaml
- name: patient_account
  regex: 'ACC[0-9]{8}'
  replace: '[REDACTED-ACC]'
  weight: 85
```

The registry is committed to git (it is configuration, not a secret). Patterns
compile at shell startup and apply to all layers (history hook, analytics
capture, AI pipeline) automatically — no per-layer wiring required.

The scrubber is the **first** layer, not the last. Do not send raw patient record
excerpts to AI — patterns are not exhaustive.

Full policy: `backlog/docs/doc-002 - PHI-Safety-Policy.md`

---

## AI security boundary

**On a fresh clone, all AI is local. This is non-negotiable until security is complete.**

`ZDOTS_AI_MODE=local` is the default set in `.zdots.env`. It means:

- `ai-query`, `zaider` (Aider), and `zdots-ctx` all send inference to `ZDOTS_AI_ENDPOINT` only
- No `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or `GEMINI_API_KEY` are set
- No data leaves the machine (or your LAN) to reach a cloud provider

### Local stack for analysis and automation

```
ai-query "analyze this"              # one-shot inference via llama.cpp
zaider                               # Aider wired to local model
zdots-ctx query <term>               # search local knowledge base
zdots-ctx hydrate [tag]              # context blob for AI tasks
zdots-brain                          # background job worker (embed, distill)
```

### Pi coding agent

`bootstrap` creates `~/.pi/agent/settings.json` and `~/.pi/agent/models.json` automatically.
These wire Pi to the local llamacpp endpoint. No further config is needed.

To verify Pi is working after bootstrap:

```bash
PI_TELEMETRY=0 pi -p --no-session "hello"   # should return a response
zpi "what services are running?"             # interactive sanity check
```

Project-level skills (`.pi/skills/`) travel with the repo via git clone.
Global skills (`~/.pi/agent/skills/`) are machine-local — only the 14 project skills
are available on a fresh machine. That is expected and sufficient for zdots work.

### Using a more powerful machine on your LAN

If you have a workstation running llama.cpp, point everything at it in `.zdots.local`:

```bash
ZDOTS_AI_ENDPOINT=http://powerstation.local:8080
```

`ai-query`, `zaider`, and `zdots-ctx` all read this single variable — no other config needed.

### Enabling cloud AI (after security setup)

1. Store API keys in macOS Keychain:
   ```bash
   zdots-keychain add OPENAI_API_KEY sk-...
   zdots-keychain add ANTHROPIC_API_KEY sk-ant-...
   ```
2. Set `ZDOTS_AI_MODE=cloud` in `.zdots.local`
3. Restart your shell

Cloud keys live in the Keychain only — never in `.zdots.secrets`, `.zdots.local`, `.zdots.env`, or any tracked file. `env.sh` loads them automatically via `zdots_keychain_load` on every shell start.

## Verify

```bash
exec zsh                    # reload the shell
zdots-ctl check             # deep platform diagnostic (includes AI router structural check)
zdots-ctx status            # database + job queue health
agent-guide                 # live service status
zdots-quiz --quick          # probe local model on 3 canonical zdots tasks (~20s)
zdots-quiz                  # full 14-case capability baseline (optional, ~5 min)
```

`zdots-quiz --quick` runs TC-03 (PHI-safe AI call), TC-07 (transparent encryption accessor), and TC-09 (posture verification) — the three highest-value patterns. All must pass before trusting `zdots-ask` with real work.

If any quiz case fails, run `zdots-quiz --verbose` to inspect the model's response and tune `etc/prompts/` accordingly.

## The firewall: what stays private

| File | Tracked | Contains |
|------|---------|----------|
| `.zdots.env` | yes | profiles, service config, defaults |
| `.zdots.work` | yes | PHI-safe enforced values (no secrets) |
| `.zdots.secrets` | **no** | API keys, tokens — **deprecated**: use Keychain instead |
| `.zdots.local` | **no** | machine identity, context, overrides |
| `.env` / `.env.*` | **no** | any other local env vars |

**Never commit** credentials, hostnames, email addresses, or proxy settings.
Machine-specific config belongs in `.zdots.local`. Secrets belong in macOS Keychain (`zdots-keychain add`).

## Keeping home and work in sync

Both machines clone the same repo. The shared code is context-free.
Machine-specific config lives only in `.zdots.local` (gitignored).

```
home machine:  .zdots.local  →  ZDOTS_CONTEXT=home
work machine:  .zdots.local  →  ZDOTS_CONTEXT=work, corporate proxy, work email
```

Push and pull freely — no context or identity leaks between machines.
