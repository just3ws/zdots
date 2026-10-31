---
id: Z-335
title: 'Bump google.golang.org/grpc in cmd/* Go modules (Dependabot high: HTTP/2 OOM)'
status: Done
assignee: []
created_date: '2026-09-01 22:02'
updated_date: '2026-09-02 16:06'
labels:
  - agent-reported
  - security
dependencies: []
priority: medium
ordinal: 210895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Dependabot (enabled 2026-09-01 with the public flip) flagged google.golang.org/grpc HIGH in cmd/zdots-phi-scrub/go.mod: 'gRPC-Go: Heap Memory Exhaustion (OOM) via HTTP/2 DATA Frame Fragmentation'. Transitive via the OTel gRPC exporter. Practical risk is low (zdots-phi-scrub's gRPC client only talks to the loopback OTel collector, not an untrusted peer) but it's a real HIGH on a public repo. All three cmd/* modules (zdots-phi-scrub, zdots-buffer-drain, zdots-secret-scan) share the OTel/grpc dep tree — bump in all three: cd cmd/<tool> && go get -u google.golang.org/grpc && go mod tidy, rebuild the committed binaries, verify tests. Or accept Dependabot's PR(s).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 google.golang.org/grpc bumped past the advisory in all 3 cmd/*/go.mod
- [ ] #2 committed cmd/* binaries rebuilt; go test ./... green in each module
- [ ] #3 Dependabot alert 19 resolved
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Done 2026-09-02. grpc v1.82.1 -> v1.83.1 in cmd/zdots-phi-scrub/go.mod (the only module with grpc — buffer-drain/secret-scan have 0 grpc in go.sum). go mod tidy also bumped genproto deps. Committed binary rebuilt (arm64), --init OK, phi_boundary.bats + phi_scrubber_fuzz.bats green. No vulnerable grpc anywhere in cmd/*/go.sum. Commit c80f03e.
<!-- SECTION:NOTES:END -->
