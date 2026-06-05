---
id: Z-130
title: Shrink the AI Invocation Interface — stop leaking via env vars
status: To Do
assignee: []
created_date: '2026-06-05 19:58'
updated_date: '2026-06-05 22:04'
labels:
  - architecture
  - refactor
dependencies: []
priority: medium
ordinal: 21890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Architecture candidate #5 (Worth exploring). The AI Invocation Interface's real contract is undocumented env vars and a thrice-asserted gate.

Files: lib/ai-invoke.bash, lib/ai-query-lib.bash, lib/ai_boundary.bash, bin/ai-query

Problem: zdots_ai_distill/zdots_ai_infer_raw coordinate behaviour (AIQ_TEMPERATURE, AIQ_ENABLE_THINKING, AIQ_SUPPRESS_RAW_WARN) by exporting env vars read four frames down in aiq_submit; the locality+gate check fires three times (bin/ai-query, zdots_ai_infer_raw, aiq_submit). The seam is wider than its signature admits.

Solution: promote temperature/thinking to parameters of the interface; assert the gate once. Everything a caller must know moves into the signature.

Wins: interface shrinks to what is true, locality (one gate assertion), testable without env mutation, deletes the AIQ_SUPPRESS_RAW_WARN coupling.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 temperature and thinking are explicit parameters, not exported env vars
- [ ] #2 the gate/locality check is asserted at exactly one layer
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
EXECUTION PLAN (verified against the tree 2026-06-05; re-grep before editing).

GOAL: temperature/thinking become explicit parameters of the interface, not env
vars callers must export; resolve the locality gate firing at three layers.

CURRENT STATE (file:line):
- Shell interface (lib/ai-invoke.bash): zdots_ai_infer_raw PROMPT [SYS] (:54);
  zdots_ai_distill PROMPT (:97, which `export AIQ_TEMPERATURE=0.1` at :113).
- Behaviour is set by env vars read 3 frames down in aiq_submit
  (lib/ai-query-lib.bash): AIQ_TEMPERATURE (:369), AIQ_ENABLE_THINKING (:360),
  AIQ_JSON_SCHEMA (:366). AIQ_SUPPRESS_RAW_WARN (ai-invoke.bash:85) suppresses a
  bin/ai-query raw-mode warning.
- bin/ai-query has --think (:165 sets AIQ_ENABLE_THINKING) but NO --temperature;
  temperature is env-only. Arg parser ~:157-181.
- Gate fires THREE times: ai-invoke.bash:66 (zdots_ai_gated_endpoint, fail-fast
  before spawning), bin/ai-query:209-210, aiq_submit:346-348. The last two are
  both inside the ai-query subprocess.
- Callers leaking via env (must update): bin/zdots-ask:241 (AIQ_ENABLE_THINKING);
  conf.d/97-zle-ai.zsh:84 and :108 (AIQ_TEMPERATURE, the explain/fix widgets).
  bin/zdots-ctx:328 calls distill (no export — fine).
- Request-body behaviour pinned by tests/zdots_eval.bats (A1-A5). Keep these
  GREEN by keeping AIQ_* as aiq_submit's INTERNAL inputs; only the PUBLIC
  interface changes.

PART A - complete bin/ai-query's flag surface:
- Add --temperature N to the parser (mirror --think at :165, set AIQ_TEMPERATURE).
  Document in usage (~:103-114) and man/. AIQ_* stay internal; flags just set them.

PART B - parameterise the shell interface:
- zdots_ai_infer_raw: accept leading flags -> zdots_ai_infer_raw [--temperature N]
  [--thinking] PROMPT [SYS]; translate to ai-query --temperature/--think. Stop
  reading inherited AIQ_* from callers.
- zdots_ai_distill: replace export AIQ_TEMPERATURE=0.1 (:113) with
  zdots_ai_infer_raw --temperature 0.1.
- Update callers to pass params, drop exports: 97-zle-ai.zsh:84,:108;
  zdots-ask:241 (--thinking). Update the env-var doc block (ai-invoke.bash:47-51).
  DECIDE: keep AIQ_* accepted as a back-compat fallback, or remove. Recommend keep
  (fallback) so nothing external breaks.

PART C - the gate (DESIGN DECISION, SECURITY-SENSITIVE - read before cutting):
- Two distinct concerns are conflated: (1) fail-fast UX (mode=none -> don't work),
  ai-invoke.bash:66; (2) the authoritative security boundary (never send to a
  non-local endpoint), at the network call in aiq_submit. bin/ai-query:209-210
  duplicates (2) at subprocess entry.
- AC#2 wants 'one layer', but for a PHI boundary defense-in-depth is defensible.
  RECOMMENDED: keep ONE authoritative security assertion in aiq_submit; remove the
  duplicate at bin/ai-query:209-210 (it immediately calls aiq_submit). KEEP
  ai-invoke.bash:66 but RELABEL it in comments as the fail-fast UX gate, not a
  security check. Net: security asserted once + one clearly-labelled fast-fail.
- Do NOT delete a gate without preserving 'no inference reaches a non-local
  endpoint'. Add a regression test for that property.

TESTS:
- Keep tests/zdots_eval.bats green (internal AIQ_* unchanged).
- Add: ai-query --temperature sets request-body temperature (mirror A3); shell
  flags flow through (extend tests/ai_invoke.bats); non-local endpoint refused at
  the submit layer (guards the gate consolidation). Update any caller test that
  assumed env exports (tests/ai_invoke.bats, zdots_ask.bats).

RISKS: locality is a security boundary - never weaken it; ZLE widgets run under
interactive zsh (verify the param call there, not just bash); AIQ_SUPPRESS_RAW_WARN
coupling is out of scope unless trivial.

VERIFY: make check (exit 0, shellcheck --severity=warning clean); bats
tests/ai_invoke.bats tests/ai_query.bats tests/zdots_eval.bats tests/zdots_ask.bats;
manual: echo hi | ai-query --mode raw --temperature 0.1 --think 'summarize'.

SCOPE: shell-only, no Ruby. Behaviour-preserving for request bodies. The win is the
contract moving into signatures + one authoritative security gate. Est: M.
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
