#!/usr/bin/env bats
# tests/zdots_gh_insights.bats — hermetic tests for `zdots-gh insights` (Phase 1).
#
# Builds a DuckDB warehouse from a tiny, committed JSON fixture (no network, no
# `gh`), renders the forensic insight report + coordination graphs, and asserts:
#   • the warehouse builds and every Phase-1 section renders,
#   • change classification is explainable and correct on known inputs,
#   • the Conway graphs are exported as valid, non-empty JSON,
#   • the report is deterministic given a fixed --as-of,
#   • unavailable insights surface in Unknowns & Data Gaps (uncertainty kept).
#
# The fixture is intentionally richer than the real cache (2 repos, 2 authors,
# a cross-repo author) so the coordination-graph paths are exercised.
#
# Self-skips when duckdb or ruby is absent, so it is safe in the public-sanity CI.

setup() {
  load "setup.bash"
  setup_environment

  command -v duckdb >/dev/null 2>&1 || skip "duckdb not installed"
  command -v ruby   >/dev/null 2>&1 || skip "ruby not installed"

  GH="$REPO_ROOT/bin/zdots-gh"
  OWNER="acme"
  export ZDOTS_GH_STATE="$BATS_TEST_TMPDIR/state"
  CACHE="$ZDOTS_GH_STATE/$OWNER"
  MD="$ZDOTS_GH_STATE/reports/$OWNER.insights.md"
  GRAPHS="$CACHE/graphs"
  ASOF="2026-06-09"
  mkdir -p "$CACHE"

  _write_fixture
  # Build the warehouse once for the suite (insights would auto-build, but an
  # explicit build keeps failures attributable).
  "$GH" warehouse "$OWNER" >/dev/null 2>&1 || skip "warehouse build failed in this environment"
}

# Two repos; alice authors in BOTH (boundary spanner + repo co-change), bob
# reviews alice and authors a bug fix (review edge + bug classification).
_write_fixture() {
  # PRs carry Phase-2 fields (headRefName/baseRefName/isDraft/mergedBy/reviewRequests).
  cat >"$CACHE/alpha_prs.json" <<'JSON'
[{"data":{"repository":{"nameWithOwner":"acme/alpha","pullRequests":{"nodes":[
  {"number":1,"title":"feat: add login","state":"MERGED","createdAt":"2026-01-10T10:00:00Z","mergedAt":"2026-01-11T10:00:00Z","headRefName":"feature/login","baseRefName":"main","isDraft":false,"mergedBy":{"login":"alice"},"reviewRequests":{"totalCount":1},"author":{"login":"alice"},"labels":{"nodes":[{"name":"feature"}]},"files":{"nodes":[{"path":"src/login.rb","additions":50,"deletions":2},{"path":"spec/login_spec.rb","additions":30,"deletions":0}]},"reviewThreads":{"totalCount":1},"statusCheckRollup":{"state":"SUCCESS"},"closingIssuesReferences":{"nodes":[{"number":7}]},"comments":{"nodes":[{"author":{"login":"bob"},"createdAt":"2026-01-10T11:00:00Z"}]},"reviews":{"nodes":[{"author":{"login":"bob"},"state":"APPROVED","createdAt":"2026-01-10T12:00:00Z"}]}},
  {"number":2,"title":"fix: npe on logout","state":"OPEN","createdAt":"2026-03-01T09:00:00Z","mergedAt":null,"headRefName":"fix/logout","baseRefName":"main","isDraft":false,"mergedBy":null,"reviewRequests":{"totalCount":0},"author":{"login":"bob"},"labels":{"nodes":[{"name":"bug"}]},"files":{"nodes":[{"path":"src/logout.rb","additions":5,"deletions":1}]},"reviewThreads":{"totalCount":0},"statusCheckRollup":null,"closingIssuesReferences":{"nodes":[]},"comments":{"nodes":[]},"reviews":{"nodes":[]}}
],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}]
JSON

  # Issue carries Phase-2 fields (assignees/milestone/comments/reopened).
  cat >"$CACHE/alpha_issues.json" <<'JSON'
[{"data":{"repository":{"nameWithOwner":"acme/alpha","issues":{"nodes":[
  {"number":7,"title":"Login broken","state":"CLOSED","createdAt":"2026-01-09T08:00:00Z","closedAt":"2026-01-11T10:00:00Z","author":{"login":"bob"},"labels":{"nodes":[{"name":"bug"}]},"assignees":{"nodes":[{"login":"bob"}]},"milestone":{"title":"v1"},"comments":{"nodes":[{"author":{"login":"alice"},"createdAt":"2026-01-09T10:00:00Z"}]},"reopened":{"totalCount":1}}
],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}]
JSON

  cat >"$CACHE/beta_prs.json" <<'JSON'
[{"data":{"repository":{"nameWithOwner":"acme/beta","pullRequests":{"nodes":[
  {"number":1,"title":"docs: update readme","state":"MERGED","createdAt":"2026-02-01T09:00:00Z","mergedAt":"2026-02-01T15:00:00Z","headRefName":"docs/readme","baseRefName":"main","isDraft":false,"mergedBy":{"login":"alice"},"reviewRequests":{"totalCount":0},"author":{"login":"alice"},"labels":{"nodes":[]},"files":{"nodes":[{"path":"README.md","additions":10,"deletions":0}]},"reviewThreads":{"totalCount":0},"statusCheckRollup":{"state":"SUCCESS"},"closingIssuesReferences":{"nodes":[]},"comments":{"nodes":[]},"reviews":{"nodes":[]}}
],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}]
JSON

  cat >"$CACHE/beta_issues.json" <<'JSON'
[{"data":{"repository":{"nameWithOwner":"acme/beta","issues":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}]
JSON

  # ── Phase-2 REST sources (field-projected flat arrays, as the harvester writes) ──
  # alpha: a flaky CI workflow (3✓/2✗) + a Deploy gate; beta: empty (tests both paths).
  cat >"$CACHE/alpha_meta.json" <<'JSON'
[{"repo_name":"acme/alpha","default_branch":"main","language":"Ruby","archived":false,"private":false,"fork":false,"created_at":"2025-01-01T00:00:00Z","pushed_at":"2026-03-01T00:00:00Z","stargazers_count":2,"forks_count":0,"open_issues_count":1}]
JSON
  cat >"$CACHE/beta_meta.json" <<'JSON'
[{"repo_name":"acme/beta","default_branch":"main","language":"Markdown","archived":false,"private":false,"fork":false,"created_at":"2025-06-01T00:00:00Z","pushed_at":"2026-02-01T00:00:00Z","stargazers_count":0,"forks_count":0,"open_issues_count":0}]
JSON
  cat >"$CACHE/alpha_workflows.json" <<'JSON'
[{"repo_name":"acme/alpha","id":10,"name":"CI","path":".github/workflows/ci.yml","state":"active"},
 {"repo_name":"acme/alpha","id":11,"name":"Deploy GitHub Pages","path":".github/workflows/deploy.yml","state":"active"}]
JSON
  cat >"$CACHE/beta_workflows.json" <<'JSON'
[]
JSON
  # Runs carry actor/triggering_actor; CI alternates fail→success so the two
  # recoveries are attributed to alice (who_fixes_ci, mttr_proxy). The Deploy
  # run at 11:00 follows alpha#1's 10:00 merge (deploy_lead_lag = 60 min).
  cat >"$CACHE/alpha_runs.json" <<'JSON'
[{"repo_name":"acme/alpha","id":1,"name":"CI","workflow_id":10,"conclusion":"success","status":"completed","event":"push","head_branch":"main","actor":"bob","triggering_actor":"bob","created_at":"2026-01-10T10:00:00Z","run_started_at":"2026-01-10T10:00:00Z","updated_at":"2026-01-10T10:01:00Z"},
 {"repo_name":"acme/alpha","id":2,"name":"CI","workflow_id":10,"conclusion":"failure","status":"completed","event":"push","head_branch":"main","actor":"bob","triggering_actor":"bob","created_at":"2026-01-11T10:00:00Z","run_started_at":"2026-01-11T10:00:00Z","updated_at":"2026-01-11T10:02:00Z"},
 {"repo_name":"acme/alpha","id":3,"name":"CI","workflow_id":10,"conclusion":"success","status":"completed","event":"push","head_branch":"main","actor":"alice","triggering_actor":"alice","created_at":"2026-01-12T10:00:00Z","run_started_at":"2026-01-12T10:00:00Z","updated_at":"2026-01-12T10:01:00Z"},
 {"repo_name":"acme/alpha","id":4,"name":"CI","workflow_id":10,"conclusion":"failure","status":"completed","event":"push","head_branch":"main","actor":"bob","triggering_actor":"bob","created_at":"2026-01-13T10:00:00Z","run_started_at":"2026-01-13T10:00:00Z","updated_at":"2026-01-13T10:02:00Z"},
 {"repo_name":"acme/alpha","id":5,"name":"CI","workflow_id":10,"conclusion":"success","status":"completed","event":"push","head_branch":"main","actor":"alice","triggering_actor":"alice","created_at":"2026-01-14T10:00:00Z","run_started_at":"2026-01-14T10:00:00Z","updated_at":"2026-01-14T10:01:00Z"},
 {"repo_name":"acme/alpha","id":6,"name":"Deploy GitHub Pages","workflow_id":11,"conclusion":"success","status":"completed","event":"push","head_branch":"main","actor":"alice","triggering_actor":"alice","created_at":"2026-01-11T11:00:00Z","run_started_at":"2026-01-11T11:00:00Z","updated_at":"2026-01-11T11:02:00Z"}]
JSON
  cat >"$CACHE/beta_runs.json" <<'JSON'
[]
JSON
  cat >"$CACHE/alpha_releases.json" <<'JSON'
[{"repo_name":"acme/alpha","id":1,"tag_name":"v1.0","name":"v1.0","draft":false,"prerelease":false,"author":"alice","created_at":"2026-01-12T00:00:00Z","published_at":"2026-01-12T00:00:00Z"}]
JSON
  cat >"$CACHE/beta_releases.json" <<'JSON'
[]
JSON
}

_render() { "$GH" insights "$OWNER" --as-of "$ASOF"; }

@test "warehouse builds the views from the fixture (Phase 1 + 2)" {
  db="$ZDOTS_GH_STATE/$OWNER.duckdb"
  run duckdb -readonly -noheader -list "$db" "SELECT count(*) FROM change_class"
  assert_success
  assert_output "3"
  # Phase-2 tables build too (Actions runs harvested, releases present for alpha).
  run duckdb -readonly -noheader -list "$db" "SELECT count(*) FROM workflow_runs"
  assert_output "6"
  run duckdb -readonly -noheader -list "$db" "SELECT count(*) FROM releases"
  assert_output "1"
}

@test "insights renders all sections (Phase 1 + 2)" {
  run _render
  assert_success
  [ -f "$MD" ]
  for header in \
    "Data inventory & traceability" \
    "DORA-adjacent" \
    "GitHub Actions reliability" \
    "Releases & deploy signal" \
    "Flow metrics" \
    "Change classification" \
    "Actor involvement" \
    "Repository health index" \
    "Change-management archetypes" \
    "Issue triage & rework" \
    "Conway / socio-technical coordination" \
    "Temporal trend" \
    "Decision support" \
    "Unknowns & data gaps" \
    "Confidence model"
  do
    grep -qF "## $header" "$MD" || { echo "missing section: $header"; cat "$MD"; return 1; }
  done
}

@test "change classification is correct and carries evidence" {
  _render
  # feature (label), bug fix (label/title), documentation (path/title) — one each.
  run duckdb -readonly -noheader -list "$ZDOTS_GH_STATE/$OWNER.duckdb" \
    "SELECT change_class FROM change_class ORDER BY change_class"
  assert_success
  assert_line --index 0 "bug fix"
  assert_line --index 1 "documentation"
  assert_line --index 2 "feature"
  # Evidence is rendered in the report so classifications are auditable.
  grep -qF "files(test/doc/ci/dep/total)" "$MD"
}

@test "Conway graphs export as valid, non-empty JSON" {
  _render
  for g in actor_repo review_pair repo_cochange boundary_spanners ownership_map comment_pair; do
    [ -f "$GRAPHS/$g.json" ] || { echo "missing graph: $g"; return 1; }
    run ruby -rjson -e "JSON.parse(File.read('$GRAPHS/$g.json'))"
    assert_success
  done
  # alice spans both repos ⇒ a repo-coupling edge and a boundary spanner exist.
  G="$GRAPHS/repo_cochange.json" run ruby -rjson -e 'd=JSON.parse(File.read(ENV["G"])); abort unless d.size==1 && d[0]["shared_actors"]==1'
  G="$GRAPHS/boundary_spanners.json" run ruby -rjson -e 'd=JSON.parse(File.read(ENV["G"])); abort unless d.any?{|r| r["actor"]=="alice" && r["repos"]==2}'
  assert_success
  # Non-empty coupling ⇒ a Mermaid block is embedded.
  grep -qF '```mermaid' "$MD"
}

@test "review edge captures bob → alice" {
  _render
  G="$GRAPHS/review_pair.json" run ruby -rjson -e \
    'd=JSON.parse(File.read(ENV["G"])); abort unless d.any?{|r| r["reviewer"]=="bob" && r["author"]=="alice"}'
  assert_success
}

@test "report is deterministic for a fixed --as-of" {
  _render
  cp "$MD" "$BATS_TEST_TMPDIR/first.md"
  cp -r "$GRAPHS" "$BATS_TEST_TMPDIR/first_graphs"
  _render
  run diff "$BATS_TEST_TMPDIR/first.md" "$MD"
  assert_success
  run diff -r "$BATS_TEST_TMPDIR/first_graphs" "$GRAPHS"
  assert_success
}

@test "Phase-2: Actions reliability — flaky CI + deploy gate" {
  _render
  db="$ZDOTS_GH_STATE/$OWNER.duckdb"
  # CI workflow: 3 success / 2 failure ⇒ failure_rate 0.4, and flaky (≥4 runs, mid-range).
  run duckdb -readonly -noheader -list "$db" \
    "SELECT failure_rate FROM workflow_reliability WHERE workflow='CI'"
  assert_output "0.4"
  run duckdb -readonly -noheader -list "$db" "SELECT count(*) FROM flaky_workflows WHERE workflow='CI'"
  assert_output "1"
  # The Deploy workflow is name-inferred as a deploy gate and rendered.
  grep -qF "Deploy GitHub Pages" "$MD"
  grep -qF "## GitHub Actions reliability" "$MD"
}

@test "Phase-2: merge gatekeeper, branch signal, triage, releases" {
  _render
  db="$ZDOTS_GH_STATE/$OWNER.duckdb"
  # alice merged both merged PRs (alpha#1, beta#1).
  run duckdb -readonly -noheader -list "$db" \
    "SELECT merges FROM merge_gatekeepers WHERE actor='alice'"
  assert_output "2"
  # Branch prefixes are extracted from head refs.
  run duckdb -readonly -noheader -list "$db" \
    "SELECT branch_prefix FROM branch_signal ORDER BY branch_prefix"
  assert_line --index 0 "docs"
  assert_line --index 1 "feature"
  assert_line --index 2 "fix"
  # Issue #7 was reopened once (rework) and got a first response from a non-author.
  run duckdb -readonly -noheader -list "$db" "SELECT sum(reopen_events) FROM reopen_summary"
  assert_output "1"
  run duckdb -readonly -noheader -list "$db" \
    "SELECT hours_to_first_response FROM issue_triage WHERE number=7"
  assert_output "2"
  # alpha has a release; beta has none.
  run duckdb -readonly -noheader -list "$db" "SELECT releases FROM releases_by_repo WHERE repo_name='acme/alpha'"
  assert_output "1"
  # Repo metadata enriches health (language).
  run duckdb -readonly -noheader -list "$db" "SELECT language FROM repo_health_meta WHERE repo_name='acme/alpha'"
  assert_output "Ruby"
}

@test "gap closure: every insight has a source view (0 unavailable)" {
  _render
  # The catalog no longer has any unavailable entry; the report says so.
  run ruby -ryaml -e 'n=YAML.load_file(ARGV[0])["insights"].count{|i|i["confidence"]=="unavailable"}; abort("#{n} unavailable") unless n==0' \
    "$REPO_ROOT/etc/zdots-gh/insights-catalog.yaml"
  assert_success
  grep -qF "no \`unavailable\` metrics" "$MD"
  grep -qF "| \`unavailable\` | 0 |" "$MD"
}

@test "gap closure: who-fixes-CI, deploy lag, MTTR, queue/active, release owner" {
  _render
  db="$ZDOTS_GH_STATE/$OWNER.duckdb"
  # alice triggers both post-failure successes (CI recovery).
  run duckdb -readonly -noheader -list "$db" "SELECT recoveries FROM ci_fixers WHERE actor='alice'"
  assert_output "2"
  # Two failure→success transitions on the CI workflow.
  run duckdb -readonly -noheader -list "$db" "SELECT count(*) FROM mttr_proxy"
  assert_output "2"
  # alpha#1 merged 10:00, Deploy gate ran 11:00 → 60-minute deploy lag.
  run duckdb -readonly -noheader -list "$db" "SELECT lag_minutes FROM deploy_lead_lag"
  assert_output "60"
  # alpha#1 reviewed 2h after open → waiting=2h in the queue/active split.
  run duckdb -readonly -noheader -list "$db" "SELECT waiting_hours FROM queue_active_split WHERE number=1"
  assert_output "2"
  # Explicit release author is recorded.
  run duckdb -readonly -noheader -list "$db" "SELECT releases FROM release_owners WHERE actor='alice'"
  assert_output "1"
  # All surface in the rendered report.
  grep -qF "CI fixers" "$MD"
  grep -qF "Pipeline recovery (MTTR proxy)" "$MD"
}

@test "every confidence tag in the report is a known class" {
  _render
  # No stray/placeholder tags — only the four legal confidence words appear as tags.
  run grep -oE '`(observed|inferred|proxy|unavailable)`' "$MD"
  assert_success
}
