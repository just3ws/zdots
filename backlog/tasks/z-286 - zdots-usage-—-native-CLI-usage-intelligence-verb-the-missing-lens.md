---
id: Z-286
title: zdots-usage — native CLI usage intelligence verb (the missing lens)
status: To Do
assignee: []
created_date: '2026-08-02 16:43'
labels:
  - agent-ready
dependencies: []
priority: high
ordinal: 162895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Operator ask (2026-08-02): 'not much intelligence that can be acted upon' about CLI usage. The DATA already exists — traces.jsonl (10.9k parseable events: exec/error/chdir/session_start), shell_hook_metrics, o2 spans, rtk gain — but there is no unified lens. Inline analysis this session proved the value; the verb should productize exactly those queries:

REPORTS (zdots usage [report]):
- top: command frequencies (first-word + full-alias resolution)
- errors: error rate per command WITH the status-130 attribution correction discovered today (Ctrl-C at an empty prompt fires precmd with 130 and blames the PREVIOUS command via ZDOTS_LAST_COMMAND — klear showed a fake 46% error rate this way; instant commands followed by prompt-aborts are artifacts)
- agents-vs-human: segment sessions by process.interactive/tty (392 session_starts on 08-01 were overwhelmingly CC agent zsh -ic shells vs ~4-10/day human baseline — unsegmented numbers are meaningless)
- candidates: repeated long literals -> alias suggestions (observed: 'k; upgrade' pattern 42x — a typo-habit; deploy 200x; ack 77x with 40% nonzero), dead tools (in bin/ but zero exec events in 90d), wrapper adoption (rtk 5.2%)
- module-health: source_failure aggregation (97-zle-ai fails ONLY in non-tty shells, 107 events since June — agent-shell artifact, should be segmented or guarded)

Implementation: single bin/zdots-usage reading traces.jsonl with jq -R fromjson? (tolerant — ~165 pre-escaping lines are unparseable) + sqlite3 -init /dev/null for metrics; no new stores, no daemon. Feed 'candidates' output into alias-suggest. Consider a Lesson auto-draft for recurring patterns (Virtuous Loop tie-in).
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
