---
id: zsh-quality-rubric
title: "Zsh Configuration Quality Rubric"
purpose: Scoring rubric for evaluating Zsh configuration quality and standards compliance.
links:
  - id: startup-performance-budget
    rel: related
  - id: readme
    rel: parent
---

# Zsh Configuration Quality Rubric

Assessed on: 2026-03-02

## Scope

This rubric evaluates this repository's Zsh configuration against high-signal best practices:

- Clear startup-file responsibilities (`.zshenv`, `.zprofile`, `.zshrc`)
- History correctness and predictable behavior
- Completion security and reliability
- Deterministic keybindings across keymaps
- Fast, quiet interactive startup
- XDG portability
- Validation and CI enforcement

## Rubric (100 Points)

| Category | Weight | Score | Notes |
| --- | ---: | ---: | --- |
| Startup file discipline | 15 | 14 | Strong separation of responsibilities; minor duplication remains. |
| Modularity and load ordering | 10 | 10 | `conf.d` loading is clear and deterministic. |
| History correctness and ergonomics | 15 | 9 | `inc_append_history_time` can conflict with `share_history`. |
| Completion security and reliability | 15 | 11 | `compinit -i` tolerates insecurity while `bin/check` enforces compaudit. |
| Keybinding determinism | 10 | 9 | `^R` policy now explicit and robust; regression check still missing. |
| Performance and startup hygiene | 15 | 10 | Benchmark target exists; no explicit startup SLO/gate. |
| XDG and portability hygiene | 10 | 9 | Strong XDG posture; small env duplication remains. |
| Validation, CI, and documentation | 10 | 10 | `bin/check` + GitHub Actions quality gate is solid. |

Overall score: **82 / 100**

## Findings

1. Startup structure is strong.
`$ZDOTDIR` and XDG paths are established in `.zshenv`; interactive modules are isolated in `conf.d`.
2. History behavior needs one explicit policy decision.
`share_history` should not be paired with incremental append timing modes.
3. Completion security posture is partly strict, partly permissive.
Runtime uses `compinit -i`, while validation uses strict `compaudit`.
4. Keybindings are now deterministic for `^R` and `^X^R`.
Need to assert this in automated checks to prevent regressions.
5. Startup quality is measurable but not yet budgeted.
`make bench` exists; no threshold-based gate/documented SLO yet.
6. Small duplication exists in env/path setup.
`PNPM_HOME` setup appears in more than one location.

## Prioritized Remediation Plan

### Priority 1: Reliability and Security (first)

1. Enforce exclusive history mode.
Files: `conf.d/50-options.zsh`, `README.md`, `bin/check` (optional assertion)
Action:
- If `ZDOTS_SHARE_HISTORY=1`, disable `inc_append_history_time`.
- If `ZDOTS_SHARE_HISTORY!=1`, enable append-only local mode.
Acceptance:
- `zsh -i -c 'setopt | rg "share_history|inc_append_history"'` matches expected mode.
- No behavior regressions in interactive history search/write flow.

2. Align completion security runtime with validation policy.
Files: `conf.d/40-completion.zsh`, `README.md`
Action:
- Default to strict `compinit` behavior.
- Keep an explicit escape hatch env var for degraded environments.
Acceptance:
- Insecure completion paths fail fast by default.
- Documented opt-out remains available for emergency use.

3. Add keybinding regression checks.
Files: `bin/check`
Action:
- Assert `^R` maps to `fzf-history-widget` when widget is present.
- Assert fallback to `history-incremental-search-backward` when absent.
Acceptance:
- `bin/check` fails on accidental `^R` remaps.

### Priority 2: Configuration Hygiene

4. Remove duplicate `PNPM_HOME` export/path logic.
Files: `.zshrc`, `conf.d/30-env.zsh`
Action:
- Keep a single source of truth in one module.
Acceptance:
- `PATH` contains one `PNPM_HOME` entry and config remains deterministic.

### Priority 3: Performance Governance

5. Define and enforce startup performance budget.
Files: `Makefile`, `bin/check` (optional fast timing check), `README.md`
Action:
- Define startup SLO (for example median interactive startup target on local host).
- Add a repeatable benchmark command and document baseline update process.
Acceptance:
- Regressions are visible and actionable before merge.

## Execution Sequence

1. Implement Priority 1 items in one PR (history + completion + keybinding checks).
2. Implement Priority 2 item in a small cleanup PR.
3. Implement Priority 3 item with benchmark policy and docs update.

## Risk Notes

1. History option changes can alter cross-session expectations.
Mitigation: gate with `ZDOTS_SHARE_HISTORY` and document behavior clearly.
2. Strict completion policy may surface local permission drift.
Mitigation: keep explicit, documented temporary bypass path.
3. Performance gates can be noisy.
Mitigation: start with non-blocking reporting before enforcing a hard threshold.
