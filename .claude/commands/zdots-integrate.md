---
name: zdots-integrate
description: Integration checklist for new zdots capabilities. Walks every registration point, wiring layer, and verification step so nothing is left half-connected.
---

# /zdots-integrate — New Capability Integration Checklist

Run after building any new `bin/` command, service, `lib/` module, or
`conf.d/` module. Work every layer in order. Mark each N/A with a one-line
reason; never silently skip.

**Invocation:**
```
/zdots-integrate <name> <type>
# type: command | service | lib | module
# Example: /zdots-integrate zdots-logs command
```

---

## Instructions for the model

Each layer shows the exact command to run, the pass condition, and the exact
fix if it fails. Run the command. Compare output to the pass condition. If it
fails, apply the fix. Then re-run to confirm. Do not guess — run it.

---

## Layer 1 — Executable / File

```bash
# L1-A: file exists
[[ -f bin/<name> ]] && echo PASS || echo FAIL

# L1-B: executable bit set (commands only; skip for lib/ and conf.d/)
[[ -x bin/<name> ]] && echo PASS || echo FAIL
# FIX: chmod +x bin/<name>

# L1-C: shellcheck clean at warning level
shellcheck --severity=warning bin/<name> && echo PASS || echo FAIL
# FIX: fix warnings in the file. File zdots-issue if in infrastructure code.
```

---

## Layer 2 — Help Text

```bash
# L2-A: --help exits 0
bin/<name> --help >/dev/null 2>&1 && echo PASS || echo FAIL

# L2-B: help text is non-empty (> 10 lines)
bin/<name> --help 2>/dev/null | wc -l | awk '{print ($1 > 10) ? "PASS" : "FAIL"}'
```

Standard embedded-help pattern (lines 2–N, `sed` extraction):
```bash
# bin/<name> — one-line description.
# Commands:  ...
# -h, --help  Show this help
```

---

## Layer 3 — Knowledge Base

```bash
# L3-A: rebuild catalog (always run when adding a new command)
zdots-index-tools --force 2>&1 | grep -E 'done|error'

# L3-B: catalog entry exists
zdots-ctx query "tooling:<name>" 2>/dev/null | grep -q '<name>' && echo PASS || echo FAIL
# FIX if FAIL: check that bin/<name> is executable and --help exits 0, then re-run L3-A
```

---

## Layer 4 — CC Allowlist

```bash
# L4-A: allowlist entry exists
grep -q '"Bash(<name>:\*)' .claude/settings.json && echo PASS || echo FAIL
# FIX: add "Bash(<name>:*)" to permissions.allow in .claude/settings.json
#      Place it alphabetically within the zdots group.
```

---

## Layer 5 — Agent Guide + Capabilities

Apply for any `bin/` command that agents or users invoke directly.
Skip for `lib/` modules.

```bash
# L5-A: agent-guide mentions the command
agent-guide 2>/dev/null | grep -q '<name>' && echo PASS || echo "MISSING (add to bin/agent-guide)"

# L5-B: AGENTS.md workflow table mentions it (only if it covers a primary workflow)
grep -q '<name>' AGENTS.md && echo PASS || echo "MISSING — add to tool table if primary workflow"
```

FIX: Edit `bin/agent-guide` to include the command in the relevant section.
Edit `AGENTS.md` tool table if it covers a workflow currently undocumented.
File `zdots-issue` if the guide/capabilities are infrastructure you didn't write.

---

## Layer 6 — Service Registry

Apply for new managed services only. Skip for commands, libs, and modules.

```bash
# L6-A: svc-registry entry exists
grep -q '"<name>"' lib/svc-registry.bash && echo PASS || echo FAIL

# L6-B: zsvc sees it
zsvc list 2>/dev/null | grep -q '<name>' && echo PASS || echo FAIL

# L6-C: zsvc health probe exits 0
zsvc health <name> >/dev/null 2>&1 && echo PASS || echo "FAIL — check health endpoint"
```

---

## Layer 7 — Shell Module (conf.d)

Apply for new `conf.d/` modules only. Skip for commands and services.

```bash
# L7-A: syntax check
zsh -n conf.d/<module> && echo PASS || echo FAIL

# L7-B: module loads without error
zsh -c "source conf.d/<module>" && echo PASS || echo FAIL

# L7-C: no duplicate load-order prefix
ls conf.d/ | grep -E '^[0-9]{2}-' | cut -d- -f1 | sort | uniq -d \
  | grep -q '' && echo "WARN: duplicate number prefix" || echo PASS
```

---

## Layer 8 — Tests

```bash
# L8-A: test file exists
ls tests/*<name>* 2>/dev/null | grep -q . && echo PASS || echo "MISSING — add tests/<name>.bats"

# L8-B: full suite green
bats tests/ && echo PASS || echo FAIL
# FIX: investigate failures; file zdots-issue for unrelated failures.
```

---

## Layer 9 — Documentation

```bash
# L9-A: man page exists (required for primary user-facing commands)
ls share/man/man1/<name>* 2>/dev/null | grep -q . && echo PASS \
  || echo "MISSING — add share/man/man1/<name>.1 if primary user-facing command"

# L9-B: system description doc mentions it
grep -q '<name>' docs/zdots-system-description.md && echo PASS \
  || echo "MISSING — add entry to docs/zdots-system-description.md"
```

---

## Layer 10 — Heal + Integrate Awareness

```bash
# L10-A: zdots-heal references this command if it's part of the health surface
grep -q '<name>' .claude/commands/zdots-heal.md && echo PRESENT || echo "NOT IN HEAL — add gate check if it's health-relevant"

# L10-B: zdots-integrate layer matrix still accurate (run this meta-check)
# Count layers in this file; count checks per layer; verify nothing drifted.
grep -c '^## Layer' .claude/commands/zdots-integrate.md
# Expected: 10. If different, the file has drifted.
```

---

## Reporting Format

```
=== zdots-integrate: <name> (<type>) — <timestamp> ===

Layer 1  Executable:      PASS | FAIL | N/A
Layer 2  Help text:       PASS | FAIL | N/A
Layer 3  Knowledge base:  PASS | FAIL | N/A
Layer 4  CC Allowlist:    PASS | FAIL | N/A
Layer 5  Agent guide:     PASS | FAIL | N/A
Layer 6  Svc registry:    PASS | FAIL | N/A
Layer 7  Shell module:    PASS | FAIL | N/A
Layer 8  Tests:           PASS | FAIL | N/A
Layer 9  Docs:            PASS | FAIL | N/A
Layer 10 Heal awareness:  PASS | FAIL | N/A

── FIXED ───────────────────────────────
- <command applied + what it fixed>

── OPERATOR NEEDED ─────────────────────
- <item> → zdots-issue filed: <ID>

── SKIPPED (N/A) ───────────────────────
- Layer N: <reason>
```

---

## Hard Limits

- Never edit `lib/`, `conf.d/`, or `bin/` infrastructure unless this is your code.
  File `zdots-issue` for gaps. Wait for operator.
- Never add allowlist rules you did not verify with L4-A first.
- Never amend commits; always create new ones.
