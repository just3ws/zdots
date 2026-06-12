---
name: zdots-integrate
description: Integration checklist for new zdots capabilities. Walks every registration point, wiring layer, and verification step so nothing is left half-connected.
---

# /zdots-integrate — New Capability Integration Checklist

Run this skill after building any new zdots command, service, library, or
configuration module. It walks every layer that must know about the new thing
and verifies each one is wired correctly.

Provide the capability name and type when invoking:
```
/zdots-integrate bin/zdots-logs command
/zdots-integrate llama service
/zdots-integrate conf.d/08-local-bin.zsh module
```

If type is omitted, the skill will inspect the path and infer it.

---

## Layer Matrix

Work through every layer. Skip only if the layer is genuinely not applicable
(mark it N/A with a one-line reason — never silently skip).

### Layer 1 — Executable / File

| Item | Check |
|------|-------|
| File exists at correct path (`bin/`, `lib/`, `conf.d/`) | `[[ -f path ]]` |
| Correct permissions (`+x` for executables, not for libs) | `ls -l path` |
| Passes `shellcheck --severity=warning` | `shellcheck path` |
| Follows zdots naming convention (`zdots-*`, `zsvc`, etc.) | visual |

**Heal:** `chmod +x bin/<name>` for missing execute bit. File `zdots-issue` for
shellcheck failures in infrastructure; fix directly for new code.

---

### Layer 2 — Help Text

| Item | Check |
|------|-------|
| `--help / -h` exits 0 and prints usage | `<cmd> --help` |
| Help text includes: purpose, commands/flags, examples | read output |
| Help is embedded at top of file (lines 2–N, extracted via `sed`) | `head -30 path` |

**Standard pattern:**
```bash
# bin/my-cmd — One-line description.
#
# Commands:
#   ...
# -h, --help  Show this help
```

---

### Layer 3 — Knowledge Base (tooling catalog)

| Item | Check |
|------|-------|
| `zdots-index-tools` knows about it | `zdots-ctx query tooling:<name>` |
| Catalog entry has full help text | check output length |
| Scenarios entry covers common use case | `zdots-ctx query tooling:scenarios` + grep |

**Heal:**
```bash
zdots-index-tools --force       # rebuild the full catalog
zdots-ctx query tooling:<name>  # verify entry exists
```

If the catalog entry is missing after `--force`, check that the file is
executable and that `--help` exits 0.

---

### Layer 4 — Claude Code Allowlist

| Item | Check |
|------|-------|
| Command is in `.claude/settings.json` allow array | `grep <name> .claude/settings.json` |
| Rule uses prefix wildcard: `"Bash(<name>:*)"` | visual |

**Heal:** Add to the `permissions.allow` array in `.claude/settings.json`:
```json
"Bash(zdots-logs:*)"
```

Group it with related zdots tools (alphabetical within the group).

---

### Layer 5 — Agent Guide + Capabilities (for user-facing tools)

Skip for internal library functions. Apply for any `bin/` command agents or
users might reach for.

| Item | Check |
|------|-------|
| `agent-guide` mentions the command in the relevant section | `agent-guide | grep <name>` |
| `capabilities --json` reports it (if it has a health endpoint) | `capabilities --json | grep <name>` |
| `AGENTS.md` task table updated if it serves a common workflow | `grep <name> AGENTS.md` |

**Heal:** Add entries to `bin/agent-guide` and `bin/capabilities` as appropriate.
Update `AGENTS.md` tool table if the command covers a workflow currently missing.

---

### Layer 6 — Service Registry (for services only)

Skip for commands and modules. Apply for any new managed service.

| Item | Check |
|------|-------|
| `_svc_reg` entry in `lib/svc-registry.bash` | `grep <name> lib/svc-registry.bash` |
| Log path, label, ctl, endpoint all set correctly | read the entry |
| `zsvc list` shows the service | `zsvc list` |
| `zsvc start/stop/health <svc>` work | test each |
| `colima: no log path` handled if it delegates to ctl | verify `ZDOTS_SVC_LOGS` field |

**Heal:** Edit `lib/svc-registry.bash` — but only if you were asked to add the
service. File `zdots-issue` if the service exists but is mis-registered.

---

### Layer 7 — Shell Integration (for conf.d modules)

Skip unless the capability adds a conf.d module.

| Item | Check |
|------|-------|
| Module numbered correctly (load order) | `ls conf.d/` |
| `source conf.d/<module>` in `.zshrc` or auto-loaded | `grep <module> .zshrc` |
| No global side effects at parse time (only function defs + hooks) | read module |
| Passes `zsh -n conf.d/<module>` syntax check | `zsh -n path` |

---

### Layer 8 — Tests

| Item | Check |
|------|-------|
| Test file exists in `tests/` | `ls tests/*<name>*` |
| `bats tests/` exits 0 | `bats tests/` |
| Tests cover: happy path, error path, flag parsing | read test file |

**Heal:** Add `tests/<name>.bats` for new commands. File `zdots-issue` for
failing tests in unrelated areas.

---

### Layer 9 — Documentation

| Item | Check |
|------|-------|
| Man page exists in `share/man/man1/` (for user-facing commands) | `ls share/man/man1/<name>*` |
| `zdots-system-description.md` is still accurate | `grep <name> docs/zdots-system-description.md` |
| Any relevant `docs/wiki/` page updated | assess manually |

Man pages are required only for primary user-facing commands. Internal tools
and library scripts do not need man pages.

---

### Layer 10 — zdots-heal Awareness

| Item | Check |
|------|-------|
| Does the new capability affect any `/zdots-heal` gate? | assess |
| If yes: is the gate's check command updated? | read `.claude/commands/zdots-heal.md` |
| Does `/zdots-integrate` itself need updating? | meta-check |

---

## Reporting Format

After all layers, produce a table:

```
=== zdots-integrate: <name> (<type>) — <timestamp> ===

Layer 1  Executable:      PASS | FAIL | N/A
Layer 2  Help text:       PASS | FAIL | N/A
Layer 3  Knowledge base:  PASS | FAIL | N/A
Layer 4  CC Allowlist:    PASS | FAIL | N/A
Layer 5  Agent guide:     PASS | FAIL | N/A
Layer 6  Svc registry:    PASS | FAIL | N/A  (or N/A — not a service)
Layer 7  Shell module:    PASS | FAIL | N/A  (or N/A — not a conf.d module)
Layer 8  Tests:           PASS | FAIL | N/A
Layer 9  Docs:            PASS | FAIL | N/A
Layer 10 Heal awareness:  PASS | FAIL | N/A

── FIXED ───────────────────────────────
- <what was healed automatically>

── OPERATOR NEEDED ─────────────────────
- <what requires manual action + zdots-issue ID>

── SKIPPED (N/A) ───────────────────────
- <layer: reason>
```

---

## Hard limits

- Never modify `lib/`, `conf.d/`, or `bin/` infrastructure scripts unless the
  new capability is your own code. File `zdots-issue` for gaps in existing tools.
- Never add untested allowlist rules to `.claude/settings.json`.
- Never regenerate `AGENTS.md` from scratch — patch only the affected section.
