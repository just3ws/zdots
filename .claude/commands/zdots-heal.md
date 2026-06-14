---
name: zdots-heal
description: Self-evaluation and self-healing skill for the zdots platform. Runs every health check, diagnoses failures, and remediates what it can — then reports what needs operator attention. "Machine, heal thyself."
---

# /zdots-heal — Machine, Heal Thyself

Run every zdots health check in sequence. For each failure, apply the listed
fix. Re-probe after every fix before moving on. Report what you changed and
what the operator must handle.

**Rules:**
- Work gates in order. Never skip a gate because a later one seems more urgent.
- One fix attempt per item per run. If it fails twice, mark NEEDS OPERATOR.
- If in doubt: file `zdots-issue`. Do not improvise.

---

## Gate 1 — Foundation

```bash
capabilities --json 2>/dev/null | python3 -m json.tool | grep health_errors
# PASS: "health_errors": 0
# FAIL: any non-zero value or parse error
```

```bash
# Confirm no RED lines in human view
capabilities 2>/dev/null | grep -i 'fail\|error\|red' | grep -v '#'
# PASS: no output
# FAIL: lines printed → read each; apply fix below
```

**Fix table:**

| Symptom | Fix |
|---------|-----|
| `health_errors > 0` | `zdots-ctx status --json` → see Gate 5 |
| `zdots-ctx` not connected | `zsvc start worker` |
| MCP tool missing | `zdots-ctx status --json` → check `mcp_servers` field |
| Provider missing | `zdots-issue --type request "provider missing: <name>"` |

---

## Gate 2 — Container Runtime

```bash
colima-status --json 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
for k in ('running','healthy','socket_exists','docker_reachable'):
    print(k, 'PASS' if d.get(k) else 'FAIL')
"
```

**Fix table:**

| Field = false | Fix | Re-probe |
|---------------|-----|----------|
| `running` | `zsvc start colima` | wait 15s, re-run gate |
| `socket_exists` (after start) | `colima stop && colima start` (once only) | wait 15s, re-run gate |
| `docker_reachable` | `DOCKER_HOST=$(colima-status socket) docker info` | fix DOCKER_HOST env |
| Guard message on stderr | note in DEFERRED; file `zdots-issue "colima-status: legacy path guard fired in <script>"` | N/A |

---

## Gate 3 — Services

```bash
zdots-ctl status --json 2>/dev/null | python3 -c "
import sys,json
for svc in json.load(sys.stdin).get('services',[]):
    print(svc['name'], svc.get('state','unknown'))
"
# PASS: every service prints 'running'
# FAIL: any service not 'running'
```

**For each non-running service:**

```bash
zsvc start <svc>
sleep 5
zsvc status <svc>
# PASS: state = running
# FAIL after one start attempt:
zsvc diag <svc>   # captures last 50 log lines + launchd state
# → paste diagnosis into NEEDS OPERATOR; file zdots-issue --high
```

Managed services: `llama embed otel o2 nginx postgres redis worker`
(colima is handled in Gate 2)

Do NOT start any service more than once per heal run.

---

## Gate 4 — Platform Deep Check

```bash
zdots-ctl check 2>&1 | grep -E 'FAIL|ERROR|CRITICAL' | grep -v '^#'
# PASS: no output
# FAIL: lines printed

zdots-doctor 2>&1 | grep -E '\[FAIL\]|\[ERROR\]'
# PASS: no output
# FAIL: lines printed
```

**Safe fixes (idempotent, apply directly):**

| Pattern in output | Fix |
|-------------------|-----|
| `schema.*migration` | `zdots-ctx migrate` |
| `index.*stale` | `zdots-index-tools --force` |

**Stop and file `zdots-issue` for:**

| Pattern | Action |
|---------|--------|
| `ZDOTS_AI_MODE=cloud` on work machine | `zdots-issue --high "AI mode is cloud on PHI machine"` then STOP |
| `FileVault.*disabled` | note in report (blocking on work; non-blocking on home) |
| Any config edit required | `zdots-issue "zdots-heal: <description>"` |
| Any destructive operation required | `zdots-issue "zdots-heal: <description>"` |

---

## Gate 5 — Knowledge Base

```bash
zdots-ctx status --json 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
connected = d.get('connected') or d.get('db_connected')
pending   = int(d.get('pending_jobs', 0))
print('connected', 'PASS' if connected else 'FAIL')
print('pending_jobs', 'PASS' if pending < 50 else f'FAIL ({pending} jobs)')
"

# Spot-check catalog freshness
zdots-ctx query tooling:catalog 2>/dev/null | grep -c 'tooling:' | \
  awk '{print ($1 > 0) ? "PASS (catalog present)" : "FAIL (catalog empty)"}'
```

**Fix table:**

| Symptom | Fix |
|---------|-----|
| not connected | `zsvc start worker && sleep 5 && zdots-ctx status` |
| pending_jobs ≥ 50 | `zsvc restart worker` |
| catalog empty | `zdots-index-tools --force` |

---

## Gate 6 — Skill Audit

```bash
# Scan all skills for command references that no longer exist in bin/.
# Anchor on the zdots command shapes (zsvc, colima-status, capabilities,
# agent-guide, cc-doctor, zdots-*) so the scan extracts real invocations,
# not arbitrary prose words. The surrounding [^/[:alnum:].-] guards reject
# path/filename embeddings (audit/zdots-audit-foo.md, /tmp/zdots-update-run.log)
# so only standalone command tokens match. Skip tokens that are themselves
# skills (.claude/commands/*.md) — those are /slash commands, not bin/ orphans.
grep -hoE '(^|[^/[:alnum:].-])(zsvc|colima-status|capabilities|agent-guide|cc-doctor|zdots-[a-z0-9-]+)([^./[:alnum:]-]|$)' \
  .claude/commands/*.md \
  | grep -oE '(zsvc|colima-status|capabilities|agent-guide|cc-doctor|zdots-[a-z0-9-]+)' \
  | sort -u \
  | while read -r cmd; do
      command -v "$cmd" >/dev/null 2>&1 && continue
      [ -f ".claude/commands/${cmd}.md" ] && continue
      printf 'MISSING: %s\n' "$cmd"
    done
# PASS: no output
# FAIL: each MISSING line is an orphaned reference
```

```bash
# Check: every bin/ command has a CC allowlist entry
for cmd in bin/*; do
  name="${cmd##*/}"
  grep -q "\"Bash(${name}:" .claude/settings.json || printf 'NO-ALLOWLIST: %s\n' "$name"
done
# PASS: no output (or only expected internal scripts)
# Expected missing (internal, not invoked by agents): cc-hook-*, secret-scan, zdots-ruby-bump
```

```bash
# Check: Gate 3 service list in this file matches zsvc
zdots_services=$(zsvc list 2>/dev/null | awk 'NR>1 {print $1}' | sort)
heal_services=$(grep 'Managed services' .claude/commands/zdots-heal.md | grep -oE '[a-z]+' | sort)
diff <(echo "$zdots_services") <(echo "$heal_services") && echo "PASS" || echo "DIFF above — update Gate 3 service list"
```

**Fix table:**

| Symptom | Fix |
|---------|-----|
| Orphaned command reference in skill | update the skill to use current command |
| New `bin/` command missing from allowlist | add `"Bash(<name>:*)"` to `.claude/settings.json` |
| Gate 3 service list drift | update the list in Gate 3 of this file |
| zdots-issue for removed command | `zdots-issue "command removed: <name> — update skills"` |

---

## Reporting Format

```
=== zdots-heal report — <timestamp> ===

GATE 1 Foundation:    PASS | FAIL | PARTIAL
GATE 2 Colima:        PASS | FAIL | PARTIAL
GATE 3 Services:      PASS | FAIL | PARTIAL (list non-running: ...)
GATE 4 Deep check:    PASS | FAIL | PARTIAL
GATE 5 Knowledge:     PASS | FAIL | PARTIAL
GATE 6 Skills:        PASS | FAIL | PARTIAL

── HEALED (automated) ──────────────────────
- <command run> → <what changed>

── NEEDS OPERATOR ──────────────────────────
- <description> → zdots-issue filed: <ID>

── DEFERRED ────────────────────────────────
- <non-blocking finding>
```

File a `zdots-issue` for every NEEDS OPERATOR item:
```bash
zdots-issue "zdots-heal: <short description>"
zdots-issue --high "zdots-heal: <blocking>"
```

---

## What you must never do during a heal run

- Modify `lib/`, `conf.d/`, or `bin/` (except your own task files)
- Restart any service more than once
- Change `ZDOTS_AI_MODE` under any circumstances
- Run `colima delete`, `docker system prune`, or any volume/image destruction
- Assume a healed item is healthy without re-probing
