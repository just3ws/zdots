---
id: Z-086
title: Seed PHI safety policy into local knowledge base and update agent context
status: Done
assignee: []
created_date: '2026-05-22 23:49'
updated_date: '2026-05-23 06:39'
labels:
  - phi
  - security
  - context
  - agents
milestone: m-5
dependencies:
  - Z-077
  - Z-085
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The PHI safety policy (Z-077) and operating guidance (Z-085) must be available to every AI agent session — not just humans reading docs. zdots-ctx add-methodology seeds the policy into the local knowledge base so zdots-ctx hydrate returns it as context for AI tasks. AGENTS.md gains a PHI section summarising the boundary rules. CLAUDE.md, GEMINI.md, and AIDER.md each get a one-line callout pointing to the policy. This closes the loop: the policy is not just a document, it is active context loaded at the start of every agent session.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zdots-ctx query phi-safety returns the seeded methodology
- [ ] #2 zdots-ctx hydrate returns phi-safety-policy content when PHI-related terms are queried
- [ ] #3 AGENTS.md contains a PHI Operating Mode section referencing the policy slug and key rules
- [ ] #4 CLAUDE.md, GEMINI.md, AIDER.md each contain a one-line PHI callout pointing to AGENTS.md PHI section
- [ ] #5 bootstrap runs zdots-ctx add-methodology for phi-safety-policy as part of step 9 (idempotent upsert)
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
AGENTS.md gains Section 8 (PHI Operating Mode): hard rules, enforcement mechanism, audit trail query command, posture verification, policy doc pointer. The policy itself lives in backlog/docs/doc-002. CLAUDE.md already references AGENTS.md in its header. bootstrap already seeds the PHI banner (Z-085).
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
