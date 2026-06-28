---
id: Z-156
title: '[agent-issue] Tune spanmetrics connector — duration_bucket ingests ~2 GB/day'
status: Done
assignee: []
created_date: '2026-06-17 19:26'
updated_date: '2026-06-28 22:37'
labels:
  - agent-reported
  - request
dependencies: []
priority: high
ordinal: 47890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** high
**Trace ID:** `6bf14d21464f22110cd5256b140c4c30`

PROBLEM
OpenObserve data dir grew to 17 GB; 10 GB was a single derived metric, traces_span_metrics_duration_bucket, + 1 GB index + 744 MB _sum. All data was inside the retention window, so retention/compaction was healthy — the issue is ingest VOLUME, not trimming. Mitigated immediately by cutting retention 14->3 days (bin/openobserve-ctl:162) + reinit (17 GB -> 81 MB).

ROOT CAUSE (etc/otel-collector.yaml:78-86, spanmetrics connector)
- exemplars: enabled: true — attaches trace/span IDs to every histogram point; biggest storage multiplier.
- metrics_flush_interval: 5s — 12 data points/min/series, huge row counts.
- Unbounded span.name cardinality (default dim) x custom event.type dim x 11 explicit buckets.

PROPOSED (tune connector, ordered by impact)
1. Disable or sample exemplars on spanmetrics.
2. metrics_flush_interval 5s -> 60s.
3. Bound dimensions; drop/normalize high-cardinality span.name; reconsider event.type dim.
4. Evaluate exponential histograms vs 10 explicit buckets.

THEN (usability)
Ensure retained RED metrics are the ones we actually query and that traces/logs stay joinable at 3-day retention. Design pass after volume is tamed.

Retention is a stopgap; without connector tuning the store still refills at ~2 GB/day.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
