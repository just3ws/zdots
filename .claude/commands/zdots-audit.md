# /zdots-audit — zdots Dry-Run Audit

Evidence-backed dry-run audit of the zdots Zsh system. No cleanup. No commits. No mutation.

---

## What This Skill Does

Audits `$HOME/.config/zsh` and produces structured artifacts under `audit/`.

Shows:
1. What zdots promises
2. What zdots implements
3. What is missing
4. What is stale
5. What is misplaced
6. What is unsafe to change

---

## Operating Rules

### Schrute Test
Before every action: would an idiot do this?
If yes: `zdots-issue --high "Audit stop: <reason>"` → stop → mark `needs_human_review`.

### Kevin's Law
Few words do trick. Exact terms. Code over prose. Evidence over opinion.

---

## PHI Rules (non-negotiable)

- `ZDOTS_AI_MODE=local` — never change
- Never route PHI or decrypted content to cloud tools
- Never bypass `lib/phi_scrubber.bash`
- Never alter PHI patterns outside `etc/phi-patterns.yaml`
- Never mutate encryption, keychain, or rekey logic
- Never change MCP transport assumptions
- MCP tools returning decrypted content = high risk

---

## Sacred Areas (default: keep)

`.zshrc` `.zprofile` `.zshenv` `.zlogin` `.zlogout`
`conf.d/` `lib/` completion loading `compinit` PATH setup
prompt initialization keybindings history Homebrew setup mise setup
secrets/keychain setup MCP PHI Scrubber Message Hygiene Pipeline
Access Control Knowledge Layer `zdots-ctx` `zdots-ask` `zdots-issue` backlog

---

## Orientation Commands

```bash
cd "$HOME/.config/zsh"
rtk git status --short
zdots-ctl status
capabilities --json
agent-guide
zdots-ctx hydrate tooling-catalog
```

Always proxy high-output commands through `rtk`.

---

## Evidence Standard

Proof requires at least one of:
- Direct reference from code
- Direct reference from shell startup
- Direct reference from tests
- Direct reference from docs used by agents
- Direct reference from git history plus current path evidence
- Successful command execution showing expected behavior
- Explicit operator instruction

If evidence conflicts: prefer runtime behavior over docs.
If runtime behavior is unsafe to test: mark `needs_human_review`.

---

## Evidence Commands

```bash
git ls-files
find bin sbin -maxdepth 1 -type f -print | sort
find . -maxdepth 1 -type f -print | sort
find . -iname '*zsynod*' -print | sort
rg --hidden --glob '!/.git/**' 'zsynod' .
rg --hidden --glob '!/.git/**' '<term>' .
rtk git log --follow -- <file>
git blame -- <file>
bats tests/
zdots-ctl check
bin/secret-scan
yamllint etc/phi-patterns.yaml
colima-status --json     # never: colima status
colima-status socket
colima-status health
```

---

## File-Level Audit Questions

1. What is it?
2. Executable?
3. Referenced?
4. On PATH?
5. Called by: aliases, functions, tests, docs, skills, MCP, launchd, cron, scripts?
6. Useful to human?
7. Useful to AI/agent context?
8. Stale?
9. Duplicated?
10. Misplaced?
11. Dangerous?
12. Needs tests?
13. Needs docs?
14. Belongs in `experiments/`?
15. Should become a backlog task?

---

## Audit Scope Order

1. `bin/`
2. `sbin/`
3. Root files under `$HOME/.config/zsh`
4. `.agents/skills`
5. `tests/`
6. `docs/`
7. `backlog/`
8. `experiments/`
9. Remaining directories by dependency risk

One directory at a time. One file at a time.

---

## Known Findings To Verify

- `docs/adr/` exists or missing
- `grill-with-docs` and `improve-codebase-architecture` depend on ADRs
- `bin/ctx-mcp` has or lacks MCP tests
- `bin/ctx-mcp-register` supports Claude Desktop only or more agents
- `tests/docs_contract.bats` coverage for `bin/` and `sbin/`
- Z-115 and Z-116 status versus commit `85d4713`
- `.agents/skills/setup-matt-pocock-skills/` has or lacks `SKILL.md`
- `.agents/skills/zoom-out/SKILL.md` has YAML description
- All zsynod files under `experiments/zsynod`

---

## Finding Format

```markdown
## <path>
Status: <recommendation>
Confidence: <high | medium | low>
Risk: <low | medium | high>
### Evidence
- Direct references:
- Indirect references:
- PATH / startup involvement:
- Tests:
- Docs:
- Human utility:
- AI / agent context utility:
- Git history notes:
- Related files:
- Stale references:
- Known gaps connected to this file:
### Recommendation
<clear recommendation>
### Rationale
<why>
### Future commit plan
No commit during dry run.
If later approved, make one surgical commit for this file or concern.
```

---

## Allowed Recommendations

`keep` `keep_with_note` `add_test` `add_docs`
`relocate_candidate` `delete_candidate` `rename_candidate`
`merge_candidate` `create_backlog_task` `close_backlog_task` `needs_human_review`

---

## Manifest Columns

`path` `directory` `file_type` `executable` `referenced_by`
`system_used` `human_useful` `ai_context_useful`
`test_coverage` `docs_coverage` `recommended_action` `confidence` `risk` `notes`

---

## Risk Model

**High:** MCP error handling, MCP tools returning decrypted content, keychain/encryption helpers,
PHI Scrubber, Message Hygiene Pipeline, shell startup, PATH mutation, agent skill discovery,
backlog/task automation, database or Knowledge Layer mutation, multi-persona tools

**Medium:** docs structure used by skills, ADR absence, missing skill frontmatter,
stale backlog status, untested CLI contracts, experiment files in production paths

**Low:** orphaned README fragments, stale notes with no references,
one-time installers with clear replacement, unused experiment scratch files

---

## Artifacts

```
audit/
audit/zdots-audit-manifest.tsv
audit/zdots-audit-findings.md
audit/zdots-audit-recommendations.md
audit/zdots-audit-zsynod.md
audit/zdots-audit-mcp.md
audit/zdots-audit-skills.md
audit/zdots-audit-docs-contract.md
audit/zdots-audit-backlog.md
audit/zdots-audit-commands.log
audit/zdots-audit-plan.json
```

---

## Stop Conditions

File `zdots-issue` and stop if:
- Shell startup reliability may be affected
- File may contain secrets or expose PHI
- File affects MCP access to decrypted content
- File affects keychain, encryption, or rekey behavior
- File is used by multiple agents
- Ownership is unclear
- Generated file has unknown generator
- Relocation requires broad reference updates
- Delete candidate has medium or high risk
- Test results contradict static analysis
- zdots tool behavior contradicts docs
- Destructive command would touch `$HOME`, `~`, `/`, `.`, `*`, or unresolved variables

---

## Dry-Run Boundary

**Allowed:** create files under `audit/`, read-only commands, run tests, inspect git history/docs, file `zdots-issue` on stop condition only.

**Not allowed:** edit production files, delete files, relocate files, change permissions, run migrations, change shell startup, change MCP registration, change secrets/keychain/encryption/PHI config, commit.

---

## Fan-Out Pattern

This skill fans out six parallel subagents:

| Agent | Scope | Primary Output |
|-------|-------|---------------|
| 1 | Orientation + `bin/` + `sbin/` | `audit/sections/bin-sbin.md` |
| 2 | Root files + `experiments/` | `audit/sections/root-experiments.md` |
| 3 | MCP | `audit/zdots-audit-mcp.md` |
| 4 | `.agents/skills` | `audit/zdots-audit-skills.md` |
| 5 | `tests/` + `docs/` | `audit/zdots-audit-docs-contract.md` |
| 6 | `backlog/` + zsynod | `audit/zdots-audit-backlog.md` + `audit/zdots-audit-zsynod.md` |

Coordinator synthesizes section files into `zdots-audit-findings.md`, `zdots-audit-manifest.tsv`, `zdots-audit-recommendations.md`, and `zdots-audit-plan.json`.
