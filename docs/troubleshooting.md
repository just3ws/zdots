# Troubleshooting Guide

First rule: identify the failing layer before changing anything. Zdots is shell
config, service control, local AI, telemetry, databases, and PHI safety in one
repo; guessing creates wider failures.

## 1. Quick Triage

Run the smallest checks first:

```sh
capabilities --json
agent-guide
git status --short
```

Use these when the shell itself is suspect:

```sh
ZDOTS_SAFE_MODE=1 zsh -i
make check-fast
make bench
```

Use these when services are suspect:

```sh
llama-ctl status
llama-ctl status-embed
otel-collector status
local-ci status
zdots-ctx status
```

`zdots-ctl check` is the intended deep audit, but if `zdots-ctl` itself errors,
file an issue with `zdots-issue` and do not fix infrastructure as part of an
unrelated task.

## 2. Shell Startup

### Shell takes too long to load

Check:

```sh
make bench
ZDOTS_SAFE_MODE=1 zsh -i
```

Common causes:
- `atuin`, `direnv`, `mise`, `fzf`, or prompt plugins are slow.
- A provider command is hanging before `zdots_cmd_timeout` can protect it.
- External services are down and startup code waits on them.

Next actions:
- Compare normal startup against `ZDOTS_SAFE_MODE=1`.
- Inspect recently changed files under `conf.d/` and `providers/`.
- Run `make check-fast` before changing startup code.

### Powerlevel10k does not load; fallback prompt appears

`conf.d/20-prompt.zsh` loads Powerlevel10k only when the shell is interactive,
has no `ZSH_EXECUTION_STRING`, stdout is a real TTY, and a theme candidate is
readable. If any check fails, zdots installs the fallback prompt:

```zsh
%F{33}%n@%m%f %1~ %#
```

Run this in the bad shell:

```zsh
print -r -- "tty=$([[ -t 1 ]] && echo yes || echo no) exec=${ZSH_EXECUTION_STRING:-none} p10k=${+functions[p10k]} hp=${HOMEBREW_PREFIX:-unset}"
```

Interpretation:
- `tty=no`: interactive shell without a real terminal. Expected for `zsh -i -c ...`, CI, agent sessions, and some command runners.
- `exec` is not `none`: shell was started with `zsh -c`; p10k is skipped by design.
- `p10k=0` with `tty=yes` and `exec=none`: p10k did not load in a real terminal.

Check theme availability:

```sh
ls -l /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
```

If the theme exists, inspect startup errors:

```sh
zsh -i -c exit
```

Look for `zdots: warning: failed to source ...`, `p10k`, `gitstatus`, or
permission errors. If the failure is intermittent and the probe shows
`tty=yes exec=none p10k=0`, add temporary instrumentation around
`conf.d/20-prompt.zsh` before changing prompt logic.

### Non-TTY plugin warnings

Symptoms:

```text
(anon):setopt:7: can't change option: monitor
(eval):1: can't change option: zle
```

This happens when zsh is interactive but has no real line editor, commonly in
`zsh -i -c ...` or automated checks. Use:

```sh
ZDOTS_SAFE_MODE=1 zsh -i -c exit
```

For scripts, avoid interactive shell startup unless the script needs aliases,
widgets, or prompt state.

### Keybindings or ZLE widgets do not work

Check:

```zsh
print -r -- "interactive=$options[interactive] zle=$options[zle]"
bindkey | rg 'fzf|zdash|history|\\ee|\\ef|\\ez'
zle -l | rg 'zdots|fzf'
```

Expected:
- `interactive=on`
- `zle=on`
- `Alt-e`, `Alt-f`, and `Alt-z` widgets present in normal terminals

If `zle=off`, the shell context cannot support widgets. If `zle=on` but widgets
are missing, inspect `conf.d/60-bindings.zsh`, `conf.d/70-integrations.zsh`, and
`conf.d/97-zle-ai.zsh`.

## 3. Path, Homebrew, and Runtime Managers

### Homebrew tools are missing

Check:

```sh
printenv HOMEBREW_PREFIX
command -v brew
brew --version
```

Expected on Apple Silicon:

```text
HOMEBREW_PREFIX=/opt/homebrew
```

If `brew` exists but tools are missing, run:

```sh
brew bundle --file "$ZDOTDIR/Brewfile"
```

### mise or Ruby commands fail

Use `zdots-ruby` for repo Ruby commands:

```sh
zdots-ruby -v
zdots-ruby -S rspec
```

If Ruby is missing:

```sh
mise trust "$ZDOTDIR/mise.toml"
mise install --cd "$ZDOTDIR"
```

Avoid relying on ambient `ruby`; this repo pins its Ruby through `mise.toml` and
`etc/ruby-version`.

## 4. Local AI and llama.cpp

### AI server unreachable on port 11500

Check:

```sh
llama-ctl status
llama-ctl config --json
curl -sf http://127.0.0.1:11500/health
```

Common fixes:

```sh
llama-ctl install
llama-ctl model-download
llama-ctl restart
```

If port state is confusing:

```sh
lsof -nP -iTCP:11500 -sTCP:LISTEN
plutil -p "$HOME/Library/LaunchAgents/com.zdots.llama-server.plist" | rg -- '--port|11500|8080'
```

The plist must show `--port 11500`. If it shows `8080`, pull latest and run:

```sh
bin/llama-ctl install
```

### Embedding server unreachable on port 11501

Check:

```sh
llama-ctl status-embed
curl -sf http://127.0.0.1:11501/health
plutil -p "$HOME/Library/LaunchAgents/com.zdots.llama-embed.plist" | rg -- '--port|11501|8090'
```

Fix:

```sh
bin/llama-ctl install-embed
```

The embed plist must show `--port 11501`. If it shows `8090`, regenerate it.

### Model download writes an invalid GGUF

Symptom in logs:

```text
Invalid magic characters: 'Inva'
```

The `.gguf` file is probably an HTML or text error response from HuggingFace.
Check:

```sh
file "$ZDOTS_AI_MODELS_DIR"/*.gguf
llama-ctl logs
zdots-keychain get HUGGINGFACE_TOKEN >/dev/null
```

Fix the token, then redownload only the affected model. Do not delete all models
unless disk pressure or corruption requires it.

### llama-server crash loop or OOM

Check:

```sh
llama-ctl logs
llama-ctl config --json | jq '{profile, ctx_size, parallel, batch_size, ubatch_size}'
```

Actions:
- Switch to `constrained` if memory is tight.
- Keep `parallel` low for 16GB machines.
- Regenerate the plist after YAML changes: `llama-ctl install`.

### AI calls are blocked by the boundary

Check:

```sh
printenv ZDOTS_AI_MODE ZDOTS_AI_ENDPOINT ZDOTS_AI_EMBED_ENDPOINT
```

Expected local defaults:

```text
ZDOTS_AI_MODE=local
ZDOTS_AI_ENDPOINT=http://127.0.0.1:11500
ZDOTS_AI_EMBED_ENDPOINT=http://127.0.0.1:11501
```

In `local` mode, endpoints must be loopback or RFC-1918. Do not switch to
`cloud` on work machines without explicit security review.

## 5. launchd Services

### `Bootstrap failed: 5: Input/output error`

This often means launchd has stale state, the service is already loaded, or the
plist was rewritten while launchd still has the old job.

Check:

```sh
launchctl print "gui/$(id -u)/com.zdots.llama-server"
launchctl print "gui/$(id -u)/com.zdots.llama-embed"
```

Regenerate and load through the wrapper:

```sh
llama-ctl install
llama-ctl install-embed
```

If the wrapper writes the plist but launchd fails, verify the file:

```sh
plutil -p "$HOME/Library/LaunchAgents/com.zdots.llama-server.plist"
plutil -p "$HOME/Library/LaunchAgents/com.zdots.llama-embed.plist"
```

Then try a direct bootstrap only when you are intentionally operating on that
service:

```sh
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.zdots.llama-server.plist"
```

### Service appears loaded but health is down

Check both launchd and HTTP:

```sh
llama-ctl status --json
curl -v http://127.0.0.1:11500/health
```

If launchd says running but health fails, the model may still be loading. Wait a
few seconds, then check logs.

## 6. Observability and LGTM

### No traces in Grafana

Check the host collector first:

```sh
otel-collector status
otel-collector health
otel-collector logs
```

Check the container stack:

```sh
local-ci status
docker compose -f "$ZDOTDIR/etc/docker-compose.lgtm.yaml" ps
```

Use `127.0.0.1`, not `localhost`, for OTLP clients:

```sh
export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

### Collector config invalid

Validate before restart:

```sh
otel-collector validate
```

If validation fails, fix `etc/otel-collector.yaml`. Do not restart into a known
bad config.

### Colima or Docker fails

Check:

```sh
colima status
docker context ls
local-ci status
```

Reclaim disk before rebuilding:

```sh
docker-df
docker-reclaim
```

Use destructive cleanup only after reading the dry run.

## 7. Database and Knowledge Layer

### `zdots-ctx` cannot connect

Check:

```sh
zdots-ctx status
psql -U zdots_ro my -c 'select 1'
printenv ZDOTS_DATABASE_URL ZDOTS_MIGRATION_URL
```

Expected:
- database name: `my`
- app URL: `ZDOTS_DATABASE_URL=postgresql://zdots_rw@/my`
- migration URL: `ZDOTS_MIGRATION_URL=postgresql:///my`

Do not set generic `DATABASE_URL`; it is intentionally not used by this stack.

### Migrations fail

Run:

```sh
zdots-ctx migrate
zdots-ctx status
```

If schema and docs disagree, file an issue with `zdots-issue`; do not patch
database infrastructure to unblock an unrelated task.

### Knowledge query or hydrate returns old errors

Check:

```sh
zdots-ctx query "test"
zdots-ctx hydrate shell
```

If it references renamed columns or missing methods, file a zdots issue. The
knowledge layer has multiple callers and should be coordinated.

## 8. Secrets, PHI, and Work Mode

### Keychain secret missing

Check:

```sh
zdots-keychain list
zdots-keychain get ZDOTS_DB_ENCRYPTION_KEY >/dev/null
```

Add or update:

```sh
zdots-keychain add ZDOTS_DB_ENCRYPTION_KEY "$(openssl rand -hex 32)"
```

Agent sessions may not inherit login-shell state. Export only for the current
session when needed:

```sh
export ZDOTS_DB_ENCRYPTION_KEY="$(zdots-keychain get ZDOTS_DB_ENCRYPTION_KEY)"
```

### PHI posture is wrong

Check:

```sh
printenv ZDOTS_CONTEXT ZDOTS_AI_MODE ZDOTS_CAPTURE_ENABLED ZDOTS_HISTORY_REDACT ZDOTS_CMD_ANALYTICS
```

Work machines should have:
- `ZDOTS_CONTEXT=work`
- `ZDOTS_AI_MODE=local`
- `ZDOTS_CAPTURE_ENABLED=0`
- `ZDOTS_HISTORY_REDACT=1`
- `ZDOTS_CMD_ANALYTICS=0`

Never enable cloud AI or command analytics on a work machine without operator
review.

### PHI or credential patterns are missing

Patterns belong in one place:

```text
etc/phi-patterns.yaml
```

Validate after edits:

```sh
yamllint etc/phi-patterns.yaml
bats tests/phi_boundary.bats
```

Do not define PHI patterns in scripts, hooks, or app-specific code.

## 9. History and Command Analytics

### History write warnings or lock failures

Check:

```sh
ls -ld "$XDG_STATE_HOME/zsh"
ls -l "$XDG_STATE_HOME/zsh/history"
printenv HISTFILE
```

The state directory should be owned by the user and writable. In sandboxed agent
sessions, history writes may fail because the sandbox cannot write under
`~/.local/state`; that is not a normal terminal failure.

### Command analytics missing

Check:

```sh
printenv ZDOTS_CMD_ANALYTICS ZDOTS_CONTEXT
ls -l "$XDG_STATE_HOME/zdots/history.sqlite3"
```

On work machines, analytics should be off. On home machines, if enabled, inspect
the SQLite fallback:

```sh
sqlite-utils query "$XDG_STATE_HOME/zdots/history.sqlite3" \
  "select cmd, count(*) n from command_runs group by cmd order by n desc limit 10"
```

## 10. Backlog, Git, and Updates

### Pull conflicts on `bin/llama-ctl`

This means the machine has local edits to the control script. Inspect before
pulling:

```sh
git status --short
git diff -- bin/llama-ctl
```

After resolving and pulling latest, regenerate local service state:

```sh
bin/llama-ctl install
bin/llama-ctl install-embed
```

Do not run full bootstrap just to update `llama-ctl`; bootstrap performs broad
machine setup.

### Backlog command has git errors

If `zdots-issue` creates the task file but reports git failures, keep the task
file and commit it separately. The important outcome is a tracked issue with a
trace ID.

Do not edit backlog task metadata directly unless the CLI is broken and the
change is only recording an agent-reported infrastructure issue.

### Git hooks or checks fail

Run the narrow check first:

```sh
make check-fast
```

Then targeted tests:

```sh
bats tests/metadata.bats
zdots-ruby -S rspec
```

Only run full `make check` after shell syntax and service blockers are clear.

## 11. Bootstrap and Machine Setup

### Is bootstrap idempotent?

Mostly, but it is not a narrow updater. It may:
- restore adots files into `$HOME`
- run `brew bundle`
- run `mise install`
- download models
- rewrite launchd plists
- modify nginx config
- install mkcert certificates

Use it for first-time setup or deliberate machine reconciliation, not for a
small repo update.

For normal update:

```sh
cd "$ZDOTDIR"
git pull --rebase
make update-local
```

Preview without changing local state:

```sh
bin/zdots-update-local --dry-run
```

### Setup changed files in `$HOME`

Bootstrap manages shell entry points and may restore adots. Before running it on
a work machine, inspect:

```sh
ls -la ~/.zshenv ~/.zshrc ~/.zprofile ~/.gitconfig
```

Back up employer-managed files before allowing bootstrap to touch them.

## 12. Disk Pressure

Check:

```sh
df -h /
docker-df
llama-ctl model-df
```

Safe first steps:

```sh
docker-reclaim
llama-ctl model-list
```

Destructive steps require intent:

```sh
docker-reclaim -f
llama-ctl model-prune
```

If primary disk remains low, move models:

```sh
export ZDOTS_AI_MODELS_DIR=/Volumes/External/llama-models
llama-ctl model-download
llama-ctl install
```

## 13. Validation Matrix

Use the narrowest validation that covers the change:

| Area | Validation |
|---|---|
| Shell startup | `make check-fast`, `make bench` |
| Prompt/theme | start a real terminal; run the p10k probe above |
| Metadata/YAML | `bats tests/metadata.bats`, `yq '.' etc/ai-models.yaml` |
| llama chat | `llama-ctl status --json`, `curl -sf http://127.0.0.1:11500/health` |
| llama embed | `llama-ctl status-embed --json`, `curl -sf http://127.0.0.1:11501/health` |
| AI API | `zdots-ruby tests/llama_integration.rb --quick` |
| Ruby code | `zdots-ruby -S rspec` |
| PHI boundary | `bats tests/phi_boundary.bats` |
| OTel | `otel-collector validate`, `otel-collector health` |
| Database | `zdots-ctx status`, `psql -U zdots_ro my -c 'select 1'` |
| Docs only | `git diff --check` |

If validation fails because a zdots infrastructure script is broken, file a
`zdots-issue` and stop changing that subsystem unless the task is explicitly to
repair it.
