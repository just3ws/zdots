---
id: Z-037
title: Add metadata-only audit log to ai-query
status: To Do
assignee: []
created_date: '2026-04-19 02:32'
labels:
  - ai-query
  - security
  - observability
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Injection attempts currently leave no local trace. When ai-query processes suspicious content, the operator has no way to review what happened after the fact. A metadata-only log gives visibility without leaking sensitive data: it records signal (hash, score, mode, bytes) but never the raw content that triggered it. This supports incident review, tuning of scanner weights, and operator accountability without creating a data-exfiltration risk from the log file itself.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each invocation appends one JSONL line containing: timestamp, mode, risk_score, risk_level, input_bytes, content_hash (SHA256 of normalized input), model, endpoint,Raw content is never written to the log under any circumstance,Default log location is $XDG_STATE_HOME/zsh/ai-query-audit.jsonl and is documented,Audit logging is disabled by default and enabled via AIQ_AUDIT_LOG=1 env var or --audit flag,Log file is created with permissions 600,docs/ai-query.md documents the log format log location and how to enable it,Tests verify: log file is created with 600 permissions; log line contains all expected fields; raw content is absent from the log
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
