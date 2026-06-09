# zdots-gh — GitHub Delivery-Health & Process Forensics

## What it does

`zdots-gh <command> <owner>` harvests a GitHub organization or user's metadata
into a local DuckDB warehouse and renders two kinds of report for the zdots
knowledge base:

- **`report`** — a DORA/DevEx delivery-health summary (Markdown, plus an HTML
  dashboard with `--html`).
- **`insights`** — a *forensic* process-inference report that reconstructs the
  **observed** engineering process from GitHub behaviour, plus coordination-graph
  edge-lists.

It is local-first. The authenticated GitHub API (via `gh`) is the only network
egress; analysis runs in DuckDB and reports render with Ruby and Python. No
cloud LLM is involved. An `<owner>` is an org **or** a user login — `gh repo
list <owner>` covers both.

Guiding idea: **GitHub is the fossil record of coordination.** Derive the process
from repeated observed behaviour — never assume the documented process is the
real one.

```
zdots-gh run phalanxduel --html          # full loop + dashboard + insights
zdots-gh insights phalanxduel --as-of 2026-06-09   # reproducible snapshot
zdots-gh status                          # freshness for all harvested owners
```

See `man zdots-gh` for the full interface, or `zdots-gh --help`.

---

## Pipeline

`zdots-gh` preserves a four-stage pipeline; each stage is its own subcommand and
`run` chains them:

```
harvest → warehouse → report / insights → ingest
```

| Stage | What it does |
|---|---|
| `harvest`   | `gh` GraphQL (PRs/issues) + REST (Actions, releases, repo metadata) → per-repo JSON cache (incremental; `--force` to refresh) |
| `warehouse` | cache JSON → per-owner DuckDB (`etc/zdots-gh/warehouse.sql`) |
| `report`    | DuckDB → Markdown (+ HTML) via `etc/zdots-gh/report.py` |
| `insights`  | DuckDB → forensic Markdown + graph edge-lists via `etc/zdots-gh/insights.rb` |
| `ingest`    | the Markdown report(s) → `zdots-ctx ingest` (Knowledge Vault) |

### Knowledge-base landing contract

The goal of `ingest` is not just to write Markdown files; the generated analysis
must land in the `my` knowledge base and remain discoverable by later agents.

After `zdots-gh run <owner>` or `zdots-gh ingest <owner>`, verify:

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
zdots-ctx query --semantic "delivery process forensics <owner>"
```

Passing criteria:

- both `gh-delivery-health-<owner>` and `gh-forensics-<owner>` exist;
- `content_enc` is non-empty for both records;
- `has_embedding` is true for both records;
- there are no pending or dead `embed` jobs;
- text search finds the reports by title/content terms;
- semantic search returns both GitHub reports.

If an embed job fails with an embed-server context overflow, do not mark the
analysis landed. Fix or requeue the embed job, then verify retrieval again. See
`docs/wiki/AI-and-Knowledge-Layer.md` for the general agent discovery workflow.

### Outputs (under `$ZDOTS_GH_STATE`, default `$XDG_STATE_HOME/zdots/gh`)

| Path | Contents |
|---|---|
| `<owner>/*.json` | raw cache: PRs/issues (GraphQL) + Actions/releases/meta (REST, field-projected) |
| `<owner>/graphs/*.json` | coordination-graph edge-lists exported by `insights` |
| `<owner>.duckdb` | analytical warehouse |
| `reports/<owner>.md` | DORA/DevEx report |
| `reports/<owner>.insights.md` | forensic process-inference report |
| `reports/<owner>.html` | executive dashboard (`--html`) |

---

## What the insights report covers

One section per lens, each metric tagged with its confidence class:

- **DORA-adjacent** — lead time, PR cycle time, first-review latency, CI-failure
  and change-failure proxies, deployment-frequency proxy.
- **GitHub Actions reliability** — per-workflow failure rate and duration, flaky
  workflows, name-inferred deploy/release gates.
- **Releases & deploy signal** — release cadence per repo.
- **Flow** — open-item age, batch size, handoffs, stale/abandoned work, WIP.
- **Change classification** — each PR labelled (bug/feature/security/deps/docs/…)
  from labels → title → file mix, with the matched **evidence** recorded.
- **Actors & bus factor** — involvement across roles, reviewer concentration
  (HHI), merge gatekeepers, ownership map, bus factor by repo and change class.
- **Repository health** — language, default branch, archived flag, review
  culture, single-owner risk, idle/abandoned state.
- **Change-management archetypes** — issue-first, PR-first drive-by, review-heavy,
  CI-heavy, silent direct-to-main (proxy), abandoned request.
- **Issue triage & rework** — time-to-first-response, assignment, reopen rate.
- **Conway / socio-technical** — actor↔repo, reviewer↔author, repo co-change, and
  boundary-spanner graphs (JSON edge-lists + inline Mermaid), hidden-team
  clustering.
- **Temporal trend** — now vs 1/2/3 calendar years ago, anchored to `--as-of`.
- **Decision support** — where delivery risk concentrates, in prose.
- **Unknowns & data gaps** + **Confidence model** — what GitHub cannot show, and
  the tally by confidence class.

---

## Confidence model & traceability

Every insight is registered in `etc/zdots-gh/insights-catalog.yaml` with a
confidence class, the warehouse view it derives from, its method, and caveats.
The renderer iterates this catalog to build the Data Inventory, Confidence Model,
and Unknowns & Data Gaps sections — so prose stays in lockstep with the SQL.

| Class | Meaning |
|---|---|
| `observed` | directly present in the harvested data |
| `inferred` | a defensible derivation (rules stated in the catalog) |
| `proxy` | an approximate stand-in for something GitHub does not record |
| `unavailable` | cannot be known from the harvest (no view); recorded, not erased |

Every registered insight now has a source view — there are **no `unavailable`
metrics**. Where GitHub does not record something directly (production deploys,
incidents), the tool uses a clearly-labelled **proxy** rather than inventing
certainty: deploy lag (merge → deploy-gate run), MTTR (CI failure → next
success), change/CI-failure rate, deployment frequency, and queue-vs-active time.
Who-fixes-CI and who-owns-release are `inferred` from run actors and deploy-gate
operators. Read proxies as approximations, not ground truth.

### Determinism

Given a fixed `--as-of` reference date, the insights report and graph exports are
a pure function of the cache: re-running produces byte-identical output. `--as-of`
also anchors open-item age and the temporal year buckets.

---

## Environment

| Variable | Effect |
|---|---|
| `ZDOTS_GH_STATE` | cache/warehouse/report root (default `$XDG_STATE_HOME/zdots/gh`) |
| `ZDOTS_GH_REPO_LIMIT` | max repos to enumerate (default 100) |
| `ZDOTS_GH_PR_PAGE` / `ZDOTS_GH_ISSUE_PAGE` | page sizes (default 25 / 50) |
| `ZDOTS_GH_INCLUDE_FORKS` | `1` = include forks (default 0) |
| `ZDOTS_GH_INCLUDE_ARCHIVED` | `1` = include archived repos (default 0) |

Requires `gh` (authenticated), `duckdb`, `ruby`, and `jq`; the HTML report also
uses `uv`. `cc-doctor` and `zdots-doctor` both verify this toolchain.

---

## Implementation

| File | Role |
|---|---|
| `bin/zdots-gh` | CLI / pipeline orchestration |
| `etc/zdots-gh/warehouse.sql` | DuckDB schema + analytical views (the derivation engine) |
| `etc/zdots-gh/insights-catalog.yaml` | metric registry (confidence + traceability) |
| `etc/zdots-gh/insights.rb` | forensic report + graph renderer (zero-gem Ruby) |
| `etc/zdots-gh/report.py` | DORA/DevEx Markdown + HTML renderer |
| `tests/zdots_gh_insights.bats` | hermetic fixture-driven tests |

Tests run hermetically off a committed fixture (no network) and self-skip when
`duckdb`/`ruby` are absent.
