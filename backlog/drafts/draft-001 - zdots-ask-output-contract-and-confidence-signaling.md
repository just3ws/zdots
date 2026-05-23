---
id: DRAFT-001
title: 'zdots-ask: output contract and confidence signaling'
status: Draft
assignee: []
created_date: '2026-05-23 13:54'
labels:
  - local-ai
  - zdots-ask
  - architecture
dependencies: []
references:
  - bin/zdots-ask
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The local 7B model currently returns free text with no signal distinguishing a confident answer from a hallucination. Add a lightweight output contract so callers can distinguish answer quality without running frontier models.

**Problem**: `zdots-ask` returns free text. There's no way to know if the model is confident, guessing, or hallucinating. A caller that pipes the output into `zaider` or uses it to write code has no safety signal.

**Design options (evaluate before implementing)**:
1. Suffix-based signal: instruct the model to end with `[CONFIDENT]` or `[UNCERTAIN]` — fragile, easy to miss
2. JSON-wrapped output: `{"answer": "...", "confidence": "high|medium|low"}` — breaks readability
3. Separate confidence probe: send a second short prompt "Rate your certainty: high/medium/low" — doubles latency
4. Keyword heuristics on the response: detect hedging language ("I think", "possibly", "I'm not sure") — deterministic, no extra call

**Recommendation**: Option 4 first (deterministic, zero latency), with `--confidence` flag that appends a one-line rating. Only escalate to option 3 if heuristics prove insufficient.

**Failure mode**: If confidence is "low", `zdots-ask` should warn on stderr but still return the response — caller decides.

**DEFER**: Do not build until there is evidence that hallucination rate on real tasks is high enough to warrant the overhead. The quiz provides this signal — track how often cases fail after prompt updates.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Design decision documented: which option was chosen and why
- [ ] #2 zdots-ask --confidence appends a confidence rating
- [ ] #3 Rating is based on response text heuristics (no extra model call)
- [ ] #4 Low-confidence responses warn on stderr
- [ ] #5 Existing callers unaffected when --confidence not specified
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
