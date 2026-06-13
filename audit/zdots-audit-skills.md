# Audit: Agent Skills
Generated: 2026-06-13
Agent: main-session

---

## Inventory

### .agents/skills/ (source truth, used by multiple agents)

| Skill | SKILL.md | Extra files | YAML frontmatter |
|-------|----------|-------------|-----------------|
| caveman | ✓ | — | yes |
| diagnose | ✓ | scripts/hitl-loop.template.sh | yes |
| github-kb-analysis | ✓ | VALIDATION.md | yes |
| grill-me | ✓ | — | yes |
| grill-with-docs | ✓ | ADR-FORMAT.md, CONTEXT-FORMAT.md | yes |
| handoff | ✓ | — | yes |
| improve-codebase-architecture | ✓ | DEEPENING.md, HTML-REPORT.md, INTERFACE-DESIGN.md, LANGUAGE.md | yes |
| prototype | ✓ | LOGIC.md, UI.md | yes |
| setup-matt-pocock-skills | ✓ | domain.md, issue-tracker-github.md, issue-tracker-gitlab.md, issue-tracker-local.md, triage-labels.md | yes |
| tdd | ✓ | deep-modules.md, interface-design.md, mocking.md, refactoring.md, tests.md | yes |
| to-issues | ✓ | — | yes |
| to-prd | ✓ | — | yes |
| triage | ✓ | AGENT-BRIEF.md, OUT-OF-SCOPE.md | yes |
| write-a-skill | ✓ | — | yes |
| zdots | ✓ | — | yes |
| zoom-out | ✓ | — | yes |

16 skills. All have SKILL.md. All have YAML frontmatter.

### .claude/commands/ (Claude Code skill files)

21 files. These mirror .agents/skills/ entries plus zdots-specific commands.

---

## Known Finding Verification

### setup-matt-pocock-skills: has or lacks SKILL.md
**HAS SKILL.md** ✓
- Valid YAML frontmatter with `name`, `description`, `disable-model-invocation: true`
- Contains: domain.md, issue-tracker variants, triage-labels.md
- Referenced in CLAUDE.md section "Agent Skills"

### zoom-out: SKILL.md has YAML description
**YES, has YAML description** ✓
```yaml
---
name: zoom-out
description: Tell the agent to zoom out and give broader context or a higher-level perspective...
disable-model-invocation: true
---
```

### grill-with-docs depends on ADRs
**YES** — multiple references to `docs/adr/`:
- "updates documentation (CONTEXT.md, ADRs) inline"
- Shows tree structure with `docs/adr/`
- "Create files lazily — only when you have something to write. If no `docs/adr/` exists, create it when the first ADR is needed."
- Since docs/adr/ EXISTS with 2 ADRs, this skill is correctly wired.

### improve-codebase-architecture depends on ADRs
**YES** — description field explicitly: "informed by the domain language in CONTEXT.md and the decisions in docs/adr/"
- Since docs/adr/ EXISTS, this skill is correctly wired.

---

## Per-Skill Findings

## .agents/skills/grill-with-docs
Status: keep
Confidence: high
Risk: low
### Evidence
- ADR dependency: YES — references docs/adr/ (exists ✓)
- CONTEXT.md dependency: YES — references CONTEXT.md (exists ✓)
- Tests: none (skills don't have unit tests by design)
- Frontmatter: valid
### Recommendation
keep
### Rationale
Dependencies present. Frontmatter valid. No staleness evidence.

---

## .agents/skills/improve-codebase-architecture
Status: keep
Confidence: high
Risk: low
### Evidence
- ADR dependency: YES — description references docs/adr/
- docs/adr/ EXISTS with 2 ADRs
- Frontmatter: valid
### Recommendation
keep

---

## .agents/skills/setup-matt-pocock-skills
Status: keep
Confidence: high
Risk: low
### Evidence
- SKILL.md: EXISTS
- Referenced in CLAUDE.md
- Subdocs: issue-tracker variants (github/gitlab/local) + triage-labels + domain.md
- Frontmatter: valid
### Recommendation
keep

---

## .agents/skills/zoom-out
Status: keep
Confidence: high
Risk: low
### Evidence
- SKILL.md: EXISTS
- YAML description: valid
- `disable-model-invocation: true` — correct (lightweight navigation prompt)
### Recommendation
keep

---

## .claude/commands/zdots-audit.md (NEW — this session)
Status: keep
Confidence: high
Risk: low
### Evidence
- Created this session to formalize the audit skill
- Appears in session-reminder skills list as `zdots-audit`
- Not yet in .agents/skills/ — only in .claude/commands/
### Recommendation
keep_with_note — consider adding to .agents/skills/ with SKILL.md if multi-agent use is intended.

---

## .DS_Store files in .agents/
Status: delete_candidate
Confidence: high
Risk: low
### Evidence
- `.agents/.DS_Store` and `.agents/skills/.DS_Store` are macOS metadata files
- Should be in .gitignore
### Recommendation
delete_candidate — check if .gitignore covers `**/.DS_Store`
### Future commit plan
No commit during dry run.

---

## Summary

All 16 skills have SKILL.md and valid YAML frontmatter.
Both known ADR-dependent skills (grill-with-docs, improve-codebase-architecture) are correctly wired — docs/adr/ exists.
No stop conditions hit.

**One gap:** `github-kb-analysis` skill is in .agents/skills/ but does NOT appear in the .claude/commands/ directory. It may be present for other agents but not exposed to Claude Code. Needs verification if it's intentionally excluded.
