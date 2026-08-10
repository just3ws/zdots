---
name: zdots-log-triage
description: Scan zdots service logs for errors, identify stuck jobs, trace root causes through config and source, and produce a prioritized remediation summary. Use when user asks to "look at logs", "check errors", "what's failing", or reports unexplained zdots behaviour. Covers zdots-worker, zdots-update-local, llama-embed, llama-server, and gemstash logs.
---

# /zdots-log-triage — Log Scan + Root Cause

Systematically examine zdots service logs, categorize errors, identify stuck
jobs, trace causes to config or source, and report with remediation hints.
Read-only. File a `zdots-issue` for any config or source fix needed.

---

## Step 1 — Collect errors

```bash
LOG_DIR=~/.local/state/zsh

# Worker: job failures
grep -i "error\|fail\|warn\|fatal" $LOG_DIR/zdots-worker.log | tail -60

# Latest update run
tail -80 $LOG_DIR/zdots-update-local-latest.log

# Embed server
tail -30 $LOG_DIR/llama-embed.log

# Inference server  
tail -30 $LOG_DIR/llama-server.log

# gemstash — check size first; a crash-looped log can be gigabytes (see below)
ls -la $LOG_DIR/gemstash.log && tail -30 $LOG_DIR/gemstash.log
```

## Step 2 — Categorize

| Pattern in log | Category | Trace |
|----------------|----------|-------|
| `Connection refused.*11501` | embed-down | `zsvc status embed` |
| `exceed_context_size_error` | ctx-overflow | `etc/ai-models.yaml` → embed `ctx_size` |
| `OptionParser::InvalidOption` | cmd-output-leak | calling script passes command output as args |
| `phi_suppressed` | phi-block | content hit deny-list in `etc/phi-patterns.yaml` |
| `LocalityError.*not local` | ai-boundary | `ZDOTS_AI_ENDPOINT` points off-loopback |
| `migration.*failed` | db-schema | `zdots-ctx migrate` |
| `Queue.*overflow\|backed up` | worker-overload | `zsvc restart worker` |
| `NSCharacterSet initialize.*fork` | puma-fork-crash | service's `workers` config > 0 — see Step 4 |

## Step 3 — Identify stuck jobs

Stuck = same JOB UUID appears 3+ times in zdots-worker.log.

```bash
grep -oE 'JOB [a-f0-9]{8}' ~/.local/state/zsh/zdots-worker.log \
  | sort | uniq -c | sort -rn | awk '$1 >= 3'
# Output: count  JOB <uuid>
# For each stuck job:
grep "JOB <uuid>" ~/.local/state/zsh/zdots-worker.log | head -5
```

For each stuck job, extract the table and record UUID from the "Generating
embedding for <table>:<uuid>" line, then look up its content:

```bash
PGPASSWORD="$(security find-generic-password -s zdots -a ZDOTS_RO_PASSWORD -w)" \
  psql -U zdots_ro my -tAc \
  "SELECT id, slug, title FROM <table> WHERE id = '<record-uuid>';"
```

## Step 4 — Trace root causes

**ctx-overflow jobs:**
Check `etc/ai-models.yaml` embed profile `ctx_size` vs the model's native context.
Nomic v2 MoE supports 2048 tokens; shipping with `ctx_size: 512` will fail any
content > ~380 words. The `embed_server` `ubatch_size` does NOT substitute for `ctx_size`.

```bash
grep -A5 "^  embed:" ~/.config/zsh/etc/ai-models.yaml
grep -A8 "^embed_server:" ~/.config/zsh/etc/ai-models.yaml
```

**embed-down jobs:**
These are historical — check whether service is now healthy before acting.
```bash
zsvc status embed
```

**puma-fork-crash jobs (Z-296):**
A launchd-managed Ruby/Puma service can show `running`/`healthy` via its own
ctl status while its log grows explosively (gigabytes in minutes) — the
master process survives, but every worker fork crashes instantly against
macOS's ObjC fork-safety check and the master just retries in a tight loop.
Confirm with a repeat count on a *fresh* slice of the log (not the whole
gigabytes-large file):
```bash
tail -c 2M "$LOG_DIR/<service>.log" | grep -c 'NSCharacterSet initialize'
```
Fix at the config layer, not with an env-var workaround: the app's Puma
config almost certainly sets `workers` > 0 (even `workers: 1` triggers
Puma's clustered/fork mode — see `puma/launcher.rb`'s `clustered?`). Set
`workers: 0` (Puma single-process mode — no fork) wherever that service's
config is generated; see `bin/gemstash-ctl`'s `cmd_init` for the pattern.
Full writeup: `zdots-ctx query --semantic "puma fork crash macOS"`, Z-296.

**OptionParser crash:**
Find which script feeds command output directly to zdots-brain as arguments.
Look at the line before the crash in zdots-update-local log for the calling command.

## Step 5 — Report + issue

Present findings as:

```
=== zdots-log-triage — <timestamp> ===

STUCK JOBS (need action):
  JOB <uuid> — <N> retries — <slug> — <category> — <token count if known>

HISTORICAL (service was down, now healthy — no action):
  <count> connection-refused failures, embed service healthy since <date>

COSMETIC (non-blocking):
  <description>

REMEDIATION:
  [SELF-HEAL] <action Claude can take immediately>
  [OPERATOR]  <zdots-issue to file>
  [UPSTREAM]  <config/source change needed — file zdots-issue>
```

Offer to draft a `zdots-issue` for any OPERATOR or UPSTREAM item.
Do NOT edit `lib/`, `etc/`, or `bin/` — file the issue instead.
