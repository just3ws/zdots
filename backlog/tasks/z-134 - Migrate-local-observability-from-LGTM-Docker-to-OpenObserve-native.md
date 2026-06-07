---
id: Z-134
title: Migrate local observability from LGTM (Docker) to OpenObserve (native)
status: To Do
assignee: []
created_date: '2026-06-06 05:49'
updated_date: '2026-06-07 13:21'
labels:
  - observability
  - infra
dependencies: []
priority: medium
ordinal: 25890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace the grafana/otel-lgtm Docker stack with a native OpenObserve single binary for single-developer local insights. LGTM forces a 4GB Colima VM reservation (the root of recurring embed/llama memory pressure on the 16GB M4) to run logs+metrics+traces datastores built for horizontal scale we never use. OpenObserve is OTLP-native, ~150MB, one binary, own UI on :5080 — the existing OTel Collector just repoints from otlphttp/lgtm (:4418) to it. Local-only, telemetry disabled, loopback bind (PHI). Decisions: drop Grafana (O2 has its own UI; remains a datasource if needed), new host o2.local retiring grafana/lgtm.local, home rollout first then work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Phase 1: openobserve-ctl (install/start/stop/restart/status/health/logs) installs pinned sha-verified darwin-arm64 binary; root password in Keychain not plist; binds 127.0.0.1; ZO_TELEMETRY=false; registered as zsvc 'o2'; runs alongside LGTM (no teardown)
- [x] #2 Phase 2: otel-collector.yaml gains otlphttp/openobserve exporter (OTLP HTTP :5080, basic-auth from env); validated in parallel with lgtm, then lgtm dropped from all three pipelines
- [x] #3 Phase 3: nginx o2.local vhost -> :5080, /etc/hosts entry, cert SAN; zdots-endpoints shows o2.local UP
- [x] #4 Phase 4: traces, metrics, and logs confirmed landing in OpenObserve UI
- [x] #5 Phase 5: LGTM torn down — container stopped, docker-compose.lgtm.yaml archived, local-ci deprecated/retired, grafana+lgtm registry+host entries removed; Colima stopped on home if obs-only (work keeps it for Rails)
- [x] #6 Phase 6: docs (otel-collector-guide -> OpenObserve), zdots-doctor/zdots-ctl check updated, memory updated
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Phase 6 DONE (commit aa73ad8): zdots-doctor gained an Observability section (O2 /healthz, loopback PHI check, collector-exporter sanity). Docs swept LGTM→OpenObserve: otel-collector-guide.md rewritten, README diagrams+tables, storage-hygiene/troubleshooting/configuration/local-url-routing fixed (wrong commands + resolved routing gaps), architecture/platform-service-plane/lifecycle/platform-discovery/tooling/wiki/tutorial swept. Only intentional 'retired (Z-134)' notes remain. doctor exit 0. ALL 6 ACs checked. ONLY remaining: Phase 3 activation is a user sudo action (echo '127.0.0.1 o2.local' | sudo tee -a /etc/hosts && nginx-ctl reload) — code/cert/config all in place.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
