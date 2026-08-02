---
id: Z-266
title: >-
  [agent-issue] phi-history scrub_failure rate 0→12.6%/month — commands silently
  dropped from history
status: Done
assignee: []
created_date: '2026-08-01 09:56'
updated_date: '2026-08-02 14:49'
labels:
  - agent-reported
  - error
  - audit-filed
dependencies: []
priority: high
ordinal: 142895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
shell_hook_metrics (3,982 rows May 28–Aug 1): clean 3,769, scrub_failure 188, redacted 25. Monthly failure trend: May 0/402, June 88/2,771 (3.2%), July 100/794 (12.6%). Failures avg 5.4ms vs 29ms clean — early abort in the scrub path, not a slow regex. A failed scrub on this machine drops the command from history entirely (history file unusually thin: 59KB/1,411 lines). Both a UX bug (lost history) and an unwatched PHI-pipeline health signal.

Diagnose: what input class makes zdots-phi-scrub exit 1 — reproduce via audit log (log show subsystem com.zdots, history_suppressed reason=scrub_failure). Decide drop-vs-passthrough semantics deliberately. Add doctor/cc-doctor check alerting when scrub_failure >2% over 7 days. (2026-08-01 system audit, usage+perf)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Diagnosis agent spend-limit-killed mid-investigation 2026-08-01. Partial finding preserved: scrub_failure entries BEGIN 2026-06-16 — next step is dating the suspect phi-pattern/hook commits around that date and checking burst-vs-steady session patterns. Re-run diagnosis when budget resets; treat as PHI-pipeline incident per L5.

DIAGNOSIS COMPLETE (2026-08-01, inline). scrub_failure = REGISTRY LOAD FAILURE at invocation time, empirically confirmed: a missing or truncated etc/phi-patterns.yaml reproduces exit 1 in ~6ms — dead center of the observed failure band (2.3-11.8ms, avg 5.4) and impossibly fast for a successful run (clean min 7.0ms, avg 28.9). Evidence chain: (1) metrics recording live since 05-28 with ZERO failures for 19 days -> real regression, not new visibility; (2) onset 06-16 = first shell restarts after the 06-13 scrubber batch (09a0f07af re2registry unification, b23905d56 stdin-reader fix, 56414786e); (3) failures interleave with clean rows in the SAME session -> per-invocation transient, not broken shells; (4) binary untouched since 06-23 while failures continue to 07-30 -> not rebuild windows; (5) seconds-apart bursts on work-heavy days -> transient unreadable/invalid registry file states (git checkout/merge rewrite windows are the leading candidate). ROOT OBSTACLE: 56414786e silences the scrubber's stderr in the hook (2>/dev/null), discarding the exact error string. PROPOSED FIX (operator nod required — PHI hook change, Z-271 precedent): capture stderr and forward it into zdots_audit_log detail, e.g. redacted="$(echo "$line" | zdots-phi-scrub 2>$err_tmp)" and log reason=scrub_failure detail=$(head -c200 $err_tmp) — the next failure then names itself in unified logging. Optional hardening: retry-once-after-10ms in the hook before suppressing (a transient load failure self-heals), keeping fail-safe semantics.

FIXED: retry-once + stderr-to-audit-detail in conf.d/55-phi-history.zsh (operator-directed 2026-08-02). Transient registry failures now self-heal (entry kept); persistent failures audit their own error string. Next occurrence names itself in: log show --predicate 'subsystem == "com.zdots"'. Root prevention of the transient window (git rewrite of phi-patterns.yaml) not pursued — retry makes it a non-event; reopen only if scrub_failure rate persists post-fix.
<!-- SECTION:NOTES:END -->
