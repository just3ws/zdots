---
name: command-qc
description: Apply the zdots command quality controls — --help, man page, completion, docs, agent-guide, capabilities, doctor/health, knowledge base, tests — consistently to any bin/ command. Use after adding or changing a command, or with "audit" to report drift without fixing.
---

# Command QC — the quality controls for a zdots command

Every user-facing command in `bin/` owes the same nine surfaces. A new verb
added to a command that doesn't reach its completion file is drift; drift
found by a human is a defect in the process. This skill IS the process.

Usage: `/command-qc <command>` (apply) · `/command-qc <command> audit` (report only)

## The surfaces

Work through every surface IN ORDER. For each: inspect, diff against the
command's actual behavior, fix or record. In audit mode, only report.

### 1. `--help` and the header comment

The script's `-h|--help` output and its header comment block must list every
subcommand, flag, env var, and example — they are the source of truth the
other surfaces derive from. Two house patterns:
- `usage()` heredoc (see `bin/agent-guide`, `bin/capabilities`)
- header-comment-as-usage via awk (see `bin/zsynod`: `_usage()` prints the `#` block)

Check: run `<cmd> --help`; compare against the dispatch table / arg parser.
Every verb in the dispatch must appear in help; every flag in the parser too.

### 2. Man page

Location: `man/man<N>/<cmd>.<N>` (mdoc — `.Dd/.Dt/.Sh`, model on
`man/man1/zdots-ctx.1`). Derive from the help text — NAME, SYNOPSIS,
DESCRIPTION, subcommands, ENVIRONMENT, FILES, EXIT STATUS, SEE ALSO.

**Pick the section by house convention** (a wrong section is drift):
- **1** — user commands (`zdots-ctx`, `ai-query`, `ztask`).
- **5** — config file formats (`zdots-env.5`, `phi-patterns.yaml.5`).
- **7** — concept/overview pages (`zdots-observability.7`, `zdots.7`).
- **8** — service & daemon managers, incl. every `*-ctl`
  (`llama-ctl.8`, `zdots-ctl.8`, `otel-collector.8`, `openobserve-ctl.8`).

Resolution is automatic: `$ZDOTDIR/bin` is on PATH, so macOS `man` derives
`$ZDOTDIR/man` — no MANPATH wiring needed. (The `share/man` entry in `.zshenv`
is empty/vestigial; do not put pages there.)

Verify: `man <cmd>` resolves and `mandoc -Tlint man/man<N>/<cmd>.<N>` is clean
(ignore the house-standard "new sentence, new line" / single-file "Xr not found"
warnings — confirm an existing page emits the same set before treating any as new).

### 3. Completion

Location: `functions/enabled/_<cmd>`, `#compdef <cmd>` first line. House
style: `subs=('verb:one-line description' …)` + per-verb `_arguments`, with
dynamic helpers reading live state cheaply (see `_zsynod`'s jq-backed
proposal/member helpers, `_zsvc`).

Check: every verb in the dispatch table appears in `subs`; new flags appear
in the verb's `_arguments`. Cautionary tale: `ui`/`keys`/`say`/`reply`
shipped in `bin/zsynod` while `_zsynod` still ended at `version` — found by
the operator, not the process. Never again.

Verify: `zsh -n functions/enabled/_<cmd>` exits 0 and line 1 is a `#compdef` header.
(Do NOT source the file as a gate: completion files end with `_<cmd> "$@"`, so
sourcing executes `_arguments` outside compsys — it always errors, and the exit
code just reflects whichever statement happens to run last. Z-233's "10 of 20
failures" were exactly this noise; all 20 files parse clean.)

### 4. Documentation

- `docs/tooling.md` — the full tool reference: add/refresh the command's entry.
- `AGENTS.md` §3 table and/or `CLAUDE.md` — only if agents should reach for
  it (these are loaded into every session; earn the tokens).
- A dedicated `docs/<cmd>.md` only when the command has architecture worth
  explaining (precedent: `docs/ruby-audit.md`). Link it from CLAUDE.md.
- Domain docs that already describe the command's system (e.g.
  `zsynod/LIFECYCLE.md`) — keep their usage blocks current.

### 5. agent-guide

`bin/agent-guide` is the live "how do I use this machine" brief for agents.
If the command is part of a service or workflow agents touch, add/refresh
its section (both human text and the `--json` emitter if present).

### 6. capabilities

`bin/capabilities` validates the environment contract. Add a check only if
the command is a contract surface: a service provider, a required tool, or
something whose absence should fail CI fast. A leaf utility doesn't belong here.

### 7. Health: zdots-doctor and zhealth (alias for `zdots-ctl check`)

If the command owns runtime state — a service, a daemon, a data file that
can rot — add a `zdots-doctor` check for it (and `zdots-ctl check`, the
`zhealth` alias, if it gates platform bring-up). A stateless command needs
nothing here.

Verify: `zdots-doctor --no-runtime --quiet` still passes.

### 8. Knowledge base

`zdots-ctx enqueue` a short note: what the command does, the verbs, when to
reach for it — so `zdots-ctx query <cmd>` answers before an agent claims
missing context. One note per command, updated not duplicated.

### 9. Tests

`tests/` must cover the command's contract: each verb's happy path and its
loudest failure. House framework: bats (`bats tests/<area>.bats`). Python
helpers get tested in their own suite (precedent: `tests/zsynod_core_py.bats`).

## Closing gate (apply mode)

Run, in order — all must pass before reporting done:
1. `<cmd> --help` lists every verb in the dispatch
2. `bash -n` / `zsh -n` on touched scripts (cc-hook-lint covers shellcheck on edit)
3. completion file sources clean (step 3 verify)
4. man page renders (step 2 verify)
5. `bats tests/` — relevant suites green
6. `bin/secret-scan` before any commit

Then report a table: surface → touched/clean/n-a, one line each. Anything
deliberately skipped gets a reason in the table, not silence.

## Rules

- Do NOT commit or push — report and await the operator's word.
- These shared surfaces (agent-guide, capabilities, zdots-doctor) have
  callers you can't see — keep changes additive; if a surface needs
  restructuring, file `zdots-issue` instead (AGENTS.md §5).
- Few word do trick: help text, man pages, and KB notes are read by agents
  at token cost. Dense beats long.
