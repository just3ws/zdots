---
name: github-kb-analysis
description: Run zdots-gh against a GitHub org/user, analyze delivery health and cross-repo issue coordination, then prove the reports landed in the My knowledge base. Use when the user asks to analyze a GitHub owner, inspect GitHub Issues coordination across repos, or validate zdots-gh knowledge-base ingestion.
---

# GitHub KB Analysis

Use `zdots-gh` to harvest GitHub metadata, render delivery-health and forensic
reports, ingest them into the My knowledge base, and prove later agents can find
the results.

## Quick Start

For a moderate exploratory org, bound the first run:

```bash
export ZDOTS_GH_REPO_LIMIT=25
GH_TOKEN=$(gh auth token) zdots-gh run <owner> --html
```

Use a fixed reference date when comparing runs:

```bash
zdots-gh insights <owner> --as-of YYYY-MM-DD
zdots-gh ingest <owner>
```

## Preflight

```bash
gh auth status
GH_TOKEN=$(gh auth token) gh auth status >/dev/null
zdots-gh status
zsvc status embed
zsvc status worker
rtk psql -d my -c "select status, count(*) from jobs where type='embed' group by status;"
```

If `gh` is not authenticated, stop and ask the operator. `zdots-gh` currently
uses a redirected `gh auth status` precheck; exporting `GH_TOKEN=$(gh auth
token)` makes that precheck deterministic in agent shells.

If the embed or worker service is down, start only the named service or file a
`zdots-issue` if service behavior contradicts docs.

## Run

```bash
export ZDOTS_GH_REPO_LIMIT=<N>
GH_TOKEN=$(gh auth token) zdots-gh run <owner> --html
```

`ZDOTS_GH_REPO_LIMIT` limits repository count, not PR/issue pagination depth
within each repository. For validation, choose a smaller owner first. Large
history repos can spend minutes on the first repo even with a low repo limit.

For Issues-heavy coordination analysis, inspect the forensic report and graphs:

```bash
grep -n "Issue triage & rework" "$ZDOTS_GH_STATE/reports/<owner>.insights.md"
grep -n "Cross-repo issue coordinators" "$ZDOTS_GH_STATE/reports/<owner>.insights.md"
ls "$ZDOTS_GH_STATE/<owner>/graphs"
```

Important graph files:

- `issue_actor_coordination.json`: issue authors, assignees, and responders spanning repos.
- `issue_closure_coordination.json`: issue-to-PR closure links, cross-repo flagged when known.
- `repo_cochange.json`: repos connected by shared PR authors.
- `boundary_spanners.json`: actors authoring across repos.

## Landing Proof

Do not claim success when `zdots-gh run` exits 0. Prove all layers:

```bash
rtk psql -d my -c \
  "select slug, title, tags, embedding is not null as has_embedding,
          octet_length(content_enc) as encrypted_bytes
     from methodologies
    where slug in ('gh-delivery-health-<owner>', 'gh-forensics-<owner>');"

rtk psql -d my -c \
  "select status, count(*) from jobs where type='embed' group by status;"

zdots-ctx query "GitHub Delivery Health"
zdots-ctx query "forensics"
zdots-ctx query --semantic "issue coordination cross repo <owner>"
```

Passing criteria:

- both `gh-delivery-health-<owner>` and `gh-forensics-<owner>` exist;
- `encrypted_bytes` is non-zero for both;
- `has_embedding` is true for both;
- no `embed` jobs are pending or dead;
- text search finds report terms;
- semantic search returns both GitHub reports.

## Failure Handling

- Embed context overflow: fix the embed path or requeue after the fix, then rerun landing proof.
- Rate limits: lower `ZDOTS_GH_REPO_LIMIT`, wait, or resume from cache.
- Missing issue coordination: check whether repos use GitHub Issues; absence is a finding, not a tool failure.
- Unexpected zdots tool behavior: file `zdots-issue` and stop.

## Validation Record

See [VALIDATION.md](VALIDATION.md) for the real-org validation run and findings.
