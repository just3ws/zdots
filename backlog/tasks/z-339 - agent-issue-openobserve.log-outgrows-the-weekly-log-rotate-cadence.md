---
id: Z-339
title: '[agent-issue] openobserve.log outgrows the weekly log-rotate cadence'
status: To Do
assignee: []
created_date: '2026-09-03 13:31'
updated_date: '2026-09-03 13:31'
labels:
  - agent-reported
  - friction
dependencies: []
priority: medium
ordinal: 214895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
During /zdots-heal Gate 4, zdots-doctor warned 'openobserve 106M (warn >=100M)'. Manually ran 'log-rotate openobserve' (106M -> 9M gz) to clear it.

## Evidence
- com.zdots.log-rotate is a WEEKLY launchd job (StartCalendarInterval Weekday 0), rotating: otel-collector, openobserve, llama-server, llama-embed, gemstash.
- Last run 2026-08-30 03:21 -> openobserve.log.20260830-032146.gz (9.1M gz).
- Four days later (2026-09-03) the active openobserve.log was back to 106M.
- Growth ~26 MB/day. Weekly rotation cannot hold it under 100M; it would reach ~180M before the next Sunday run.

## Likely source
openobserve logging at high volume. Session brief shows ~500 failed spans / 6h (GET, HEAD, scraper.search) rejected at ingest -- a plausible driver of the log churn.

## Suggested fix (source, not retention)
- (a) lower openobserve's own log level / suppress the repeated ingest-rejection lines, and/or
- (b) add openobserve to a daily rotation tier rather than the weekly batch.
- See the telemetry-volume skill.

Not blocking. Filed from /zdots-heal 2026-09-03.
<!-- SECTION:DESCRIPTION:END -->
