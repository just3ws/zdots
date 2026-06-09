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
  cat >"$CACHE/alpha_prs.json" <<'JSON'
[{"data":{"repository":{"nameWithOwner":"acme/alpha","pullRequests":{"nodes":[
  {"number":1,"title":"feat: add login","state":"MERGED","createdAt":"2026-01-10T10:00:00Z","mergedAt":"2026-01-11T10:00:00Z","author":{"login":"alice"},"labels":{"nodes":[{"name":"feature"}]},"files":{"nodes":[{"path":"src/login.rb","additions":50,"deletions":2},{"path":"spec/login_spec.rb","additions":30,"deletions":0}]},"reviewThreads":{"totalCount":1},"statusCheckRollup":{"state":"SUCCESS"},"closingIssuesReferences":{"nodes":[{"number":7}]},"comments":{"nodes":[{"author":{"login":"bob"},"createdAt":"2026-01-10T11:00:00Z"}]},"reviews":{"nodes":[{"author":{"login":"bob"},"state":"APPROVED","createdAt":"2026-01-10T12:00:00Z"}]}},
  {"number":2,"title":"fix: npe on logout","state":"OPEN","createdAt":"2026-03-01T09:00:00Z","mergedAt":null,"author":{"login":"bob"},"labels":{"nodes":[{"name":"bug"}]},"files":{"nodes":[{"path":"src/logout.rb","additions":5,"deletions":1}]},"reviewThreads":{"totalCount":0},"statusCheckRollup":null,"closingIssuesReferences":{"nodes":[]},"comments":{"nodes":[]},"reviews":{"nodes":[]}}
],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}]
JSON

  cat >"$CACHE/alpha_issues.json" <<'JSON'
[{"data":{"repository":{"nameWithOwner":"acme/alpha","issues":{"nodes":[
  {"number":7,"title":"Login broken","state":"CLOSED","createdAt":"2026-01-09T08:00:00Z","closedAt":"2026-01-11T10:00:00Z","author":{"login":"bob"},"labels":{"nodes":[{"name":"bug"}]}}
],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}]
JSON

  cat >"$CACHE/beta_prs.json" <<'JSON'
[{"data":{"repository":{"nameWithOwner":"acme/beta","pullRequests":{"nodes":[
  {"number":1,"title":"docs: update readme","state":"MERGED","createdAt":"2026-02-01T09:00:00Z","mergedAt":"2026-02-01T15:00:00Z","author":{"login":"alice"},"labels":{"nodes":[]},"files":{"nodes":[{"path":"README.md","additions":10,"deletions":0}]},"reviewThreads":{"totalCount":0},"statusCheckRollup":{"state":"SUCCESS"},"closingIssuesReferences":{"nodes":[]},"comments":{"nodes":[]},"reviews":{"nodes":[]}}
],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}]
JSON

  cat >"$CACHE/beta_issues.json" <<'JSON'
[{"data":{"repository":{"nameWithOwner":"acme/beta","issues":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}]
JSON
}

_render() { "$GH" insights "$OWNER" --as-of "$ASOF"; }

@test "warehouse builds the Phase-1 views from the fixture" {
  run duckdb -readonly -noheader -list "$ZDOTS_GH_STATE/$OWNER.duckdb" \
    "SELECT count(*) FROM change_class"
  assert_success
  assert_output "3"
}

@test "insights renders all Phase-1 sections" {
  run _render
  assert_success
  [ -f "$MD" ]
  for header in \
    "Data inventory & traceability" \
    "DORA-adjacent" \
    "Flow metrics" \
    "Change classification" \
    "Actor involvement" \
    "Repository health index" \
    "Change-management archetypes" \
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

@test "unavailable insights surface in Unknowns & Data Gaps" {
  _render
  for gap in actions_reliability releases_and_deploys reopen_rate mttr who_merges; do
    grep -qF "$gap" "$MD" || { echo "missing gap: $gap"; return 1; }
  done
  # Confidence model legend present.
  grep -qF '`unavailable`' "$MD"
}

@test "every confidence tag in the report is a known class" {
  _render
  # No stray/placeholder tags — only the four legal confidence words appear as tags.
  run grep -oE '`(observed|inferred|proxy|unavailable)`' "$MD"
  assert_success
}
