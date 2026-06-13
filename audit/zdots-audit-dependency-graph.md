# zdots Dependency Graph
Generated: 2026-06-13
Mode: read-only — no production files modified

This artifact maps the load-time and call-time dependency graph for the zdots
repo. It is structured as layers: each layer consumes the one below it.

---

## Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 6 — External Services                                    │
│  llama.cpp :11500 · PostgreSQL (my) · OpenObserve :5080        │
│  OTel Collector :4317/4318                                      │
└────────────────────────────┬────────────────────────────────────┘
                             │ network/socket
┌────────────────────────────▼────────────────────────────────────┐
│  LAYER 5 — MCP Servers (.mcp.json)                              │
│  backlog (backlog mcp start)                                    │
│  ctx    (bin/ctx-mcp)    → LAYER 4 (zdots-ctx via Open3)       │
│  llama  (bin/llama-mcp)  → LAYER 6 (llama.cpp endpoint)        │
└────────────────────────────┬────────────────────────────────────┘
                             │ stdio JSON-RPC 2.0
┌────────────────────────────▼────────────────────────────────────┐
│  LAYER 4 — bin/ Commands (87 files)                             │
│  zdots-ctx, zdots-ctl, zdots-ask, ai-query, llama-ctl, zsvc,   │
│  cc-hook-guard, pi-ctx-*, zdots-brain (→ sbin/zdots-brain), …  │
└────────────────────────────┬────────────────────────────────────┘
                             │ source / require_relative
┌────────────────────────────▼────────────────────────────────────┐
│  LAYER 3 — lib/ (Bash + Ruby)                                   │
│  Bash: ai-invoke, phi_scrubber, message_hygiene, ai_boundary,  │
│        svc-launchd, svc-process, svc-health, keychain, trace   │
│  Ruby: zdots.rb → zdots/db, zdots/crypto, zdots/models,        │
│        zdots/ai/client → zdots/ai/pipeline                     │
│  Go (cmd/): zdots-phi-scrub, zdots-secret-scan, buffer-drain   │
└────────────────────────────┬────────────────────────────────────┘
                             │ source (at shell startup)
┌────────────────────────────▼────────────────────────────────────┐
│  LAYER 2 — conf.d/ (23 .zsh files, loaded in numeric order)    │
│  01 → 05 → 08 → 10 → 15 → 20 → 30 → 40 → 50 → 55 → 56 →      │
│  60 → 70 → 71 → 72 → 73 → 74 → 75 → 76 → 80 → 90 → 95 → 97   │
└────────────────────────────┬────────────────────────────────────┘
                             │ source
┌────────────────────────────▼────────────────────────────────────┐
│  LAYER 1 — Shell Entrypoints                                    │
│  .zshrc → .zprofile → .zshenv (sacred; do not touch)           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Layer 2 — conf.d Load Order

| File | Key action |
|------|------------|
| `01-zdots-bin.zsh` | PATH: `$ZDOTDIR/bin` first |
| `05-observability.zsh` | OTel tracing init (`zdots_trace_init`) |
| `08-local-bin.zsh` | PATH: `$HOME/.local/bin` |
| `10-homebrew.zsh` | Homebrew prefix, `zdots_pkg_manager_init` |
| `15-safe-rm.zsh` | Interactive `rm` guard |
| `20-prompt.zsh` | P10k theme (sources p10k.zsh) |
| `30-env.zsh` | Core env vars (`ZDOTS_AI_MODE`, `ZDOTS_CONTEXT`, …) |
| `40-completion.zsh` | `compinit`, `fpath` |
| `50-options.zsh` | `setopt` |
| `55-phi-history.zsh` | ← `lib/audit_log.bash`, `lib/shell_hook_metrics.bash`; hooks `precmd` for PHI audit trail |
| `56-cmd-analytics.zsh` | Command analytics buffer (`_zca_redact` suppress+scrub) |
| `60-bindings.zsh` | Keybindings |
| `70-shell-helpers.zsh` | `zsh-defer`; base for 71/73/74/76 |
| `71-shell-tools.zsh` | ← `conf.d/70-shell-helpers.zsh`; broot completion |
| `72-ai-function.zsh` | `zdots_ai_infer` ZLE function |
| `73-zsh-plugins.zsh` | ← `70`; autosuggestions, vi-mode, autopair |
| `74-fzf.zsh` | ← `70`; fzf-tab, `.fzf.zsh`, `fzfrc` |
| `75-local-overrides.zsh` | ← `.zshrc.local` (untracked) |
| `76-history-widgets.zsh` | ← `70`; substring-search |
| `80-aliases.zsh` | ← `.aliasrc` (untracked) |
| `90-mise.zsh` | `mise activate`, `zdots_node_runtime_init` |
| `95-ai.zsh` | ← provider file; `zdots_ai_init`, `zdots_whisper_init` |
| `97-zle-ai.zsh` | ← `lib/ai-invoke.bash`; binds ZLE AI widget |

**Intra-conf.d dependencies** (load order must be respected):
- `71`, `73`, `74`, `76` all depend on `70`
- `97` depends on `lib/ai-invoke.bash` being loadable (bash in zsh)

---

## Layer 3 — Bash lib Dependency Graph

```
lib/ai-invoke.bash
  └── lib/ai_boundary.bash         (gate: blocks cloud egress)
  └── lib/message_hygiene.bash
        └── lib/phi_scrubber.bash  ← SACRED — PHI Scrubber

lib/ai-query-lib.bash
  └── lib/message_hygiene.bash     (conditional source)
        └── lib/phi_scrubber.bash

lib/lifecycle.bash
  └── lib/svc-launchd.bash
        └── lib/svc-health.bash    (health probe primitives)
  └── lib/svc-process.bash
        └── lib/svc-health.bash

lib/trace_log.bash                 (no dependencies)
lib/keychain.bash                  (no dependencies)
lib/audit_log.bash                 (no dependencies)
lib/svc-registry.bash              (no dependencies)
lib/model-store.bash               (no dependencies)
lib/cc-context.bash                (no dependencies)
lib/metadata.bash                  (no dependencies)
```

**PHI Scrubber chain:** `ai-invoke` → `message_hygiene` → `phi_scrubber`.
This is the Message Hygiene Pipeline: normalize (message_hygiene) then scrub
(phi_scrubber), order enforced by the source chain.

---

## Layer 3 — Ruby lib Dependency Graph

```
lib/zdots.rb  (root require)
  └── lib/zdots/db.rb
  └── lib/zdots/crypto/key_store.rb
  └── lib/zdots/models/encrypted_content.rb
  └── lib/zdots/models/searchable.rb
  └── lib/zdots/ai/client.rb
        └── lib/zdots/ai/pipeline.rb
              └── lib/zdots.rb     (circular via load path — resolved by Bundler)

lib/zdots/manifest.rb              (standalone, no internal deps)

lib/zdots/jobs/base.rb             (base class)
lib/zdots/jobs/distill.rb          → base
lib/zdots/jobs/docs_sync.rb        → base
lib/zdots/jobs/embed.rb            → base
lib/zdots/jobs/transcription.rb    → base
lib/zdots/jobs/pattern_analysis.rb → base

lib/zdots/models/job.rb
lib/zdots/models/lesson.rb
lib/zdots/models/methodology.rb
lib/zdots/models/session_residue.rb

lib/zdots/migrator.rb
lib/zdots/schema_version.rb
lib/zdots/verify_db.rb

lib/ruby_audit/report_builder.rb
lib/ruby_audit/runners.rb
lib/ruby_audit/slice_builder.rb    (standalone ruby-audit suite)
```

---

## Layer 3 — Go Binaries (cmd/)

| Binary | Build target | Role |
|--------|-------------|------|
| `cmd/zdots-phi-scrub/` | `bin/zdots-phi-scrub` | PHI Scrubber (ADR-0002); no runtime deps |
| `cmd/zdots-secret-scan/` | `bin/zdots-secret-scan` | Secret scanner; RE2 registry (pkg/re2registry) |
| `cmd/zdots-buffer-drain/` | (bin/) | OTel analytics buffer drain |

Shared: `pkg/re2registry/` — RE2 pattern engine used by both phi-scrub and
secret-scan. The unification from the previous session's refactor.

---

## Layer 4 — bin/ → lib/ Source Map

| bin/ command | lib/ dependencies |
|-------------|------------------|
| `zdots-ask` | `ai-invoke.bash`, `trace_log.bash` |
| `zdots-ctx` | `ai-invoke.bash`, `keychain.bash`, `svc-health.bash`, `trace_log.bash` |
| `zdots-ctl` | `svc-health.bash`, `svc-registry.bash`, `trace_log.bash` |
| `ai-query` | `ai_boundary.bash` |
| `zdots-quiz` | `ai_boundary.bash` |
| `zmorning` | `ai_boundary.bash`, `trace_log.bash` |
| `cc-hook-guard` | `cc-context.bash` |
| `cc-doctor` | `cc-context.bash` |
| `cc-hook-session` | `cc-context.bash` |
| `cc-statusline` | `cc-context.bash` |
| `llama-ctl` | `model-store.bash`, `svc-launchd.bash` |
| `whisper-ctl` | `model-store.bash` |
| `openobserve-ctl` | `svc-launchd.bash`, `svc-process.bash` |
| `otel-collector` | `svc-launchd.bash`, `svc-process.bash` |
| `zdots-worker` | `svc-launchd.bash`, `svc-process.bash`, `keychain.bash` |
| `zsvc` | `svc-registry.bash` |
| `zdots-logs` | `svc-registry.bash` |
| `pi-ctx-hydrate` | `phi_scrubber.bash` |
| `pi-ctx-query` | `phi_scrubber.bash` |
| `zdots-o2-query` | `phi_scrubber.bash` |
| `zdash` | `trace_log.bash` |
| `zdots-doctor` | `trace_log.bash` |
| `zdots-endpoints` | `trace_log.bash` |
| `ztask` | `svc-health.bash`, `trace_log.bash` |
| `gemini-invoke` | `svc-health.bash` |
| `zdots-keychain` | `keychain.bash` |
| `zdots-status` | `keychain.bash` |
| `zdash` | `trace_log.bash` |

**bin/ → lib/ → external (Ruby):**

| bin/ | lib/ | calls |
|------|------|-------|
| `bin/ctx-mcp` | `lib/zdots.rb`, `lib/zdots/manifest.rb` | `bin/zdots-ctx` (Open3) |
| `sbin/zdots-brain` | `lib/zdots.rb`, jobs/*, models/* | PostgreSQL (`my`) |
| `sbin/zdots-recommend` | `lib/zdots.rb` | PostgreSQL (`my`) |
| `bin/zdots-schema` | `lib/zdots/schema_version.rb` | — |
| `bin/zdots-config` | `lib/zdots/config.rb` | — |

---

## Layer 5 — MCP Servers

```
.mcp.json
  ├── backlog → backlog mcp start     (external CLI, no zdots lib dep)
  │
  ├── ctx    → bin/ctx-mcp
  │              ├── lib/zdots.rb
  │              ├── lib/zdots/manifest.rb   (TOOLS array, 10 mcp:true)
  │              └── bin/zdots-ctx (Open3)   → Layer 6 (PostgreSQL)
  │
  └── llama  → bin/llama-mcp
                 └── ZDOTS_AI_ENDPOINT        → Layer 6 (llama.cpp :11500)
```

**ctx-mcp tool advertisement** (manifest.rb, 10 tools):

| Tool | Write? | Was gap? |
|------|--------|----------|
| ctx_status | no | — |
| ctx_query | no | — |
| ctx_hydrate | no | — |
| ctx_enqueue | yes | — |
| living_docs | yes | — |
| ctx_add_methodology | yes | **was gap** |
| ctx_add_lesson | yes | **was gap** |
| ctx_capture | yes | **was gap** |
| ctx_semantic_search | no | **was gap** |
| ctx_jobs | no | **was gap** |

**llama-mcp tools** (5, all in bin/llama-mcp):
`llama_capabilities`, `llama_health`, `llama_config`, `llama_run_test`,
`llama_integration_snippet`

---

## Cross-Call Frequency (files referencing each hub command)

| Command | Files referencing it | Role |
|---------|---------------------|------|
| `zdots-ctx` | 33 | Knowledge Layer CLI gateway |
| `llama-ctl` | 29 | AI inference service manager |
| `zdots-ctl` | 18 | Platform orchestrator |
| `zsvc` | 15 | Per-service control interface |
| `ai-query` | 15 | Scripted inference |
| `zdots-brain` | 10 | Knowledge Layer binary |
| `zdots-ask` | 10 | Domain AI router |
| `colima-status` | 4 | Docker runtime status |

These are the highest-fan-in commands — changes to their interfaces have the
widest blast radius.

---

## Critical Paths (PHI/Security)

```
Any AI call:
  bin/* → lib/ai-invoke.bash → lib/message_hygiene.bash
                              → lib/phi_scrubber.bash → [scrubbed]
                             → lib/ai_boundary.bash   → [locality check]
                             → ZDOTS_AI_ENDPOINT       → llama.cpp :11500

CC hook path (every CC prompt):
  cc-hook-guard → lib/cc-context.bash → deny-list check

History / analytics path:
  conf.d/55-phi-history.zsh → lib/audit_log.bash → macOS Unified Logging
  conf.d/56-cmd-analytics.zsh → _zca_redact → suppress-flagged drop

PHI Scrubber binary path (Go):
  bin/zdots-phi-scrub (cmd/zdots-phi-scrub/) ← called by lib/phi_scrubber.bash
  pkg/re2registry ← shared with bin/zdots-secret-scan
```

---

## Dependency Hotspots (highest fan-in in lib/)

| lib/ file | Dependents | Notes |
|-----------|-----------|-------|
| `phi_scrubber.bash` | message_hygiene, pi-ctx-*, zdots-o2-query | Sacred; do not modify |
| `message_hygiene.bash` | ai-invoke, ai-query-lib | Normalize before scrub |
| `ai-invoke.bash` | zdots-ask, zdots-ctx, conf.d/97 | AI call entry point |
| `ai_boundary.bash` | ai-invoke, ai-query, zdots-quiz, zmorning | Cloud egress gate |
| `svc-health.bash` | svc-launchd, svc-process, zdots-ctl, ztask, gemini-invoke, zdots-ctx | Health probe shared primitives |
| `svc-launchd.bash` | lifecycle, llama-ctl, openobserve-ctl, otel-collector, zdots-worker | launchd lifecycle |
| `trace_log.bash` | zdash, zdots-ask, zdots-ctx, zdots-ctl, zdots-doctor, zdots-endpoints, zmorning, ztask | Observability breadcrumbs |
| `keychain.bash` | zdots-ctx, zdots-worker, zdots-status, zdots-keychain | Credential access |
| `cc-context.bash` | cc-hook-guard, cc-doctor, cc-hook-session, cc-statusline | CC integration layer |
| `svc-registry.bash` | zdots-ctl, zsvc, zdots-logs | Service registry |

---

## Notes for Future Passes

1. **Circular Ruby dep** (`zdots/ai/pipeline` → `lib/zdots.rb`) should be
   verified — Bundler resolves it but it's worth confirming with `ruby -e
   "require_relative 'lib/zdots'"`.

2. **lib/shell_hook_metrics.bash** sourced by `55-phi-history.zsh` but not
   listed in lib/ tree — likely generated or conditionally present; confirm.

3. **lifecycle.bash** — sourced by zdots-ctl (indirectly via svc-launchd)?
   Confirm: `grep -r 'lifecycle' bin/`. Currently only svc-launchd/svc-process
   source it — this may be dead code.

4. **bin/bootstrap** sources lib/ but its full dep chain was not traced here.

5. **experiments/zsynod/** — currently fully isolated. If promoted, its
   Python lib (`zsynod_core.py`, `zsynod_otel.py`) will need a new layer
   between lib/ (bash/Ruby) and bin/.
