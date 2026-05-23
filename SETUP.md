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

### 1 — Set machine context

```bash
# .zdots.local
ZDOTS_CONTEXT=work
ZDOTS_AI_MODE=local     # lock to local; change only after security review
ZDOTS_CAPTURE_ENABLED=0 # capture is opt-in; do NOT enable until DB encryption is in place
ZDOTS_HISTORY_REDACT=1  # already the default; confirm it is set
```

### 2 — Provision the database encryption key

```bash
# Generate
openssl rand -hex 32

# Store in Keychain
zdots-keychain add ZDOTS_DB_ENCRYPTION_KEY <value>

# Wire into .zdots.secrets (add this line)
export ZDOTS_DB_ENCRYPTION_KEY="$(_zdots_kc ZDOTS_DB_ENCRYPTION_KEY)"

# Run the encryption migration
zdots-ctx migrate
```

`zdots-ctx migrate` will hard-fail if `ZDOTS_DB_ENCRYPTION_KEY` is unset. After it runs,
`lessons.content`, `methodologies.content`, and `session_residue.{summary,intent,result}`
are encrypted at rest with pgcrypto. `zdots_ro` sees ciphertext only.

**Agent sessions:** If another AI agent reports the key is missing, tell it:
```bash
export ZDOTS_DB_ENCRYPTION_KEY=$(zdots-keychain get ZDOTS_DB_ENCRYPTION_KEY)
```

### 3 — Verify security posture

```bash
zdots-ctl check   # verifies FileVault, SIP, Firewall, llama-server loopback, model provenance
```

`zdots-ctl check` will **hard-fail** if FileVault or SIP is disabled on a work machine.
Fix before proceeding.

### 4 — Zero-AI mode for unknown network environments

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

### 5 — Understand what the PHI scrubber covers

Every AI call pipes content through `lib/phi_scrubber.bash` before sending or
storing. Patterns scrubbed automatically:

| Pattern | Replacement |
|---------|-------------|
| SSN `NNN-NN-NNNN` | `[REDACTED-SSN]` |
| MRN labels | `[REDACTED-MRN]` |
| DOB labels | `[REDACTED-DOB]` |
| DB connection strings | `[REDACTED-CONN]` |

Site-specific patterns (patient account numbers, employee IDs) go in `.zdots.local`:

```bash
ZDOTS_HISTORY_REDACT_PATTERNS=(
  'ACC[0-9]{8}'
  'EMP-[A-Z]{2}[0-9]{5}'
)
```

The scrubber is the **first** layer, not the last. Do not send raw patient record
excerpts to AI — scrubbing patterns are not exhaustive.

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

### Using a more powerful machine on your LAN

If you have a workstation running llama.cpp, point everything at it in `.zdots.local`:

```bash
ZDOTS_AI_ENDPOINT=http://powerstation.local:8080
```

`ai-query`, `zaider`, and `zdots-ctx` all read this single variable — no other config needed.

### Enabling cloud AI (after security setup)

1. Add API keys to `.zdots.secrets` (gitignored):
   ```bash
   export OPENAI_API_KEY=sk-...
   export ANTHROPIC_API_KEY=sk-ant-...
   ```
2. Set `ZDOTS_AI_MODE=cloud` in `.zdots.local`
3. Restart your shell

Cloud keys never go in `.zdots.env`, `.zdots.local`, or anywhere tracked by git.

## Verify

```bash
exec zsh                    # reload the shell
zdots-ctl check             # deep platform diagnostic
zdots-ctx status            # database + job queue health
agent-guide                 # live service status
```

## The firewall: what stays private

| File | Tracked | Contains |
|------|---------|----------|
| `.zdots.env` | yes | profiles, service config, defaults |
| `.zdots.secrets` | **no** | API keys, tokens |
| `.zdots.local` | **no** | machine identity, context, overrides |
| `.env` / `.env.*` | **no** | any other local env vars |

**Never commit** credentials, hostnames, email addresses, or proxy settings.
They belong in `.zdots.local` or `.zdots.secrets`.

## Keeping home and work in sync

Both machines clone the same repo. The shared code is context-free.
Machine-specific config lives only in `.zdots.local` (gitignored).

```
home machine:  .zdots.local  →  ZDOTS_CONTEXT=home
work machine:  .zdots.local  →  ZDOTS_CONTEXT=work, corporate proxy, work email
```

Push and pull freely — no context or identity leaks between machines.
