---
name: my-ingest-principles
description: Feed contract markdown into the context-engine principle pipeline at my.local. Use when adding guidance/policy the context engine should resolve, when /api/v1/context/query returns insufficient_context for things you know are documented, or when the dashboard principle-rule count is low/zero.
---

# /my-ingest-principles — feed the context engine

The context engine resolves queries against **principle rules** extracted from
contract markdown in `~/my/context/intake/inbox/`. No inbox files → 0 rules →
every query returns `insufficient_context`. This skill adds them correctly.

## The contract

Frontmatter needs all 5 keys; body needs all 3 `##` sections (exact headings).
**Ingest is lenient** (`strict: false`) — a malformed file is parsed anyway and
silently yields garbage or zero rules, it does NOT fail loudly. That is why you
validate with `strict: true` *before* ingesting (step 1 below).

```markdown
---
title: Short Title
captured_at: 2026-06-19
source: where-this-came-from
scope: global          # required key; recorded for provenance.
status: active         #   principle rules do NOT use scope for precedence
---

## Principle Candidates
- Must <do X> ...          # judgment inferred from verb: must/never/should/may
- Should <prefer Y> ...

## Evidence
- Why each principle holds; links become citations

## Counterexamples
- What violating it looks like
```

Judgment is parsed from the leading verb: `must/always`→required, `should/prefer`→recommended,
`may/can`→allowed, `should not/avoid`→discouraged, `must not/never`→forbidden.

## Workflow

```bash
# 1. Validate format BEFORE ingest — MUST be strict:true or it catches nothing
#    (strict:false always returns valid, even for missing keys/sections)
C=$(cat ~/my/context/intake/inbox/FILE.md)
curl -sk -X POST https://my.local/api/v1/markdown/validate \
  -H "Content-Type: application/json" \
  -d "{\"markdown\": $(printf '%s' "$C" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))'), \"strict\": true}" \
  | python3 -m json.tool   # status:"valid", errors:[] → safe to ingest

# 2. Ingest (re-parses changed files, then runs PrincipleRuleExtractor)
cd ~/my/context-engine && RAILS_ENV=production bundle exec rails context:ingest_markdown_inbox
#   → scanned=N ingested=N skipped=N failed=N

# 3. Verify rules landed + query resolves
PGPASSWORD="$(security find-generic-password -s zdots -a ZDOTS_RO_PASSWORD -w)" \
  psql -U zdots_ro my -tAc "SELECT count(*), count(*) FILTER (WHERE triage_status='conflict') FROM markdown_principle_rules;"
curl -sk -X POST https://my.local/api/v1/context/query \
  -H "Content-Type: application/json" \
  -d '{"question":"<something your principles cover>","response_profile":"standard"}' | python3 -m json.tool
```

## Gotchas (learned the hard way)

- **`skipped=N` means unchanged** — ingest dedupes on file hash + mtime. To force
  re-ingest after a code (not file) change, clear rows as superuser:
  `psql -U mike.hall my -c "DELETE FROM markdown_inbox_chunks; DELETE FROM markdown_inbox_sources;"`
- **`failed=N`** — the rake loop swallows errors. Surface the real one with
  `rails runner` calling `MarkdownInboxIngestor.new.send(:ingest_file!, Pathname.new(path))`.
- A new column the parser/extractor expects but the DB lacks → file a `zdots-issue`
  for a migration in `db/migrations/` (don't patch the schema ad-hoc).
- App is **Sequel, not ActiveRecord** — service-layer edits follow Sequel idioms
  (see the `/my-deploy` notes and the sequel memory).

## Model / effort

**sonnet** at **medium** — needs judgment writing good principle statements, but
the mechanics are scripted.
