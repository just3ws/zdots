---
name: zdots-heal
description: Self-evaluation and self-healing skill for the zdots platform. Runs every health check, diagnoses failures, and remediates what it can — then reports what needs operator attention. "Machine, heal thyself."
---

# /zdots-heal — Machine, Heal Thyself

Run every zdots health check in sequence. For each failure, attempt
remediation. Surface what you fixed and what the operator must resolve.

This skill is the Omnissiah's touch on the control plane.

---

## Protocol

Work through the **five gates** in order. Never skip a gate because a later
one seems more important. The gates are ordered by blast radius — a broken
PATH is more foundational than a broken knowledge-base embedding job.

---

## Gate 1 — Foundation

```bash
capabilities --json        # environment contract
capabilities               # human view (confirm no RED lines)
```

**Check:** no `health_errors > 0`. Every service contract has a provider file.
Critical paths exist. Knowledge DB is online.

**Heal:**
- Missing provider file → file `zdots-issue --type request` and note in report
- Knowledge DB offline → `zsvc start ctx` or check `zdots-ctx status`
- MCP missing → check `.mcp.json`; run `zdots-ctx status`

---

## Gate 2 — Container Runtime

```bash
colima-status --json
```

**Check:** `.healthy == true`, `.socket_exists == true`, `.docker_reachable == true`.

**Heal:**
- `healthy: false` → `zsvc start colima` then re-probe
- `socket_exists: false` after start → wait 15s, probe again; if still missing
  run `colima stop && colima start` once; log it
- Guard warning on legacy path → note in report; do NOT patch bin/ scripts
  yourself — file `zdots-issue` citing the script name

```bash
# Pattern for scripts needing DOCKER_HOST:
export DOCKER_HOST="unix://$(colima-status socket)"
```

---

## Gate 3 — Services

```bash
zsvc list
zdots-ctl status --json
```

**Check every managed service** (llama, embed, otel, o2, colima, nginx, postgres, redis, worker).
For each service not in `running` state:

**Heal (safe — idempotent):**
```bash
zsvc start <svc>
```

Wait 5s, re-probe with `zsvc status <svc>`. If still down, run:
```bash
zsvc diag <svc>      # last 50 log lines + launchd state
```

Record diagnosis. Do NOT restart more than once per service per heal run.

---

## Gate 4 — Platform deep check

```bash
zdots-ctl check
zdots-doctor
```

**Check:** no FAIL lines. Every hard check (FileVault, SIP, AI mode, capture,
llama bind, model provenance) must pass on a work machine. On home machine,
FileVault/SIP failures are noted but not blocking.

**Heal:**
- Failed phase in `zdots-doctor` → read its output carefully; only act if the
  fix is a single idempotent command (e.g. `zdots-ctx migrate`). Anything
  requiring config edits or destructive operations → operator note only.
- `ZDOTS_AI_MODE=cloud` on a work machine → STOP. Do not proceed. File
  `zdots-issue --high "AI mode is cloud on a PHI-adjacent machine"`.

---

## Gate 5 — Knowledge base

```bash
zdots-ctx status
zdots-ctx query tooling:catalog | head -5   # spot-check index freshness
```

**Check:** connected, pending_jobs < 50 (a large backlog means embedding
worker is behind or stuck).

**Heal:**
- Not connected → `zsvc start worker` then `zdots-ctx status`
- pending_jobs high → `zsvc restart worker`
- Index stale (tooling-catalog older than 7 days or missing) →
  `zdots-index-tools --force`

---

## Gate 6 — Skill Audit

Audit every installed skill in `.claude/commands/` for correctness, coverage,
and staleness against the current platform state.

```bash
ls .claude/commands/
```

**For each skill file, check:**

1. **Correctness** — do the commands it references still exist?
   ```bash
   # For each command cited: grep bin/ for it
   zdots-ctx query tooling:catalog | grep <name>
   ```

2. **Integration coverage** — does each `bin/` command have:
   - A CC allowlist entry in `.claude/settings.json`?
   - An entry in `agent-guide` or `capabilities` if user-facing?
   - A knowledge-base entry (`zdots-ctx query tooling:<name>`)?
   ```bash
   grep -c 'Bash(' .claude/settings.json
   zdots-ctx query tooling:catalog | wc -l
   ```

3. **Skill self-consistency** — for the zdots skills specifically:
   - `/zdots-heal` (this skill): does it reference all current services?
     Compare Gate 3 service list against `zsvc list`.
   - `/zdots-integrate`: does its layer matrix match the current registration
     points (new layers added to platform but not reflected in the checklist)?
   - `/command-qc`: does it cover the current set of QC checkpoints?

4. **Orphaned references** — skills that mention removed commands or services:
   ```bash
   # Quick scan: extract all command names from skills, check bin/
   grep -h 'zsvc\|zdots-\|colima-status\|capabilities\|agent-guide' \
     .claude/commands/*.md | grep -oE '[a-z][a-z0-9-]+' | sort -u \
     | while read -r cmd; do
         command -v "$cmd" >/dev/null 2>&1 || printf 'MISSING: %s\n' "$cmd"
       done
   ```

**Heal:**
- Command referenced in skill no longer exists → update skill to use current
  equivalent; file `zdots-issue` if the removal was unintended
- New service/command not reflected in `/zdots-heal` gates → update this file
- New registration layer not in `/zdots-integrate` → update that skill
- Allowlist entry missing for an active `bin/` command → add it to
  `.claude/settings.json` permissions.allow

---

## Reporting format

After all gates, produce a structured report:

```
=== zdots-heal report — <timestamp> ===

GATE 1 Foundation:    PASS | FAIL | PARTIAL
GATE 2 Colima:        PASS | FAIL | PARTIAL
GATE 3 Services:      PASS | FAIL | PARTIAL (list downs)
GATE 4 Deep check:    PASS | FAIL | PARTIAL
GATE 5 Knowledge:     PASS | FAIL | PARTIAL
GATE 6 Skills:        PASS | FAIL | PARTIAL

── HEALED (automated) ──────────────────────
- <what was fixed>

── NEEDS OPERATOR ──────────────────────────
- <what you could not fix, with zdots-issue filed if applicable>

── DEFERRED ────────────────────────────────
- <non-blocking findings for next review>
```

File a `zdots-issue` for every item in NEEDS OPERATOR:
```bash
zdots-issue "zdots-heal: <short description>"
zdots-issue --high "zdots-heal: <blocking issue>"
```

---

## What you must never do during a heal run

- Modify files in `lib/`, `conf.d/`, or `bin/` (except your own task files)
- Run more than one destructive restart per service
- Change `ZDOTS_AI_MODE` under any circumstances
- Run `colima delete`, `docker system prune`, or any volume/image destruction
- Assume a healed service is healthy without re-probing

When in doubt about a remediation, file the issue and mark it NEEDS OPERATOR.
The skill's value is in reliable diagnosis and safe fixes, not heroic attempts.
