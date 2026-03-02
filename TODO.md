# TODO

## P0 (Highest)

- [x] Fix `asdf` loading behavior in interactive shells.
  - Switched from lazy wrapper to explicit `asdf.sh` initialization.
  - Added regression check in `bin/check` (`asdf --version` in interactive shell).

## P1 (Security + Reliability)

- [x] Add CI gate to run `bin/check` on PR/push.
  - Prevent regressions from landing without local validation parity.
  - Workflow now includes Homebrew cache reuse and retry loops for flaky network/install steps.

- [x] Add login-shell runtime validation in `bin/check`.
  - Catch `.zprofile` and login-only startup failures.

- [x] Harden `history-import` persistence path and data lifecycle.
  - Enforce private DB permissions.
  - Add import idempotency protections.
  - Add retention/prune support.

- [x] Make upgrade helpers safer by default.
  - Remove broad forced upgrades.
  - Require explicit opt-in for aggressive behavior.

- [x] Normalize `~/.zshenv` bootstrap to repo source-of-truth.
  - Keep runtime settings in repo-managed `$ZDOTDIR/.zshenv`.
  - Minimize host-local drift in startup behavior.

## P2 (Safety + UX)

- [x] Remove insecure TLS bypass alias.
  - Retire `nv=--tls-no-verify` global alias.

- [x] Revisit cross-session history sharing defaults.
  - Prefer append-only history writes by default.
  - Keep optional opt-in for shared history.

- [x] Remove legacy/non-effective history knob.
  - Drop `HISTFILESIZE` in favor of `HISTSIZE`/`SAVEHIST`.

## P3 (Quality of Life)

- [x] Add a `Makefile` for common workflows.
  - Targets: `bootstrap`, `check`, `bench`, `upgrade`.

- [x] Add optional `shellcheck` pass to `bin/check`.
  - Run only when `shellcheck` exists.

- [x] Add prompt health check to `bin/check`.
  - Verify at least one Powerlevel10k theme candidate is present.

- [x] Add recovery/troubleshooting doc section.
  - Include startup failure workflow (`zsh -f`, disable a module, run `bin/check`).

## P1 (Rubric: Reliability + Security)

- [x] Enforce mutually exclusive history mode settings.
  - Update `conf.d/50-options.zsh` so `share_history` and `inc_append_history_time` are not enabled together.
  - Document exact behavior in `README.md`.
  - Add/adjust checks for expected mode behavior.

- [x] Align completion runtime policy with strict security defaults.
  - Replace default permissive `compinit -i` flow with strict behavior.
  - Keep explicit env-gated bypass for constrained systems.
  - Document failure mode and bypass in `README.md`.

- [ ] Add keybinding regression checks for history search.
  - Extend `bin/check` to validate `^R` mapping policy (`fzf-history-widget` when present, safe fallback otherwise).
  - Ensure checks run under both `zsh -i` and `zsh -l -i`.

## P2 (Rubric: Hygiene)

- [ ] Remove duplicate `PNPM_HOME` path setup.
  - Consolidate to one source of truth between `.zshrc` and `conf.d/30-env.zsh`.
  - Verify no duplicate `PNPM_HOME` entry in `PATH`.

## P3 (Rubric: Performance)

- [ ] Define and track startup performance budget.
  - Record baseline startup metrics and target threshold.
  - Document budget policy and refresh cadence in `README.md`.
  - Add optional non-blocking timing report to validation workflow.
