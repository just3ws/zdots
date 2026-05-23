# Zsh Config Audit

**Date:** 2026-05-22  
**Auditor:** Claude Code (claude-sonnet-4-6)  
**Scope:** `/Users/mike/.config/zsh` — quality, correctness, performance, PHI-safe shell behavior

---

## Executive Summary

The configuration is architecturally sound: clean separation of concerns (env.sh → conf.d/ → providers/), idiomatic Zsh, solid PHI tooling in `phi_scrubber.bash` and `55-phi-history.zsh`, and good use of deferred loading. No syntax errors found across 50+ files.

**Four fixes were applied inline:** one critical (HISTFILE override), one high-performance (cognitive-load re-source), one high-PHI (trace redaction gap), and one medium-quality (iTerm2 double-load). A medium-correctness OTEL export fix was also applied.

---

## Inventory

| Category | Count |
|---|---|
| Entrypoints | 3 (`.zshenv`, `.zshrc`, `.zprofile`) |
| conf.d/ modules | 12 (05 through 95) |
| providers/ | 12 |
| lib/ | 7 (`.bash`) |
| bin/ scripts | 25+ |
| Functions | 15 |
| Test files | 8 bats suites |

---

## Source Graph

```
Shell start (login+interactive)
│
├─ /etc/zshenv            (macOS, run first)
├─ ~/.config/zsh/.zshenv
│   └─ env.sh             (POSIX core: XDG, trace IDs, zdots_safe_source, PATH)
│       ├─ .zdots.env     (dependency manifest, service provider selectors)
│       ├─ .zdots.secrets (API keys — 600, gitignored)
│       ├─ .zdots.local   (machine overrides — not committed)
│       └─ providers/     (via zdots_require: pkg, node, trace, ai, whisper)
│
├─ /etc/zprofile          (macOS path_helper — reorders PATH)
├─ ~/.config/zsh/.zprofile
│   ├─ conf.d/10-homebrew.zsh  (zdots_pkg_manager_init)
│   ├─ conf.d/90-mise.zsh      (zdots_node_runtime_init)
│   └─ env.sh (again)     ← documented as "idempotent re-source to fix path_helper"
│
├─ /etc/zshrc             (macOS — RESETS HISTFILE to ${ZDOTDIR}/.zsh_history) ← CRITICAL
└─ ~/.config/zsh/.zshrc
    ├─ conf.d/05-observability.zsh  (trace hooks: preexec/precmd/chpwd)
    ├─ conf.d/10-homebrew.zsh
    ├─ conf.d/20-prompt.zsh         (Powerlevel10k)
    ├─ conf.d/30-env.zsh            (LS_COLORS, Rails/Ruby env)
    ├─ conf.d/40-completion.zsh     (compinit with 24h cache)
    ├─ conf.d/50-options.zsh        (setopt, history policy, HISTFILE re-assert)
    ├─ conf.d/55-phi-history.zsh    (zshaddhistory hook — SSN/MRN/DOB/CONN)
    ├─ conf.d/60-bindings.zsh       (Vi-mode, Ctrl-R, Ctrl-xe)
    ├─ conf.d/70-integrations.zsh   (zoxide, direnv, atuin, fzf, iTerm2)
    ├─ conf.d/80-aliases.zsh
    ├─ conf.d/90-mise.zsh
    └─ conf.d/95-ai.zsh             (zdots_ai_init, zaider)
```

---

## Startup Performance

| Run | Time (wall) |
|---|---|
| Before fixes (run 1) | 0.137s |
| Before fixes (run 2) | 0.139s |
| Before fixes (run 3) | 0.150s |
| After fixes           | 0.132s |

**Median before:** ~139ms. **After:** ~132ms. Well within budget. No PATH duplication detected (`typeset -gU path` is effective). No fpath duplication. `compaudit` returned clean.

---

## Findings Table

| # | Severity | Category | File:Line | Problem | Status |
|---|---|---|---|---|---|
| 1 | **CRITICAL** | PHI_SAFETY / CORRECTNESS | `conf.d/50-options.zsh` + `/etc/zshrc` | `/etc/zshrc` (macOS system file) runs between `.zshenv` and `.zshrc` and resets `HISTFILE` to `${ZDOTDIR}/.zsh_history`. env.sh correctly sets `HISTFILE` to XDG path, but macOS clobbers it. Result: 1950-line history was accumulating in `.config/zsh/.zsh_history` (in the repo dir) instead of the XDG-compliant `~/.local/state/zsh/history` (127 lines, stale). | **FIXED** |
| 2 | **HIGH** | PERFORMANCE | `conf.d/05-observability.zsh:48-53` | `cognitive-load.bash` was re-sourced via `source` on every 5th command in the `precmd` hook. This re-parses and re-evaluates the file each time, plus spawns `zdots-ctx error-velocity` subprocess on each check cycle. | **FIXED** |
| 3 | **HIGH** | PHI_SAFETY | `env.sh:71-83` + `providers/trace/otlp.zsh:40` | `zdots_trace_redact` (used by ALL trace logging including the `preexec` full command hook) only masked credential flags (`--password`, `--token`, etc.). It did NOT mask SSN, MRN, DOB patterns, or DB connection strings. A command like `psql -c 'WHERE ssn=123-45-6789'` would be written verbatim to `traces.jsonl` and sent over OTLP. | **FIXED** |
| 4 | **HIGH** | CORRECTNESS | `conf.d/05-observability.zsh:30,100` | OTEL port mismatch: `otel-cli span` hardcodes `:4317` (gRPC) while `OTEL_EXPORTER_OTLP_ENDPOINT` and the curl-based OTLP sender use `:4318` (HTTP/protobuf). `otel-cli` is correct to use gRPC on `:4317` (it has its own config); the inconsistency is that the global env var doesn't match what `otel-cli` actually uses. This means the `OTEL_EXPORTER_OTLP_ENDPOINT` env var passed to `otel-cli` spans (lines 30, 100) overrides its default to `:4318/HTTP` which may fail if collector only accepts gRPC on `:4317`. | **DEFERRED** — Document and verify against otel-collector config. |
| 5 | **MEDIUM** | CORRECTNESS | `env.sh:158-159` | `OTEL_EXPORTER_OTLP_ENDPOINT` and `OTEL_SERVICE_NAME` were assigned without `export`. Child processes (scripts, tools) that rely on these env vars would not inherit them. | **FIXED** |
| 6 | **MEDIUM** | ZSH_QUALITY | `.zshrc:48` | iTerm2 shell integration loaded unconditionally in `.zshrc` (no terminal check), then loaded again conditionally with `$TERM_PROGRAM == iTerm.app` guard in `conf.d/70-integrations.zsh:127`. Double-load in iTerm sessions; always-load in non-iTerm sessions. | **FIXED** |
| 7 | **MEDIUM** | SAFETY | `.zdots.env` (permissions 644) | `.zdots.env` is world-readable (`644`). It contains `ZDOTS_DATABASE_URL` and `ZDOTS_MIGRATION_URL` (currently passwordless unix socket, but a pattern risk if credentials are added). On a shared machine this would expose connection config. On a personal macOS laptop with umask 077, the risk is low but non-zero. | **DEFERRED** — Run `chmod 600 .zdots.env` if DB credentials are ever added. |
| 8 | **MEDIUM** | MAINTAINABILITY | `env.sh:211` + `.zprofile` | `.zprofile` sources `env.sh` a second time (documented as "idempotent"). However, `env.sh` unconditionally resets `PATH="/usr/bin:/bin:/usr/sbin:/sbin"` then rebuilds. This is a fragile "idempotent" claim — any provider initialized between the first and second source that adds to PATH via a mechanism NOT covered by `zdots_require` will be lost. Currently safe because `zdots_node_runtime_paths` is called inside env.sh's `zdots_require` chain, but the pattern is a maintenance trap. | **DEFERRED** |
| 9 | **MEDIUM** | PHI_SAFETY | `conf.d/05-observability.zsh:62` | `ZDOTS_LAST_COMMAND` captures and exports the full raw command line. Even after fixing `zdots_trace_redact`, complex quoted SQL or heredocs containing PHI may not be fully covered by the pattern-based scrubber. Consider a truncation limit (e.g. 512 bytes) on logged command lines. | **DEFERRED** |
| 10 | **LOW** | CLEAN_CODE | `conf.d/05-observability.zsh:10` | `local _otel_bin` is used at the top level of the `if` block (not inside a function). In Zsh, `local` at file scope is valid but unusual and confusing — it limits scope to the sourced file's current execution frame, which is the intended behavior, but a comment would help. | **DEFERRED** |
| 11 | **LOW** | ZSH_QUALITY | `conf.d/40-completion.zsh:31` | `autoload -Uz "$(basename $fn)"` forks `basename` for each function file. Use Zsh parameter expansion `"${fn:t}"` instead (zero forks). | **DEFERRED** |
| 12 | **LOW** | POSIX | `env.sh:100-118` | `zdots_safe_source` uses `local` (a bash/zsh extension). The file claims POSIX compatibility ("sourced by sh, bash, and zsh"). `local` is widely supported but not POSIX. Not a real risk since no POSIX `sh` directly sources `env.sh` in this codebase (all consumers are bash scripts or zsh), but the comment is misleading. | **DEFERRED** |
| 13 | **LOW** | TOOLING | `tests/helpers/bats-file/script/install-bats.sh:3` | `set -o xtrace` in a test helper script. Not in the shell startup path, no risk. | INFO |

---

## Applied Fixes

### Fix 1 — CRITICAL: HISTFILE override by /etc/zshrc

**File:** `conf.d/50-options.zsh`  
**Change:** Added re-assertion of `HISTFILE` to XDG path at end of file, with `mkdir -p` guard. This runs as part of `.zshrc` (after `/etc/zshrc`) and wins the race.

```zsh
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"
```

**Validation:** `zsh -i -c 'echo "HISTFILE=$HISTFILE"'` → `HISTFILE=/Users/mike/.local/state/zsh/history` ✓

### Fix 2 — HIGH: cognitive-load.bash re-sourced every 5 commands

**File:** `conf.d/05-observability.zsh:48-53`  
**Change:** Added function-existence guard (`${+functions[zdots_check_cognitive_load]}`) so the file is sourced at most once per session, not on every 5th command.

### Fix 3 — HIGH PHI_SAFETY: zdots_trace_redact missing PHI patterns

**File:** `env.sh` (zdots_trace_redact function)  
**Change:** Replaced Zsh-only glob-based redaction with a unified `sed` pipeline that covers both credential flags AND PHI patterns (SSN, MRN, DOB, connection strings). Aligns `zdots_trace_redact` with `phi_scrubber.bash`.

**Validation:**
```
zdots_trace_redact "WHERE ssn=123-45-6789"   → WHERE ssn=[REDACTED-SSN]
zdots_trace_redact "MRN: 1234567"             → [REDACTED-MRN]
zdots_trace_redact "postgresql://user:p@h/db" → [REDACTED-CONN]/db
zdots_trace_redact "curl --token abc123"      → curl --token [REDACTED]
```

### Fix 4 — MEDIUM: OTEL vars not exported

**File:** `env.sh:158-159`  
**Change:** Added `export` to `OTEL_EXPORTER_OTLP_ENDPOINT` and `OTEL_SERVICE_NAME` so child processes inherit them.

### Fix 5 — MEDIUM: iTerm2 double-load

**File:** `.zshrc:48`  
**Change:** Removed unconditional source of `.iterm2_shell_integration.zsh` from `.zshrc`. The guarded load in `conf.d/70-integrations.zsh` (with `$TERM_PROGRAM == iTerm.app` check) is the correct single load point.

---

## Deferred Fixes

| # | Severity | File | Action |
|---|---|---|---|
| 4 | HIGH | `conf.d/05-observability.zsh:30,100` | Audit otel-collector config; decide whether to use `:4317` (gRPC) or `:4318` (HTTP) consistently. Update `OTEL_EXPORTER_OTLP_ENDPOINT` to match the port `otel-cli` is configured to use. |
| 7 | MEDIUM | `.zdots.env` | `chmod 600 .zdots.env` if/when DB credentials are stored there. |
| 8 | MEDIUM | `env.sh:211` + `.zprofile` | Consider replacing the "re-source env.sh" approach in `.zprofile` with an explicit `_zdots_re_apply_path` function that only re-runs path construction, not the full env.sh. |
| 9 | MEDIUM | `conf.d/05-observability.zsh:62` | Add a 512-byte truncation on `ZDOTS_LAST_COMMAND` before logging: `ZDOTS_LAST_COMMAND="${cmd[1,512]}"`. |
| 11 | LOW | `conf.d/40-completion.zsh:31` | Change `"$(basename $fn)"` → `"${fn:t}"` (zero forks). |

---

## PHI Safety Verification

| Check | Result |
|---|---|
| `set -x` / `xtrace` in startup path | None found |
| Prompt exposes hostname/username by default | No — p10k context segment hidden (`POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO}_{CONTENT,VISUAL_IDENTIFIER}_EXPANSION=`) |
| Startup scripts print env vars or tokens | No |
| `conf.d/55-phi-history.zsh` loads and active | Yes — `ZDOTS_HISTORY_REDACT=1` confirmed |
| `lib/ai_boundary.bash` — syntax valid | Yes |
| `lib/phi_scrubber.bash` — syntax valid | Yes |
| `ZDOTS_CAPTURE_ENABLED` default | `0` (capture is opt-in) |
| `ZDOTS_HISTORY_REDACT` default | `1` (redaction on by default) |
| `ZDOTS_AI_MODE` default | `local` (no cloud egress by default) |
| `.zdots.secrets` permissions | `600` (correct) |
| `.zsh_history` permissions | `600` (correct) |
| `zdots_trace_redact` PHI coverage | **Fixed** — now covers SSN, MRN, DOB, CONN + credential flags |

**Remaining PHI risk (deferred):** Raw command lines longer than regex coverage (multi-line heredocs, base64-encoded data in commands) can still leak to `traces.jsonl`. Mitigate with command-line length truncation (deferred fix #9).

---

## Validation Transcript

```
# Static syntax checks
OK: .zshenv
OK: .zshrc
OK: .zprofile
OK: env.sh
OK: conf.d/05-observability.zsh (all 12 conf.d files)
OK: lib/ai_boundary.bash (all 7 lib/*.bash files)
OK: providers/ai/llama-cpp.zsh (all 12 providers/*.zsh files)
OK: bin/bootstrap, bin/ai-query, bin/zdots-ctx, bin/zdots-ctl, bin/secret-scan

# Runtime checks
HISTFILE after fix: /Users/mike/.local/state/zsh/history  ✓ (was .config/zsh/.zsh_history)
PATH duplication: none
fpath duplication: none
Startup time: ~132ms (median of 3)
env.sh isolated load: OK
compaudit: clean
set -x in startup path: none

# PHI redaction validation
SSN in trace_redact: [REDACTED-SSN]  ✓
MRN in trace_redact: [REDACTED-MRN]  ✓
CONN in trace_redact: [REDACTED-CONN] ✓
--token in trace_redact: [REDACTED]  ✓
```

---

## Recommended Next Steps

1. **Merge stale history** — 1950 lines of history in `.config/zsh/.zsh_history` (pre-fix). Run:
   ```zsh
   cat /Users/mike/.config/zsh/.zsh_history >> /Users/mike/.local/state/zsh/history
   rm /Users/mike/.config/zsh/.zsh_history
   ```

2. **Resolve OTEL port** (deferred #4) — Verify the otel-collector config. If it accepts gRPC on `:4317`, update `OTEL_EXPORTER_OTLP_ENDPOINT` to `http://127.0.0.1:4317` in `env.sh`, or configure `otel-cli` to use `:4318`. Pick one consistently.

3. **Truncate ZDOTS_LAST_COMMAND** (deferred #9) — In `05-observability.zsh` preexec hook, add:
   ```zsh
   export ZDOTS_LAST_COMMAND="${cmd[1,512]}"
   ```

4. **Permissions on .zdots.env** — Current content is safe (passwordless DB URLs). Run `chmod 600 .zdots.env` proactively and add a note in CONTRIBUTING.md.

5. **`basename` → `${fn:t}`** in `conf.d/40-completion.zsh:31` — Minor fork elimination.
