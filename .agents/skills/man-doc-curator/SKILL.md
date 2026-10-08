---
name: man-doc-curator
description: Maintain, generate, validate, and curate man pages (man/man1, man/man8), CLI --help contracts, and interface inventories across zdots. Use when modifying or creating CLI commands, updating documentation contracts, running docs_contract tests, or curating man pages.
---

# Man Page & CLI Help Curator (`man-doc-curator`)

## Quick Start

```bash
# 1. Audit man page coverage across all bin/ tools
bin/zdots-man-gen --check

# 2. Generate missing man page stubs from --help output
bin/zdots-man-gen

# 3. Test docs and CLI interface contracts
bats tests/docs_contract.bats

# 4. View a rendered man page locally
mandoc -Tutf8 man/man1/<command>.1 | head -40
```

---

## The Contract Suite (`tests/docs_contract.bats`)

Zdots enforces strict documentation hygiene via automated Bats suites:

1. **`--help` Availability & Speed (Z-249)**:
   - Every executable in `bin/` must respond to `--help` within 5 seconds.
   - Must exit with code `0`.
   - Must output usage text containing `Usage:`, `Commands:`, or `Options:`.
   - Must be non-interactive (fails if it prompts on closed stdin `</dev/null`).

2. **Man Page Parity (`zdots-man-gen --check`)**:
   - Every executable in `bin/` must have a corresponding man page in `man/man1/<command>.1` or `man/man8/<command>.8`.
   - Unwritten stubs can be generated via `bin/zdots-man-gen`.

3. **Fictional-Reference Linting (Z-153)**:
   - Any backticked \`zdots-*\` tool cited in docs (`AGENTS.md`, `CLAUDE.md`, `docs/wiki/`, tier docs in `etc/docs-sync-manifest.yaml`) must exist and be executable in `bin/` or explicit in the test's allowlist.

4. **Interface Inventory**:
   - `docs/generated/interface-inventory.json` & `.md` track registered commands and capabilities.
   - Known exceptions must be recorded with justification in `docs/generated/docs-contract-known-gaps.txt`.

---

## Workflows

### 1. Adding or Modifying a CLI Command

When adding or touching an executable in `bin/` or `recipes/`:

- [ ] **Provide standard `--help`**:
  Ensure the command supports `-h` and `--help` and prints a clear `Usage:` block with synopsis and flag definitions.
- [ ] **Check `--help` speed**:
  Verify the script exits 0 and does not execute heavy startup routines or block on TCC / network when `--help` is requested:
  ```bash
  timeout 5 bin/<command> --help </dev/null
  ```
- [ ] **Generate or Curate the Man Page**:
  - Run `bin/zdots-man-gen` to generate the initial manual page.
  - Or curate an mdoc/groff manual page directly in `man/man1/<command>.1` (or `man/man8/` for root/system daemons).
  - Verify syntax with `mandoc -Tlint man/man1/<command>.1`.
- [ ] **Update Tested Commands in `tests/docs_contract.bats`**:
  If this is a permanent platform command, add it to the `tested=( ... )` array in `tests/docs_contract.bats`.
- [ ] **Verify Contracts**:
  ```bash
  bats tests/docs_contract.bats
  ```

---

### 2. Upgrading a Generated Man Page to Curated mdoc

Generated pages from `zdots-man-gen` use basic roff blocks (`.TH`, `.SH NAME`, `.SH SYNOPSIS`, `.nf`). When hand-promoting a high-visibility command to full BSD mdoc:

```roff
.Dd October 8, 2026
.Dt COMMAND-NAME 1
.Os zdots
.Sh NAME
.Nm command-name
.Nd concise one-line description
.Sh SYNOPSIS
.Nm
.Op Fl -flag
.Ar argument ...
.Sh DESCRIPTION
Detailed description of behavior, architecture, and interfaces.
.Sh OPTIONS
.Bl -tag -width "--flag"
.It Fl -flag
Option explanation.
.El
.Sh ENVIRONMENT
.Bl -tag -width "ZDOTS_ENV_VAR"
.It Ev ZDOTS_ENV_VAR
Description of the environment variable.
.El
.Sh SEE ALSO
.Xr agent-guide 1 ,
.Xr zdots-doctor 1
```

Validate and inspect:
```bash
mandoc -Tlint man/man1/<command>.1
mandoc -Tutf8 man/man1/<command>.1 | less
```

---

### 3. Handling Known Gaps

If a command is an internal helper, third-party binary, or cannot implement standard `--help` conventions, ledger it in `docs/generated/docs-contract-known-gaps.txt` instead of allowing silent CI breakage:

Format:
```
<command-name>:<reason/explanation>
```
