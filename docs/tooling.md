---
id: tooling
title: "Key Tools Reference"
purpose: Authoritative map of Brewfile tools to workflows. What to reach for and why.
---

# Key Tools Reference

All tools listed are installed via the Brewfile unless noted (`bin/` prefix = zdots-native, not Homebrew).
Organized by workflow, not alphabetically. For service lifecycle, see [architecture.md](architecture.md).

---

## Shell Intelligence & Knowledge Layer

The zdots-specific stack. Every agent session should orient here first.

| Tool | Command | Purpose |
|------|---------|---------|
| Platform orchestrator | `zdots-ctl up/down/check/status` | Start, stop, health-check all services |
| Knowledge layer CLI | `zdots-ctx query/capture/hydrate/sync-history` | Shell→PostgreSQL brain interface |
| Task orchestrator | `ztask start/done/stop/status <id>` | Hydrate shell env to a specific task; links trace to work |
| Service guide | `agent-guide` | Live status + endpoint map for agents |
| Environment contract | `capabilities --json` | Machine capability report |
| Local state updater | `zdots-update-local` | Post-pull reconciliation without full bootstrap |
| Status TUI | `zdots-status` | Self-refreshing service + env + storage panel |
| Issue filing | `zdots-issue "description"` | File a backlog task with trace ID attached |
| AI router | `zdots-ask "prompt"` | Domain-aware prompt routing (shell/ruby/phi/default) |
| AI smoke test | `zdots-quiz --quick` | 3-case probe of the local model |
| Startup benchmark | `bench` | Measure cold/warm shell startup latency; guards 80ms budget |
| Morning ritual | `zmorning` | Daily context brief + optional Pi orientation session |
| Task picker | `zdash` | fzf task picker wired to Pi↔Aider↔ztask cycle |
| Secrets | `zdots-keychain add/get/list` | Store and load secrets from macOS Keychain |

---

## AI & Inference

| Tool | Command | Purpose |
|------|---------|---------|
| llama.cpp | `llama-ctl status/start/stop` | Manage local chat server (Qwen3-8B, port 11500) |
| Embedding server | `ZDOTS_AI_PROFILE=embed llama-ctl start` | Nomic embed-v2, port 11501 |
| One-shot inference | `ai-query "prompt"` | Guarded LLM call with PHI scrubbing |
| Capability doc | `llama-caps` | Full endpoint/capability/constraint doc for local stack |
| llama MCP server | `llama-mcp` | MCP stdio server: health, config, test, snippet tools for Claude/Cursor |
| Context MCP server | `ctx-mcp` | MCP stdio server: query/capture knowledge base from AI agents |
| Aider (local) | `zaider` | Aider wired to local llama.cpp — file editing + git |
| Pi coding agent | `zpi "prompt"` | Interactive session agent (earendil pi) |
| Gemini CLI | `gemini` | Google Gemini from the shell |
| Kimi CLI | `kimi` | MoonshotAI from the shell |
| Fabric | `fabric-ai` | Expert prompt pipelines (local or cloud) |
| AI pattern browser | `zdots-pattern` | Interactive `fzf` browser for 250+ Fabric patterns |
| Whisper transcription | `whisper-ctl` | Local audio-to-text (whisper.cpp) |

**Security boundary:** `ai-query` and `zdots-ask` enforce `ZDOTS_AI_MODE` and route through
`lib/ai_boundary.bash`. Use them in preference to calling `llama-server` or cloud CLIs directly
from scripts — they apply the PHI scrubber and locality check automatically. `zdots-ask` now supports
Expert Patterns via `--pattern <name>`.

---

## History & Analytics (write side)

Tools that feed data into the Knowledge Layer.

| Tool | Command | Purpose |
|------|---------|---------|
| History import | `history-import` | Bulk-import zsh/bash/atuin/fish history into SQLite |
| History analysis | `history-analyze` | Pattern analysis: inefficiencies, alias candidates, failure rates |
| Docker reclaim | `docker-reclaim` | `docker system prune` + `fstrim` to shrink Colima disk image |
| OTel verifier | `trace-verify` | Contract test shell control plane via OTel JSONL trace stream |

---

## Data Exploration (analytics read side)

The command analytics pipeline writes to Redis → SQLite → PostgreSQL. Shell
hook metrics write directly to the same SQLite buffer and sync through the same
PostgreSQL path. These tools are the read side.

| Tool | Command | Purpose |
|------|---------|---------|
| `visidata` | `vd ~/.local/state/zdots/history.sqlite3` | TUI spreadsheet — pivot command_runs or shell_hook_metrics by cmd, exit code, duration, hook |
| `pgcli` | `pgcli -U zdots_ro my` | PostgreSQL REPL with autocomplete; replaces raw `psql` for exploration |
| `litecli` | `litecli ~/.local/state/zdots/history.sqlite3` | SQLite REPL with autocomplete; explore analytics fallback DB |
| `sqlite-utils` | `sqlite-utils query <db> "SELECT ..."` | CLI analytics — query, export JSON/CSV, script transforms |
| `redis-cli` | `redis-cli KEYS 'zdots:cmds:*'` | Inspect the live analytics write buffer |
| `jless` | `zdots-ctx query term \| jless` | Interactive JSON navigator |

**Quick workflow — find your worst commands this week:**
```bash
sqlite-utils query ~/.local/state/zdots/history.sqlite3 \
  "SELECT cmd, count(*) n, round(avg(duration_ms)) avg_ms
   FROM command_runs WHERE exit_code != 0
   GROUP BY cmd ORDER BY n DESC LIMIT 20"
```

**Quick workflow — open command_runs as a spreadsheet:**
```bash
vd ~/.local/state/zdots/history.sqlite3
# press Enter on command_runs → g/ to filter → F to frequency-table any column
```

**Quick workflow — inspect slow shell hooks:**
```bash
sqlite-utils query ~/.local/state/zdots/history.sqlite3 \
  "SELECT hook, status, elapsed_ms, threshold_ms, session_id
   FROM shell_hook_metrics
   ORDER BY elapsed_ms DESC
   LIMIT 20"
```

---

## Context & Token Efficiency

| Tool | Command | Purpose |
|------|---------|---------|
| `repomix` | `repomix --output context.xml` | Dense codebase snapshot for AI context |
| `rtk` | `rtk git diff`, `rtk tokei` | Proxy high-output commands; clips noise for AI |
| `tokei` | `tokei` | Code line counts by language — fast codebase overview |
| `universal-ctags` | `ctags -R .` | Symbol index for navigation and AI context |
| `ripgrep` | `rg "pattern"` | Fast codebase search; feeds context-reduction workflows |

**RTK rule (from AGENTS.md):** Always proxy high-output commands through `rtk` in agent sessions:
`rtk git status`, `rtk git diff`, `rtk tokei`, `rtk docker logs`.

---

## Testing & Code Quality

| Tool | Command | Purpose |
|------|---------|---------|
| `bats-core` | `bats tests/` | Shell test runner (TAP output) |
| `watchexec` | `watchexec -e zsh,bash,bats -- bats tests/` | Re-run tests on file save |
| `entr` | `ls tests/*.bats \| entr bats tests/` | Alternative file-watch test runner |
| `shellcheck` | `shellcheck bin/*` | Static analysis for shell scripts |
| `shfmt` | `shfmt -d bin/zdots-ctl` | Shell script formatter |
| `actionlint` | `actionlint` | GitHub Actions workflow linter |
| `hadolint` | `hadolint Dockerfile` | Dockerfile linter |
| `pre-commit` | `pre-commit run --all-files` | Run all configured pre-commit hooks |
| `yamllint` | `yamllint etc/phi-patterns.yaml` | YAML syntax validation |
| `hyperfine` | `hyperfine 'exec zsh -c exit'` | Shell startup benchmarking |

---

## Security & PHI

| Tool | Command | Purpose |
|------|---------|---------|
| `bandwhich` | `sudo bandwhich` | Per-process network monitor — verify AI stays on loopback |
| `secret-scan` | `bin/secret-scan` | High-confidence credential leak detection (AWS, GitHub, SSH) |
| `gitleaks` | `gitleaks detect` | Git history secret scan |
| `trufflehog` | `trufflehog git file://.` | Deep entropy-based secret scan |
| `syft` | `syft .` | SBOM generation for supply chain auditing |
| `trivy` | `trivy fs .` | Vulnerability scan (filesystem, Docker images) |

**PHI posture check:** `zdots-ctl check` — run this before any session that may touch patient data.
Hard-fails on FileVault/SIP disabled or missing `ZDOTS_DB_ENCRYPTION_KEY`.

---

## Git & Code Navigation

| Tool | Command | Purpose |
|------|---------|---------|
| `lazygit` | `lg` | TUI git — stage hunks, rebase, stash, all interactively |
| `git-delta` | (configured in gitconfig) | Side-by-side diff with syntax highlighting |
| `git-cliff` | `git cliff --latest` | CHANGELOG from conventional commits |
| `git-absorb` | `git absorb` | Auto-fixup: squash staged changes into the right commit |
| `gh` | `gh pr create`, `gh dash` | GitHub CLI + gh-dash TUI for PR review |
| `diff-so-fancy` | (configured in gitconfig) | Opinionated diff post-processor |
| `commit-msg` | `bin/commit-msg` | AI commit message from staged diff via RTK+ai-query |
| `diff-review` | `bin/diff-review` | AI review of staged or arbitrary diff before committing |
| `alias-suggest` | `bin/alias-suggest` | Scan atuin history, suggest zsh aliases for repeated commands |

---

## Data & Text Processing

| Tool | Command | Purpose |
|------|---------|---------|
| `jq` | `jq '.patterns[].name' etc/phi-patterns.yaml` | JSON processing; required by analytics pipeline |
| `yq` | `yq '.patterns[]' etc/phi-patterns.yaml` | YAML processing; required by phi_scrubber.bash |
| `fzf` | (shell integration) | Fuzzy finder — history, file, process selection |
| `bat` | `bat bin/zdots-ctx` | `cat` with syntax highlighting and line numbers |
| `eza` | `eza -la --git` | `ls` with git status, icons, tree view |
| `fd` | `fd '\.bats$' tests/` | Fast `find` alternative |
| `dasel` | `dasel -f file.yaml '.key'` | Query/update YAML/JSON/TOML/CSV from the CLI |
| `miller` (mlr) | `mlr --csv stats1 -a mean -f duration_ms` | CSV/JSON analytics pipelines |
| `gron` | `gron response.json \| grep token` | Make JSON greppable |

---

## Infrastructure & Services

| Tool | Command | Purpose |
|------|---------|---------|
| `colima` | `colima start` | Lightweight Docker runtime for LGTM stack |
| `lazydocker` | `lzd` | TUI for Docker containers and images |
| `docker` / `docker-compose` | `docker compose up` | Container management |
| `otel-collector` | `bin/otel-collector start` | Bare-metal OTel collector (managed, not Homebrew) |
| `local-ci` | `bin/local-ci up` | LGTM stack in Colima (Grafana/Loki/Tempo) |
| `nginx` | (managed via launchctl) | TLS reverse proxy for local service hostnames |
| `mkcert` | `mkcert -install` | Local CA + certs for `*.local` hostnames |
| `tailscale` | `tailscale status` | Mesh VPN — secure LAN endpoint access |

---

## Quick orientation for a new session

```bash
zdots-ctl status          # all services green?
zdots-ctx status          # PostgreSQL + job queue healthy?
agent-guide               # full endpoint + capability map
capabilities --json | jq  # machine contract
```
