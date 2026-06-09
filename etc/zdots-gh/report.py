#!/usr/bin/env python3
"""etc/zdots-gh/report.py — render a zdots-gh DuckDB warehouse into reports.

Invoked by `bin/zdots-gh report` via `uv run --with duckdb`. Emits a Markdown
report (the artifact `zdots-ctx ingest` feeds into the knowledge base) and,
optionally, a rich HTML dashboard.

Usage:
  report.py --owner O --db PATH --asset-dir DIR --md PATH [--html PATH]
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone

import duckdb


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner", required=True)
    ap.add_argument("--db", required=True)
    ap.add_argument("--asset-dir", required=True)
    ap.add_argument("--md", required=True)
    ap.add_argument("--html")
    args = ap.parse_args()

    conn = duckdb.connect(args.db, read_only=True)

    def val(q, default=0):
        try:
            r = conn.execute(q).fetchone()
            return r[0] if r and r[0] is not None else default
        except Exception:
            return default

    def rows(q):
        try:
            return conn.execute(q).fetchall()
        except Exception:
            return []

    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    # ── Headline metrics ──────────────────────────────────────────────────────
    total_repos = val("SELECT count(DISTINCT repo_name) FROM prs")
    total_prs = val("SELECT count(*) FROM prs WHERE NOT is_bot")
    total_merged = val("SELECT count(*) FROM prs WHERE state='MERGED' AND NOT is_bot")
    total_issues = val("SELECT count(*) FROM issues")
    contributors = val("SELECT count(DISTINCT author) FROM prs WHERE NOT is_bot AND author IS NOT NULL")

    avg_resonance = round(val("SELECT avg(resonance_ratio) FROM test_resonance"), 2)
    median_lead = round(val("SELECT quantile_cont(total_lead_time_hours, 0.5) FROM issue_lifecycle"), 1)
    median_spec = round(val("SELECT quantile_cont(spec_to_code_hours, 0.5) FROM issue_lifecycle"), 1)
    median_merge = round(val("SELECT quantile_cont(code_to_merge_hours, 0.5) FROM issue_lifecycle"), 1)
    median_first_review = round(val("SELECT quantile_cont(hours_to_first_review,0.5) FROM first_review_latency"), 1)

    leakage_count = val("SELECT count(*) FROM process_leakage")
    leakage_pct = round((leakage_count / total_merged * 100) if total_merged else 0, 1)

    # DORA deployment-frequency proxy: merged PRs/week over the observed window.
    span_weeks = val(
        "SELECT greatest(1, date_diff('day', min(created_at), now())/7.0) "
        "FROM prs WHERE NOT is_bot"
    )
    deploy_freq = round((total_merged / span_weeks) if span_weeks else 0, 1)

    # ── Tables ────────────────────────────────────────────────────────────────
    mobility = rows("SELECT author, repo_count, total_prs FROM developer_mobility LIMIT 10")
    linger = rows("SELECT title, days_open, author, repo_name FROM issue_linger LIMIT 8")
    shadows = rows("SELECT actor, social_touches, authored_prs FROM shadow_stakeholders LIMIT 8")
    leaks = rows(
        "SELECT repo_name, number, author, ci_state, review_count "
        "FROM process_leakage ORDER BY repo_name, number LIMIT 12"
    )
    hottest = rows(
        "SELECT repo_name, count(*) prs, "
        "round(avg(thread_count),1) avg_threads "
        "FROM prs WHERE NOT is_bot GROUP BY repo_name ORDER BY prs DESC LIMIT 10"
    )

    # ── Markdown (the ingest artifact) ────────────────────────────────────────
    md = render_markdown(
        owner=args.owner, now=now,
        total_repos=total_repos, total_prs=total_prs, total_merged=total_merged,
        total_issues=total_issues, contributors=contributors,
        deploy_freq=deploy_freq, median_lead=median_lead, median_spec=median_spec,
        median_merge=median_merge, median_first_review=median_first_review,
        avg_resonance=avg_resonance, leakage_pct=leakage_pct, leakage_count=leakage_count,
        mobility=mobility, linger=linger, shadows=shadows, leaks=leaks, hottest=hottest,
    )
    with open(args.md, "w") as f:
        f.write(md)

    # ── HTML dashboard (optional) ─────────────────────────────────────────────
    if args.html:
        render_html(conn, args, owner=args.owner, now=now, val=val, rows=rows,
                    total_repos=total_repos, median_lead=median_lead,
                    avg_resonance=avg_resonance, leakage_pct=leakage_pct,
                    median_spec=median_spec, median_merge=median_merge,
                    linger=linger, mobility=mobility)
    return 0


def _md_table(headers, body_rows, fmt):
    out = ["| " + " | ".join(headers) + " |",
           "|" + "|".join("---" for _ in headers) + "|"]
    if not body_rows:
        out.append("| " + " | ".join("_none_" for _ in headers) + " |")
    for r in body_rows:
        out.append("| " + " | ".join(fmt(r)) + " |")
    return "\n".join(out)


def render_markdown(**k) -> str:
    owner = k["owner"]
    mobility_tbl = _md_table(
        ["Contributor", "Repos bridged", "PRs"],
        k["mobility"],
        lambda r: [f"@{r[0]}", str(r[1]), str(r[2])],
    )
    linger_tbl = _md_table(
        ["Issue", "Days open", "Author", "Repo"],
        k["linger"],
        lambda r: [str(r[0])[:60], f"{r[1]}d", f"@{r[2]}", r[3].split('/')[-1]],
    )
    shadow_tbl = _md_table(
        ["Actor", "Reviews+comments", "PRs authored"],
        k["shadows"],
        lambda r: [f"@{r[0]}", str(r[1]), str(r[2])],
    )
    leak_tbl = _md_table(
        ["Repo", "PR", "Author", "CI", "Reviews"],
        k["leaks"],
        lambda r: [r[0].split('/')[-1], f"#{r[1]}", f"@{r[2]}", str(r[3] or "—"), str(r[4])],
    )
    hot_tbl = _md_table(
        ["Repo", "PRs", "Avg review threads"],
        k["hottest"],
        lambda r: [r[0].split('/')[-1], str(r[1]), str(r[2])],
    )

    return f"""---
title: "GitHub Delivery Health — {owner}"
source: zdots-gh
owner: {owner}
generated: {k['now']}
tags: [github, dora, devex, delivery-health, {owner}]
---

# GitHub Delivery Health — `{owner}`

DORA + DevEx insight report generated by `zdots-gh` on {k['now']}.
Scope: **{k['total_repos']}** repos · **{k['total_prs']}** PRs · **{k['total_merged']}** merged ·
**{k['total_issues']}** issues · **{k['contributors']}** contributors.

## DORA — the delivery pulse

| Metric | Value | Proxy |
|---|---|---|
| Deployment frequency | **{k['deploy_freq']}/wk** | merged PRs per week |
| Lead time for changes | **{k['median_lead']}h** | median issue-open → PR-merge |
| Change failure rate | **{k['leakage_pct']}%** | merged PRs with CI failure or zero review ({k['leakage_count']}) |

## DevEx — the flow state

| Signal | Value | Reading |
|---|---|---|
| Test resonance | **{k['avg_resonance']}** | test churn ÷ logic churn; >1.0 healthy |
| Feedback-loop friction | **{k['median_first_review']}h** | median PR-open → first review |
| Spec-to-code latency | **{k['median_spec']}h** | median issue-open → first linked PR |
| Code-to-merge latency | **{k['median_merge']}h** | median first PR → merge |

## Knowledge map (bus factor & glue)

People bridging the most repositories — the connective tissue whose departure
concentrates risk.

{mobility_tbl}

## Shadow stakeholders

High social engagement (reviews/comments) with little or no authored code — the
hidden SMEs, PMs, and QA voices defining value from the shadows.

{shadow_tbl}

## Process leakage (change-failure detail)

Merged PRs that bypassed the guardrails (CI failure or zero reviews).

{leak_tbl}

## Backlog decay (longest-lingering open issues)

Open issues with no linked PR — stalled intent draining attention without code.

{linger_tbl}

## Activity hotspots

{hot_tbl}

---
*Generated by `zdots-gh` — local-first GitHub delivery-health insights.
Re-run with `zdots-gh run {owner}` to refresh.*
"""


def render_html(conn, args, *, owner, now, val, rows, total_repos, median_lead,
                avg_resonance, leakage_pct, median_spec, median_merge,
                linger, mobility):
    with open(f"{args.asset_dir}/report.html") as f:
        html = f.read()

    funnel = {
        "labels": ["Spec → Code", "Code → Merge", "Total Lead Time"],
        "values": [median_spec, median_merge, median_lead],
    }

    yoy = rows(
        "SELECT month(created_at) m, "
        "count(*) FILTER (WHERE year(created_at)=year(now())) cur, "
        "count(*) FILTER (WHERE year(created_at)=year(now())-1) prev "
        "FROM prs WHERE NOT is_bot GROUP BY 1 ORDER BY 1"
    )
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    cur_year = datetime.now().year
    yoy_data = {
        "categories": months,
        "series": [
            {"name": f"{cur_year}", "data": [next((r[1] for r in yoy if r[0] == m), 0) for m in range(1, 13)]},
            {"name": f"{cur_year-1}", "data": [next((r[2] for r in yoy if r[0] == m), 0) for m in range(1, 13)]},
        ],
    }

    lat = val(
        "SELECT quantile_cont(date_diff('hour',created_at,merged_at),[0,0.25,0.5,0.75,1]) "
        "FROM prs WHERE merged_at IS NOT NULL AND NOT is_bot",
        default=[0, 0, 0, 0, 0],
    )
    latency_data = [{"x": "Merge latency (hours)", "y": list(lat) if lat else [0, 0, 0, 0, 0]}]

    heat = rows(
        "SELECT repo_name, month(created_at) m, count(*) c "
        "FROM prs WHERE NOT is_bot GROUP BY 1,2 ORDER BY 1,2"
    )
    repos = sorted({r[0] for r in heat})[:15]
    heatmap_data = [
        {"name": repo.split("/")[-1],
         "data": [{"x": months[m - 1], "y": next((r[2] for r in heat if r[0] == repo and r[1] == m), 0)}
                  for m in range(1, 13)]}
        for repo in repos
    ]

    linger_rows = "".join(
        f'<div class="bg-white/5 p-4 rounded-lg flex justify-between items-center">'
        f'<div><p class="text-sm font-bold truncate w-48">{r[0]}</p>'
        f'<p class="text-xs text-slate-500">@{r[2]}</p></div>'
        f'<div class="text-right"><p class="text-lg font-black text-red-400 font-mono">{r[1]}d</p>'
        f'<p class="text-[10px] text-slate-600 uppercase">Linger</p></div></div>'
        for r in linger
    ) or "<p class='text-slate-500 italic'>No lingering open issues.</p>"

    cohort_rows = ""
    for r in mobility:
        impact = "High" if r[1] > 3 else "Moderate"
        color = "text-purple-400" if impact == "High" else "text-blue-400"
        cohort_rows += (
            f'<tr class="border-t border-white/5 hover:bg-white/5 font-mono">'
            f'<td class="p-4 font-bold text-white">@{r[0]}</td>'
            f'<td class="p-4 text-slate-300">{r[1]}</td>'
            f'<td class="p-4 text-slate-300">{r[2]}</td>'
            f'<td class="p-4 {color} font-bold">{impact}</td></tr>'
        )

    repl = {
        "{{OWNER}}": owner,
        "{{TIMESTAMP}}": now,
        "{{TOTAL_REPOS}}": str(total_repos),
        "{{AVG_RESONANCE}}": str(avg_resonance),
        "{{MEDIAN_LEAD_TIME}}": str(median_lead),
        "{{LEAKAGE_PERCENT}}": str(leakage_pct),
        "{{YOY_DATA_JSON}}": json.dumps(yoy_data),
        "{{LATENCY_DATA_JSON}}": json.dumps(latency_data),
        "{{HEATMAP_DATA_JSON}}": json.dumps(heatmap_data),
        "{{FUNNEL_DATA_JSON}}": json.dumps(funnel),
        "{{ISSUE_LINGER_ROWS}}": linger_rows,
        "{{COHORT_TABLE_ROWS}}": cohort_rows,
    }
    for kk, vv in repl.items():
        html = html.replace(kk, vv)
    with open(args.html, "w") as f:
        f.write(html)


if __name__ == "__main__":
    raise SystemExit(main())
