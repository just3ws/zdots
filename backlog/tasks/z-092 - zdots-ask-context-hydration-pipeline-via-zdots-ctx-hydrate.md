---
id: Z-092
title: 'zdots-ask: context hydration pipeline via zdots-ctx hydrate'
status: To Do
assignee: []
created_date: '2026-05-23 13:54'
labels:
  - local-ai
  - zdots-ask
  - context
dependencies: []
references:
  - bin/zdots-ask
  - bin/zdots-ctx
  - etc/prompts/
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add `--context` flag to `zdots-ask` that prepends a `zdots-ctx hydrate` blob to the prompt before sending to the local model. This gives the 7B model live repo-state awareness without requiring it to know the full codebase.

**Problem**: Each `zdots-ask` call is stateless. The system prompts give domain conventions but not current repo state (active tasks, recent lessons, current session context). High-value tasks like "what should I work on next?" or "summarize what we know about X" require the knowledge base.

**Design**:
- `zdots-ask --context [TAG]` calls `zdots-ctx hydrate [TAG]` and prepends output to the user prompt
- Context blob goes between system prompt and user message (not in system prompt — it's dynamic)
- Hard limit: 4096 tokens for context blob (leave room for response in 32768 ctx window)
- If context exceeds limit, truncate with explicit warning

**Escalation path**: If `zdots-ctx` is unavailable or DB is down, proceed without context (warn, don't fail).

**Validation**: Add TC-15 to zdots-quiz: `zdots-ask --context` returns a response that references a known lesson topic.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zdots-ask --context [TAG] prepends hydration blob to prompt
- [ ] #2 Context blob truncated at 4096 tokens with warning
- [ ] #3 Failure of zdots-ctx hydrate degrades gracefully (warns, proceeds without context)
- [ ] #4 zdots-quiz TC-15 validates context-aware response
- [ ] #5 No latency increase when --context not specified
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
