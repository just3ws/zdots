#!/usr/bin/env ruby
# frozen_string_literal: true

# etc/zdots-gh/insights.rb — forensic delivery-process report for zdots-gh.
#
# Invoked by `bin/zdots-gh insights`. Reads the DuckDB warehouse (read-only) via
# the `duckdb -json` CLI (zero gems — no bundler, mirrors how report.py uses
# ephemeral deps), iterates the metric catalog (insights-catalog.yaml) for
# traceability + confidence, and emits:
#   • a Markdown report  → reports/<owner>.insights.md   (ingestable)
#   • graph edge-lists   → state/<owner>/graphs/*.json    (source-traceable)
#   • inline Mermaid blocks for the top coordination clusters.
#
# Determinism contract: output is a pure function of (warehouse, --as-of). No
# wall-clock time enters the report — the only time reference is the --as-of
# literal, stamped in the header. Two runs with the same --as-of are byte-equal.
#
# Usage:
#   insights.rb --owner O --db PATH --catalog PATH --md PATH --graphs-dir DIR [--as-of TS]
#
# Framing (AGENTS.md / Kevin's Law): GitHub is the fossil record of coordination.
# Every number carries its confidence tag; uncertainty is never erased.

require "json"
require "yaml"
require "open3"
require "optparse"
require "fileutils"
require "date"

# ── CLI ───────────────────────────────────────────────────────────────────────
opts = {}
OptionParser.new do |o|
  o.on("--owner OWNER")       { |v| opts[:owner] = v }
  o.on("--db PATH")           { |v| opts[:db] = v }
  o.on("--catalog PATH")      { |v| opts[:catalog] = v }
  o.on("--md PATH")           { |v| opts[:md] = v }
  o.on("--graphs-dir DIR")    { |v| opts[:graphs] = v }
  o.on("--as-of TS")          { |v| opts[:as_of] = v }
end.parse!(ARGV)

%i[owner db catalog md graphs].each do |k|
  abort "insights.rb: missing --#{k.to_s.tr('_', '-')}" unless opts[k]
end
abort "insights.rb: warehouse not found: #{opts[:db]}" unless File.exist?(opts[:db])

# Normalise --as-of (default: today 00:00 UTC) into a DuckDB TIMESTAMP literal.
raw_as_of = opts[:as_of] || "#{Date.today.iso8601}T00:00:00Z"
norm = raw_as_of.strip.sub(/Z\z/, "").tr("T", " ")
norm = "#{norm} 00:00:00" if norm =~ /\A\d{4}-\d{2}-\d{2}\z/
unless norm =~ /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/
  abort "insights.rb: bad --as-of #{raw_as_of.inspect} (want YYYY-MM-DD[THH:MM:SS[Z]])"
end
AS_OF = norm                       # e.g. "2026-06-09 00:00:00"
TS = "TIMESTAMP '#{AS_OF}'"        # interpolated into temporal SQL

# ── DuckDB access (read-only, JSON) ───────────────────────────────────────────
DB = opts[:db]

def duck(sql)
  out, err, st = Open3.capture3("duckdb", "-readonly", "-json", DB, sql)
  unless st.success?
    warn "insights.rb: query failed:\n#{sql}\n#{err}"
    return []
  end
  s = out.strip
  return [] if s.empty?
  JSON.parse(s)
rescue JSON::ParserError => e
  warn "insights.rb: bad JSON from duckdb (#{e.message}) for:\n#{sql}"
  []
end

# First scalar of the first row, or default.
def scalar(sql, default = nil)
  r = duck(sql).first
  return default if r.nil?
  v = r.values.first
  v.nil? ? default : v
end

def median_q(expr, where)
  scalar("SELECT median(#{expr}) v FROM #{where}")
end

def num(v, dp = 1)
  return "n/a" if v.nil?
  f = v.to_f
  dp.zero? ? f.round.to_s : format("%.#{dp}f", f)
end

def pct(part, whole)
  return "n/a" if whole.nil? || whole.to_f.zero?
  format("%.1f%%", part.to_f / whole.to_f * 100)
end

# Value + unit, but never "n/ah" — a missing value stays "n/a".
def unit(v, u, dp = 1)
  v.nil? ? "n/a" : "#{num(v, dp)}#{u}"
end

# ── Catalog (traceability + confidence) ───────────────────────────────────────
CATALOG = YAML.load_file(opts[:catalog]).fetch("insights")
BY_NAME = CATALOG.each_with_object({}) { |i, h| h[i["name"]] = i }

CONF_BADGE = {
  "observed" => "`observed`", "inferred" => "`inferred`",
  "proxy" => "`proxy`", "unavailable" => "`unavailable`"
}.freeze

# Confidence tag for a catalog entry, e.g. " `proxy`".
def tag(name)
  c = BY_NAME.dig(name, "confidence")
  c ? " #{CONF_BADGE[c]}" : ""
end

# ── Markdown helpers ──────────────────────────────────────────────────────────
def md_table(headers, rows)
  out = +"| #{headers.join(' | ')} |\n|#{(['---'] * headers.size).join('|')}|\n"
  if rows.empty?
    out << "| #{(['_none_'] * headers.size).join(' | ')} |\n"
  else
    rows.each { |r| out << "| #{r.join(' | ')} |\n" }
  end
  out << "\n" # trailing blank line so the next block isn't absorbed into the table
  out
end

def short(repo) = repo.to_s.split("/").last
def at(actor)   = "@#{actor}"
def trunc(s, n = 40) = s.to_s.length > n ? "#{s.to_s[0, n - 1]}…" : s.to_s

SECTIONS = +"" # accumulates the report body

def section(title)
  SECTIONS << "\n## #{title}\n\n"
end

def para(text)
  SECTIONS << "#{text}\n\n"
end

def emit(text)
  SECTIONS << text
  SECTIONS << "\n" unless text.end_with?("\n")
end

# ── Headline numbers ──────────────────────────────────────────────────────────
REPOS        = scalar("SELECT count(DISTINCT repo_name) v FROM prs", 0)
HUMAN_PRS    = scalar("SELECT count(*) v FROM prs WHERE NOT is_bot", 0)
MERGED       = scalar("SELECT count(*) v FROM prs WHERE state='MERGED' AND NOT is_bot", 0)
ISSUES       = scalar("SELECT count(*) v FROM issues", 0)
CONTRIBUTORS = scalar("SELECT count(DISTINCT author) v FROM prs WHERE NOT is_bot AND author IS NOT NULL", 0)

# ═══════════════════════════════════════════════════════════════════════════════
#  SECTION BUILDERS
# ═══════════════════════════════════════════════════════════════════════════════

# ── Data inventory (cat 1) ────────────────────────────────────────────────────
def build_inventory
  section "Data inventory & traceability"
  para "Every insight below is registered in `insights-catalog.yaml` with its " \
       "confidence class and the source view/table it derives from. This is the " \
       "audit map: what GitHub data is directly supported, inferred, a proxy, or " \
       "simply unavailable from the harvest."
  rows = CATALOG.sort_by { |i| [i["section"], i["name"]] }.map do |i|
    [i["name"], i["section"], CONF_BADGE[i["confidence"]],
     "`#{i['source_view'] || '—'}`",
     (i["required_data"] ? Array(i["required_data"]).join(", ") : (i["reason"] || "—"))]
  end
  emit md_table(%w[Insight Section Confidence Source Depends-on/Reason], rows)
end

# ── DORA-adjacent (cat 2) ─────────────────────────────────────────────────────
def build_dora
  section "DORA-adjacent — the delivery pulse"

  span_weeks = scalar(
    "SELECT greatest(1, date_diff('day', min(created_at), #{TS})/7.0) v " \
    "FROM prs WHERE NOT is_bot", 1
  )
  deploy_freq = MERGED.to_f / span_weeks.to_f

  lead   = median_q("total_lead_time_hours", "issue_lifecycle")
  cyc    = median_q("cycle_hours", "pr_cycle_time")
  cyc75  = scalar("SELECT quantile_cont(cycle_hours,0.75) v FROM pr_cycle_time")
  rev    = median_q("hours_to_first_review", "first_review_latency")
  ci_sig = scalar("SELECT sum(ci_signals) v FROM ci_failure_rate", 0)
  ci_fl  = scalar("SELECT sum(failures) v FROM ci_failure_rate", 0)
  leak   = scalar("SELECT count(*) v FROM process_leakage", 0)

  rows = [
    ["Deployment frequency", "#{num(deploy_freq)}/wk", "merged PRs/week#{tag('deployment_frequency')}"],
    ["Lead time for change", unit(lead, "h"), "issue→merge median#{tag('lead_time_for_change')}"],
    ["PR cycle time", "#{unit(cyc, 'h')} (p75 #{unit(cyc75, 'h')})", "open→merge#{tag('pr_cycle_time')}"],
    ["First-review latency", unit(rev, "h"), "open→1st review#{tag('first_review_latency')}"],
    ["CI failure rate", pct(ci_fl, ci_sig), "of #{ci_sig} rollup signals#{tag('ci_failure_rate')}"],
    ["Change-failure proxy", "#{pct(leak, MERGED)} (#{leak})", "merged w/ CI-fail or 0 review#{tag('change_failure_proxy')}"]
  ]
  emit md_table(%w[Metric Value Reading], rows)
  para "_Deploy lag and MTTR are#{tag('deploy_lead_lag')} — see Unknowns & Data Gaps._"
end

# ── Flow (cat 3) ──────────────────────────────────────────────────────────────
def build_flow
  section "Flow metrics — where work waits"

  open_pr   = "prs WHERE state='OPEN' AND NOT is_bot"
  pr_age_md = median_q("date_diff('hour', created_at, #{TS})", open_pr)
  pr_age_mx = scalar("SELECT max(date_diff('day', created_at, #{TS})) v FROM #{open_pr}")
  open_iss  = "issues WHERE state='OPEN'"
  iss_age_mx = scalar("SELECT max(date_diff('day', created_at, #{TS})) v FROM #{open_iss}")
  churn_md  = median_q("churn", "pr_flow WHERE NOT is_bot")
  files_md  = median_q("files_changed", "pr_flow WHERE NOT is_bot")
  hand_md   = median_q("handoffs", "pr_flow WHERE NOT is_bot")
  stale     = scalar(
    "SELECT count(*) v FROM pr_flow WHERE state='OPEN' AND NOT is_bot " \
    "AND reviewers=0 AND date_diff('day', created_at, #{TS}) > 30", 0
  )
  aband     = scalar("SELECT count(*) v FROM abandoned_prs", 0)

  rows = [
    ["Open PR age", "med #{unit(pr_age_md, 'h')} / max #{unit(pr_age_mx, 'd', 0)}", "open PRs vs ref date#{tag('pr_age')}"],
    ["Open issue age", "max #{unit(iss_age_mx, 'd', 0)}", "open issues vs ref date#{tag('issue_age')}"],
    ["Batch size", "med #{num(churn_md, 0)} lines / #{num(files_md, 0)} files", "churn / files#{tag('batch_size')}"],
    ["Handoffs per PR", "med #{num(hand_md, 0)}", "reviewers+commenters#{tag('handoffs')}"],
    ["Stale PRs", stale.to_s, "open >30d, unreviewed#{tag('stale_work')}"],
    ["Abandoned PRs", aband.to_s, "closed, never merged#{tag('abandoned_work')}"]
  ]
  emit md_table(%w[Signal Value Reading], rows)

  wip = duck("SELECT repo_name, open_prs, open_issues FROM wip_by_repo " \
             "WHERE open_prs>0 OR open_issues>0 ORDER BY open_prs+open_issues DESC, repo_name LIMIT 12")
  unless wip.empty?
    para "**Work-in-progress by repo**#{tag('wip_by_repo')}:"
    emit md_table(%w[Repo Open-PRs Open-issues],
                  wip.map { |r| [short(r["repo_name"]), r["open_prs"], r["open_issues"]] })
  end
end

# ── Change classification (cat 4) ─────────────────────────────────────────────
def build_classification
  section "Change classification"
  para "Each PR classified from labels → title → file mix (first match wins). The " \
       "`evidence` column records the raw inputs, so every call is auditable, not " \
       "asserted.#{tag('change_class')}"

  dist = duck("SELECT change_class, count(*) n FROM change_class GROUP BY 1 ORDER BY n DESC, change_class")
  emit md_table(%w[Class Count], dist.map { |r| [r["change_class"], r["n"]] })

  sample = duck("SELECT number, change_class, evidence FROM change_class ORDER BY number DESC, repo_name LIMIT 6")
  unless sample.empty?
    para "**Evidence sample** (most recent):"
    emit md_table(["PR", "Class", "Evidence"],
                  sample.map { |r| ["##{r['number']}", r["change_class"], "`#{r['evidence'].to_s[0, 90]}`"] })
  end

  bfc = duck("SELECT change_class, authors, prs FROM bus_factor_class ORDER BY prs DESC, change_class")
  para "**Bus factor by change class**#{tag('bus_factor_class')} — how many people can do each kind of work:"
  emit md_table(%w[Class Authors PRs], bfc.map { |r| [r["change_class"], r["authors"], r["prs"]] })

  bs = duck("SELECT branch_prefix, count(*) n FROM branch_signal GROUP BY 1 ORDER BY n DESC, branch_prefix")
  para "**Branch-name signal**#{tag('branch_name_signal')}: " +
       (bs.empty? ? "no human PRs." : bs.map { |r| "#{r['branch_prefix']}=#{r['n']}" }.join(", ") + ".")
end

# ── Actor / bus-factor (cat 5) ────────────────────────────────────────────────
def build_actors
  section "Actor involvement & load"
  act = duck("SELECT actor, prs_authored, reviews, approvals, comments, issues_opened, total_touches " \
             "FROM actor_activity ORDER BY total_touches DESC, actor LIMIT 15")
  para "Per-person involvement across roles (bots excluded).#{tag('actor_activity')}"
  emit md_table(%w[Actor PRs Reviews Approvals Comments Issues Touches],
                act.map { |r| [at(r["actor"]), r["prs_authored"], r["reviews"], r["approvals"],
                               r["comments"], r["issues_opened"], r["total_touches"]] })

  total_touch = act.sum { |r| r["total_touches"].to_i }
  if total_touch.positive? && !act.empty?
    top = act.first
    para "**Actor overload**#{tag('actor_overload')}: #{at(top['actor'])} carries " \
         "#{pct(top['total_touches'], total_touch)} of all recorded human activity."
  end

  rc = duck("SELECT repo_name, reviewers, hhi FROM reviewer_concentration ORDER BY hhi DESC, repo_name")
  if rc.empty?
    para "**Reviewer concentration**#{tag('reviewer_concentration')}: no recorded reviews — " \
         "no review culture is visible on GitHub for this estate."
  else
    emit md_table(["Repo", "Reviewers", "HHI (→1 = concentrated)"],
                  rc.map { |r| [short(r["repo_name"]), r["reviewers"], num(r["hhi"], 2)] })
  end

  mg = duck("SELECT actor, merges, repos FROM merge_gatekeepers WHERE NOT is_bot " \
            "ORDER BY merges DESC, actor LIMIT 8")
  if mg.empty?
    para "**Merge gatekeepers**#{tag('who_merges')}: no human-attributed merges recorded."
  else
    para "**Merge gatekeepers**#{tag('who_merges')} — who actually lands changes:"
    emit md_table(["Actor", "Merges", "Repos"],
                  mg.map { |r| [at(r["actor"]), r["merges"], r["repos"]] })
  end
end

# ── Repo health (cat 6) ───────────────────────────────────────────────────────
def build_repo_health
  section "Repository health index"
  # Idle uses the repo's real last-push (repo_meta) when present, else PR activity.
  rows = duck("SELECT repo_name, prs, merged, authors, reviewed_share, single_owner, no_ci, " \
              "language, archived, " \
              "date_diff('day', coalesce(pushed_at, last_activity), #{TS}) AS idle_days " \
              "FROM repo_health_meta ORDER BY prs DESC, repo_name")
  para "Active = pushed within 90d of the reference date.#{tag('repo_metadata')} " \
       "`single` = single-author bus-factor risk; `no-ci` = no status rollup seen; " \
       "`arch` = archived."
  emit md_table(%w[Repo Lang PRs Merged Authors Reviewed Idle State Flags],
                rows.map { |r|
                  flags = []
                  flags << "single" if r["single_owner"]
                  flags << "no-ci"  if r["no_ci"]
                  flags << "arch"   if r["archived"]
                  state = r["idle_days"].to_i > 90 ? "abandoned" : "active"
                  [short(r["repo_name"]), r["language"] || "—", r["prs"], r["merged"], r["authors"],
                   pct(r["reviewed_share"].to_f, 1.0), "#{r['idle_days']}d", state,
                   flags.empty? ? "—" : flags.join(",")]
                })

  bf = duck("SELECT repo_name, authors, top_author, top_author_share, bus_factor_risk " \
            "FROM bus_factor_repo ORDER BY authors ASC, top_author_share DESC, repo_name")
  para "**Bus factor by repo**#{tag('bus_factor_repo')} / **ownership**#{tag('ownership_map')}:"
  emit md_table(["Repo", "Authors", "Top author", "Share", "Risk"],
                bf.map { |r| [short(r["repo_name"]), r["authors"], at(r["top_author"]),
                              pct(r["top_author_share"].to_f, 1.0), r["bus_factor_risk"]] })
end

# ── Archetypes (cat 8) ────────────────────────────────────────────────────────
def build_archetypes
  section "Change-management archetypes"
  para "The observed process shape of each change, with evidence. Proxies are flagged.#{tag('change_archetype')}"
  dist = duck("SELECT archetype, count(*) n FROM change_archetype GROUP BY 1 ORDER BY n DESC, archetype")
  emit md_table(%w[Archetype Count], dist.map { |r| [r["archetype"], r["n"]] })
  sample = duck("SELECT number, archetype, evidence FROM change_archetype ORDER BY number DESC, repo_name LIMIT 5")
  unless sample.empty?
    para "**Evidence sample:**"
    emit md_table(["PR", "Archetype", "Evidence"],
                  sample.map { |r| ["##{r['number']}", r["archetype"], "`#{r['evidence']}`"] })
  end
end

# ── GitHub Actions reliability (cat 7) — Phase 2 ──────────────────────────────
def build_actions
  section "GitHub Actions reliability"
  by_repo = duck("SELECT repo_name, active_workflows, runs, failures, failure_rate " \
                 "FROM actions_by_repo ORDER BY runs DESC, repo_name")
  if by_repo.empty?
    para "_No GitHub Actions runs were harvested for this estate.#{tag('actions_reliability')}_"
    return
  end
  para "Most-recent runs per repo (harvest caps at 100/repo).#{tag('actions_reliability')}"
  emit md_table(["Repo", "Workflows", "Runs", "Failures", "Failure rate"],
                by_repo.map { |r| [short(r["repo_name"]), r["active_workflows"], r["runs"],
                                   r["failures"], pct(r["failure_rate"].to_f, 1.0)] })

  worst = duck("SELECT repo_name, workflow, runs, failure_rate, median_min " \
               "FROM workflow_reliability WHERE runs >= 3 " \
               "ORDER BY failure_rate DESC, runs DESC, workflow LIMIT 8")
  unless worst.empty?
    para "**Least-reliable workflows**#{tag('workflow_failure_detail')}:"
    emit md_table(["Repo", "Workflow", "Runs", "Fail rate", "Med min"],
                  worst.map { |r| [short(r["repo_name"]), trunc(r["workflow"]), r["runs"],
                                   pct(r["failure_rate"].to_f, 1.0), num(r["median_min"])] })
  end

  flaky = duck("SELECT workflow, failure_rate FROM flaky_workflows ORDER BY failure_rate DESC, workflow LIMIT 8")
  para "**Flaky workflows**#{tag('flaky_workflows')}: " +
       (flaky.empty? ? "none detected." :
        flaky.map { |r| "#{trunc(r['workflow'], 30)} (#{pct(r['failure_rate'].to_f, 1.0)})" }.join("; ") + ".")

  dep = duck("SELECT DISTINCT workflow FROM deploy_workflows ORDER BY workflow")
  para "**Deploy/release gates**#{tag('deploy_gates')} (name-inferred): " +
       (dep.empty? ? "none detected." :
        dep.map { |r| "`#{trunc(r['workflow'], 30)}`" }.join(", ") + ".")
end

# ── Releases / deploy signal (cat 2, 8) — Phase 2 ─────────────────────────────
def build_releases
  section "Releases & deploy signal"
  rel = duck("SELECT repo_name, releases, final_releases, last_release " \
             "FROM releases_by_repo WHERE releases > 0 ORDER BY releases DESC, repo_name")
  if rel.empty?
    para "_No GitHub Releases exist across the estate.#{tag('releases_and_deploys')} Shipping is " \
         "not cut as release artifacts here; deploy is inferred from Actions deploy gates instead. " \
         "Deploy lag and MTTR therefore remain #{CONF_BADGE['unavailable']} (see Unknowns & Data Gaps)._"
  else
    emit md_table(["Repo", "Releases", "Final", "Last release"],
                  rel.map { |r| [short(r["repo_name"]), r["releases"], r["final_releases"],
                                 r["last_release"].to_s[0, 10]] })
  end
end

# ── Issue triage & rework (cat 3, 5, 8) — Phase 2 ─────────────────────────────
def build_triage
  section "Issue triage & rework"
  ftr      = median_q("hours_to_first_response", "issue_triage WHERE hours_to_first_response IS NOT NULL")
  responded = scalar("SELECT count(*) v FROM issue_triage WHERE first_response IS NOT NULL", 0)
  total_iss = scalar("SELECT count(*) v FROM issue_triage", 0)
  reop      = scalar("SELECT coalesce(sum(reopened_issues),0) v FROM reopen_summary", 0)
  rows = [
    ["First-response latency", unit(ftr, "h"), "median issue→1st reply#{tag('triage_first_response')}"],
    ["Triage coverage", "#{responded}/#{total_iss}", "issues with any response#{tag('triage_first_response')}"],
    ["Reopened issues", reop.to_s, "rework signal#{tag('reopen_rate')}"]
  ]
  emit md_table(%w[Signal Value Reading], rows)

  asg = duck("SELECT actor, assigned, repos FROM issue_assignment ORDER BY assigned DESC, actor LIMIT 10")
  if asg.empty?
    para "**Assignment / ownership**#{tag('assignment_ownership')}: no issues are assigned."
  else
    para "**Assignment / ownership**#{tag('assignment_ownership')}:"
    emit md_table(["Actor", "Assigned issues", "Repos"],
                  asg.map { |r| [at(r["actor"]), r["assigned"], r["repos"]] })
  end
end

# ── Conway / socio-technical (cat 9) — graphs + Mermaid ───────────────────────
def mermaid_id(s) = s.to_s.gsub(/[^A-Za-z0-9]/, "_")

def write_graph(dir, name, rows)
  path = File.join(dir, "#{name}.json")
  File.write(path, JSON.pretty_generate(rows) + "\n")
  path
end

def build_conway(graphs_dir)
  section "Conway / socio-technical coordination"
  para "GitHub is the fossil record of coordination. The graphs below are exported " \
       "as source-traceable edge lists under `graphs/` and summarised here. Edges " \
       "reflect *observed behaviour*, not the org chart."

  # Export edge lists (deterministic ordering).
  actor_repo = duck("SELECT actor, repo_name, prs FROM edge_actor_repo ORDER BY actor, repo_name")
  review     = duck("SELECT reviewer, author, weight FROM edge_review_pair ORDER BY reviewer, author")
  comment    = duck("SELECT commenter, author, weight FROM edge_comment_pair ORDER BY commenter, author")
  cochange   = duck("SELECT repo_a, repo_b, shared_actors FROM edge_repo_cochange ORDER BY shared_actors DESC, repo_a, repo_b")
  spanners   = duck("SELECT actor, repos, prs, repo_list FROM boundary_spanners ORDER BY repos DESC, actor")
  ownership  = duck("SELECT repo_name, top_author, top_author_share, authors FROM ownership_map ORDER BY repo_name")

  exports = {
    "actor_repo" => actor_repo, "review_pair" => review, "comment_pair" => comment,
    "repo_cochange" => cochange, "boundary_spanners" => spanners, "ownership_map" => ownership
  }
  written = exports.map { |name, rows| [name, write_graph(graphs_dir, name, rows), rows.size] }
  para "**Exported graphs** (`#{File.basename(graphs_dir)}/`):"
  emit md_table(%w[Graph File Edges],
                written.map { |n, p, c| ["`#{n}`", "`#{File.basename(p)}`", c] })

  # Repo co-change Mermaid (architectural coupling proxy).
  para "**Repo coupling**#{tag('edge_repo_cochange')} (shared authors ⇒ coordination):"
  if cochange.empty?
    para "_No repo-to-repo coupling — human work is isolated to a single repository._"
  else
    mer = +"```mermaid\ngraph LR\n"
    cochange.first(20).each do |e|
      mer << "  #{mermaid_id(short(e['repo_a']))}[#{short(e['repo_a'])}]" \
             " ---|#{e['shared_actors']}| " \
             "#{mermaid_id(short(e['repo_b']))}[#{short(e['repo_b'])}]\n"
    end
    mer << "```\n"
    emit mer
  end

  # Boundary spanners.
  if spanners.empty?
    para "**Boundary spanners**#{tag('boundary_spanners')}: none — no contributor bridges ≥2 repos yet."
  else
    para "**Boundary spanners**#{tag('boundary_spanners')} — connective tissue across repos:"
    emit md_table(["Actor", "Repos", "PRs", "Spans"],
                  spanners.map { |r| [at(r["actor"]), r["repos"], r["prs"], r["repo_list"]] })
  end

  # Hidden teams = connected components over the co-change graph.
  build_hidden_teams(cochange, ownership)
end

def build_hidden_teams(cochange, ownership)
  all_repos = ownership.map { |r| r["repo_name"] }
  parent = {}
  find = ->(x) { x = parent[x] while parent[x] && parent[x] != x; x }
  all_repos.each { |r| parent[r] = r }
  cochange.each do |e|
    a = e["repo_a"]; b = e["repo_b"]
    parent[a] ||= a; parent[b] ||= b
    ra = find.call(a); rb = find.call(b)
    parent[ra] = rb if ra != rb
  end
  clusters = (all_repos + cochange.flat_map { |e| [e["repo_a"], e["repo_b"]] }).uniq
             .group_by { |r| find.call(r) }.values
  multi = clusters.select { |c| c.size > 1 }
  singles = clusters.count { |c| c.size == 1 }
  para "**Hidden teams**#{tag('hidden_teams')} (repos that move together): " +
       if multi.empty?
         "no multi-repo cluster detected; #{singles} repo(s) operate independently."
       else
         multi.map { |c| "{ #{c.map { |r| short(r) }.sort.join(', ')} }" }.join("; ") +
           " (#{singles} independent)."
       end
end

# ── Temporal (cat 10) ─────────────────────────────────────────────────────────
def build_temporal
  section "Temporal trend — now vs 1/2/3 calendar years ago"
  para "Buckets anchored to the reference date via the day-aware `yr_offset` macro. " \
       "Empty buckets render `n/a` (history may not reach that far back), never a " \
       "misleading zero.#{tag('temporal_volume')}"

  vol = duck(<<~SQL).each_with_object({}) { |r, h| h[r["yr"]] = r }
    SELECT yr_offset(created_at, #{TS}) AS yr,
           count(*) AS prs,
           count(DISTINCT author) AS actors,
           median(date_diff('hour', created_at, merged_at))
             FILTER (WHERE merged_at IS NOT NULL) AS cyc,
           count(*) FILTER (WHERE ci_state='FAILURE') AS ci_fail,
           count(*) FILTER (WHERE ci_state IS NOT NULL) AS ci_sig
    FROM prs WHERE NOT is_bot GROUP BY 1
  SQL

  revsh = duck(<<~SQL).each_with_object({}) { |r, h| h[r["yr"]] = r }
    SELECT yr_offset(p.created_at, #{TS}) AS yr,
           count(*) AS total,
           count(*) FILTER (WHERE r.pr_number IS NOT NULL) AS reviewed
    FROM prs p LEFT JOIN (SELECT DISTINCT repo_name, pr_number FROM pr_reviews) r
      ON p.repo_name=r.repo_name AND p.number=r.pr_number
    WHERE NOT p.is_bot GROUP BY 1
  SQL

  own = duck(<<~SQL).each_with_object({}) { |r, h| h[r["yr"]] = r }
    WITH a AS (SELECT yr_offset(created_at, #{TS}) AS yr, author, count(*) c
               FROM prs WHERE NOT is_bot AND author IS NOT NULL GROUP BY 1,2),
         t AS (SELECT yr, sum(c) tot FROM a GROUP BY 1)
    SELECT a.yr AS yr, round(max(a.c)::DOUBLE/max(t.tot),2) AS top_share
    FROM a JOIN t USING(yr) GROUP BY a.yr
  SQL

  labels = { 0 => "Now", 1 => "−1y", 2 => "−2y", 3 => "−3y" }
  cell = ->(b, key, fmt) {
    row = b[key]
    return "n/a" if row.nil? || row["prs"].to_i.zero?
    fmt.call(row)
  }
  metric_rows = [
    ["PR volume#{tag('temporal_volume')}",     ->(r) { r["prs"].to_s }],
    ["Contributors#{tag('temporal_actors')}",  ->(r) { r["actors"].to_s }],
    ["Median cycle (h)#{tag('temporal_cycle_time')}", ->(r) { r["cyc"] ? num(r["cyc"]) : "n/a" }],
    ["CI fail rate#{tag('temporal_ci_reliability')}", ->(r) { pct(r["ci_fail"], r["ci_sig"]) }]
  ]
  rows = metric_rows.map do |label, fmt|
    [label] + [0, 1, 2, 3].map { |k| cell.call(vol, k, fmt) }
  end
  # reviewed share + ownership use their own bucket maps
  rows << ["Reviewed share#{tag('temporal_review_culture')}"] +
          [0, 1, 2, 3].map { |k| r = revsh[k]; r ? pct(r["reviewed"], r["total"]) : "n/a" }
  rows << ["Ownership top-share#{tag('temporal_ownership')}"] +
          [0, 1, 2, 3].map { |k| r = own[k]; r ? pct(r["top_share"].to_f, 1.0) : "n/a" }

  emit md_table(["Metric", labels[0], labels[1], labels[2], labels[3]], rows)
end

# ── Decision support (cat 11) ─────────────────────────────────────────────────
def build_decision_support
  section "Decision support — where risk concentrates"
  bullets = []

  crit = duck("SELECT repo_name FROM bus_factor_repo WHERE bus_factor_risk LIKE 'critical%' ORDER BY repo_name")
  bullets << "**Knowledge risk:** #{crit.size} repo(s) are single-author " \
             "(#{crit.map { |r| short(r['repo_name']) }.join(', ')}) — a departure halts that line of work." unless crit.empty?

  noci = scalar("SELECT count(*) v FROM repo_health WHERE no_ci", 0)
  bullets << "**Automation gap:** #{noci} repo(s) show no CI signal — merges land without an observed gate." if noci.to_i.positive?

  noreview = scalar("SELECT count(*) v FROM repo_health WHERE reviewed_share=0 AND prs>0", 0)
  bullets << "**Review culture:** #{noreview} repo(s) merge with no recorded reviews — peer review is implicit or off-GitHub." if noreview.to_i.positive?

  leak = scalar("SELECT count(*) v FROM process_leakage", 0)
  bullets << "**Change risk:** #{pct(leak, MERGED)} of merges bypassed CI/review guardrails (proxy)." if leak.to_i.positive? && MERGED.to_i.positive?

  cochange = scalar("SELECT count(*) v FROM edge_repo_cochange", 0)
  bullets << "**Coordination:** no cross-repo coupling observed — the estate behaves as #{REPOS} independent unit(s)." if cochange.to_i.zero?

  worst_wf = duck("SELECT repo_name, workflow, failure_rate, runs FROM workflow_reliability " \
                  "WHERE runs >= 5 AND failure_rate >= 0.5 ORDER BY failure_rate DESC, runs DESC, workflow LIMIT 1").first
  if worst_wf
    bullets << "**CI/deploy risk:** `#{trunc(worst_wf['workflow'], 40)}` in #{short(worst_wf['repo_name'])} " \
               "fails #{pct(worst_wf['failure_rate'].to_f, 1.0)} of #{worst_wf['runs']} runs — a broken pipeline."
  end

  sole = duck("SELECT actor, merges FROM merge_gatekeepers WHERE NOT is_bot ORDER BY merges DESC, actor LIMIT 1").first
  total_merges = scalar("SELECT count(*) v FROM prs WHERE state='MERGED' AND merged_by IS NOT NULL", 0)
  if sole && total_merges.to_i.positive? && (sole["merges"].to_f / total_merges.to_i) >= 0.8
    bullets << "**Gatekeeping:** #{at(sole['actor'])} lands #{pct(sole['merges'], total_merges)} of all merges — a single integration point."
  end

  bullets << "_No elevated structural risks detected in the available signals._" if bullets.empty?
  bullets.each { |b| emit "- #{b}\n" }
end

# ── Unknowns & data gaps (cat 1) ──────────────────────────────────────────────
def build_gaps
  section "Unknowns & data gaps"
  para "What GitHub still cannot tell us, even after the Phase-2 harvest expansion " \
       "(Actions, releases, issue triage, repo metadata are now collected). These remain " \
       "`unavailable` — recorded, not erased. Most need deployment/incident data or " \
       "per-run actors that GitHub does not expose through the read-only API here."
  gaps = CATALOG.select { |i| i["confidence"] == "unavailable" }.sort_by { |i| i["name"] }
  emit md_table(%w[Missing-insight Purpose Why-unavailable],
                gaps.map { |i| [i["name"], i["purpose"], i["reason"]] })
end

# ── Confidence model (cat 13) ─────────────────────────────────────────────────
def build_confidence
  section "Confidence model"
  counts = CATALOG.group_by { |i| i["confidence"] }.transform_values(&:size)
  emit md_table(%w[Confidence Count Meaning], [
    ["`observed`", counts.fetch("observed", 0), "directly present in harvested GitHub data"],
    ["`inferred`", counts.fetch("inferred", 0), "defensible derivation; rules stated in the catalog"],
    ["`proxy`", counts.fetch("proxy", 0), "approximate stand-in for something GitHub does not record"],
    ["`unavailable`", counts.fetch("unavailable", 0), "cannot be known from the harvest at all"]
  ])
end

# ═══════════════════════════════════════════════════════════════════════════════
#  ASSEMBLE
# ═══════════════════════════════════════════════════════════════════════════════
FileUtils.mkdir_p(opts[:graphs])
FileUtils.mkdir_p(File.dirname(opts[:md]))

build_inventory
build_dora
build_actions
build_releases
build_flow
build_classification
build_actors
build_repo_health
build_archetypes
build_triage
build_conway(opts[:graphs])
build_temporal
build_decision_support
build_gaps
build_confidence

header = <<~MD
  ---
  title: "GitHub Delivery-Process Forensics — #{opts[:owner]}"
  source: zdots-gh
  owner: #{opts[:owner]}
  reference_date: #{AS_OF}
  report: insights
  tags: [github, dora, devex, flow, conway, change-management, #{opts[:owner]}]
  ---

  # GitHub Delivery-Process Forensics — `#{opts[:owner]}`

  Forensic inference of the **observed** engineering process from GitHub behaviour,
  by `zdots-gh insights`. Reference date (`--as-of`): **#{AS_OF}**. Deterministic:
  the same warehouse + reference date always yields this exact report.

  Scope: **#{REPOS}** repos · **#{HUMAN_PRS}** human PRs · **#{MERGED}** merged ·
  **#{ISSUES}** issues · **#{CONTRIBUTORS}** contributors.
  Every metric carries a confidence tag — `observed` / `inferred` / `proxy`. What
  GitHub cannot show sits in **Unknowns & Data Gaps**, not hidden.
MD

footer = <<~MD

  ---
  _Generated by `zdots-gh insights` — local-first, gh-only, forensic delivery-process
  inference. Re-run: `zdots-gh insights #{opts[:owner]} --as-of #{AS_OF.split(' ').first}`._
MD

File.write(opts[:md], header + SECTIONS + footer)
warn "insights.rb: wrote #{opts[:md]} (#{SECTIONS.length} chars) + graphs → #{opts[:graphs]}"
