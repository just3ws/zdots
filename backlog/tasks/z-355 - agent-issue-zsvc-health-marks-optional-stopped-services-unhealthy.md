---
id: Z-355
title: '[agent-issue] zsvc health marks optional stopped services unhealthy'
status: Done
assignee: []
created_date: '2026-10-31T23:15:00Z'
updated_date: '2026-11-01T03:46:00Z'
labels:
  - agent-reported
  - error
dependencies: []
modified_files:
  - lib/svc-registry.bash
  - bin/zsvc
  - tests/svc_registry.bats
  - tests/platform_e2e.bats
priority: medium
ordinal: 226895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `5175011939a1195d366748987d19123f`

I was checking the normal bare-metal service posture with Colima intentionally stopped and the optional bus-coordinator parked. `zsvc health --json` returned healthy=false because colima (stopped) and coordinator (not-registered) both had health=fail, even though all required platform services and the six core local URLs reported ok, and `capabilities --json` reports health_errors=0. Expected: optional/on-demand services should be reported distinctly and should not make the required-platform health summary false. Please add an explicit required/optional policy and focused coverage for the summary semantics.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Service registry declares required or optional health policy for every service
- [x] #2 Optional service probe failures remain visible but do not fail aggregate health
- [x] #3 Required service and local URL failures still fail aggregate health
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented explicit health policy in lib/svc-registry.bash. zsvc JSON exposes policy; optional failures remain visible without failing aggregate status. Tests: tests/svc_registry.bats and tests/platform_e2e.bats pass (38/38); full make check passes (check: OK). Live zsvc health --json reports healthy:true with Colima stopped and coordinator not registered, all six core URLs HTTP 200. Verified git diff --check and bin/secret-scan. Operator approved work by directing resume/fix-forward; this resolves the original wait-for-operator note.

Remote verification complete: commit 9f2549da was pushed as Mike Hall <mike@just3ws.com>; GitHub Check 41268639876 and Secret Scan 41268639863 both passed. Optional Colima and coordinator remain visible as failing probes but do not affect aggregate health. The operator explicitly authorized resuming and fixing forward, resolving the original coordination hold.
<!-- SECTION:NOTES:END -->
