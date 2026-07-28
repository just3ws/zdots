---
id: Z-228
title: >-
  [agent-issue] docs_sync worker jobs hallucinate docs, half-apply, and
  retry-loop on LLM timeout
status: To Do
assignee: []
created_date: '2026-07-15 18:32'
updated_date: '2026-07-28 18:47'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 107895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** high
**Trace ID:** `64fc7ae163a5227411ce047015e86825`

Audit of the unexplained README.md working-tree modification (mtime 2026-07-15 08:01). Root cause: zdots-worker docs_sync jobs (e.g. 5b0cd857, residue session 16114c3a) rewrite README.md '(updated successfully)', then hit Net::ReadTimeout (TCPSocket closed) against the local LLM on the next file (docs/architecture.md), FAIL, and requeue — 115+ 'Processing README.md' passes in zdots-worker.log. Three defects: (1) partial application — README is mutated before the job is known to succeed, no rollback on failure; (2) content quality — the generated README section documents lib/cert-store.bash and lib/service-reload.bash which do not exist in any commit on any branch; the model extrapolated fake lib paths from cert/reload lessons (real machinery is bin/nginx-regen-certs, nginx-ctl, zsvc); (3) retry storm — ctx_jobs shows 7 docs_sync jobs queued across 5+ residue sessions, all failing the same timeout, burning inference. Expected: docs_sync applies atomically (temp file + rename after ALL files succeed), grounds doc claims against the actual tree (a path it documents must exist), and dead-letters after N failures. The dirty README.md should NOT be committed; reverting is futile until the queue is drained/paused.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-07-28: mitigations landed — (1) fictional-path gate: generated docs referencing repo paths that don't exist are REJECTED, not written (would have caught the SSH-contract hallucination); (2) two-phase apply ends half-applies; (3) phi_suppressed docs skip instead of retry-looping; (4) LLM-timeout loops now bounded by the global 5-attempt dead-letter. Remaining: hallucinations that invent no paths still pass — semantic validation is out of scope for now.
<!-- SECTION:NOTES:END -->
