---
id: Z-034
title: Configure targeted GitHub tokens for Mise and Homebrew
status: To Do
assignee: []
created_date: '2026-04-04 22:30'
labels:
  - setup
  - security
  - manual-action
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Following the architectural update to support targeted GitHub tokens, the user needs to manually create and populate their secrets file. This reduces the security surface area by ensuring each tool uses a token with the minimum necessary permissions rather than a single global GITHUB_TOKEN.

### Configuration Files
- **Template:** `.zdots.secrets.example` (Tracked in Git)
- **Active Secrets:** `.zdots.secrets` (Git-ignored, stored in `$ZDOTDIR`)

### Tokens to Define
1. **`HOMEBREW_GITHUB_API_TOKEN`**: Used for Homebrew rate limits and formula metadata.
2. **`MISE_GITHUB_TOKEN`**: Used by Mise for downloading plugins and tool manifests.
3. **`GITHUB_TOKEN`**: (Optional) General fallback for other tools.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `.zdots.secrets` is created from `.zdots.secrets.example`
- [ ] #2 `HOMEBREW_GITHUB_API_TOKEN` is defined with a targeted token (metadata:read)
- [ ] #3 `MISE_GITHUB_TOKEN` is defined with a targeted token (contents:read)
- [ ] #4 Verify `mise` and `brew` pick up the tokens in a new shell session
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
