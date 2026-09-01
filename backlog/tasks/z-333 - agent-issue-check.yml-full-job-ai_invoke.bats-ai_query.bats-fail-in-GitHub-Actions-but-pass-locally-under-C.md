---
id: Z-333
title: >-
  [agent-issue] check.yml 'full' job: ai_invoke.bats + ai_query.bats fail in
  GitHub Actions but pass locally under C
status: To Do
assignee: []
created_date: '2026-09-01 19:24'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 208895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `51a96ef723d9121d483864d519bd4b0b`

check.yml 'full' job: ai_invoke.bats + ai_query.bats fail in GitHub Actions but pass locally under CI simulation. ~20 failures, e.g. ai_invoke.bats:68 expects infer_raw to emit 'ai-query not found' when ai-query is missing — in GHA it doesn't (ai-query IS on PATH from bin/, or the error text changed). ai_invoke.bats:87 [ status -eq 0 ] also fails. Local: 'CI=1 ZDOTS_SKIP_ENV_TESTS=1 bats tests/ai_invoke.bats tests/ai_query.bats' passes 0 failures, deps-up AND deps-down sim. So these files don't meet the ci-allowlist.txt bar ('verified green under BOTH conditions') in the actual GHA env. This is the last layer of check.yml 'full' breakage after the brew-tap fix (romkatv tap trust) and the stale zsynod_*.bats allowlist cleanup this session. Options: (a) debug the local/GHA infer_raw behavior gap, (b) temporarily drop ai_invoke/ai_query from tests/ci-allowlist.txt and re-add once CI-verified. Context: check.yml full has been red since 2026-08-17 (Z-305).

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
