---
id: Z-275
title: Evaluate RTK proxy gaps from current usage
status: To Do
assignee: []
created_date: 2026-08-01 09:57
updated_date: '2026-10-31T22:34:00Z'
labels:
  - enhancement
  - audit-filed
dependencies: []
priority: medium
ordinal: 151895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 2026-08-02 usage review corrected the adoption estimate: RTK hook integrations already provided 96.2% aggregate savings over 39k commands. Remaining candidates were unsupported git subcommands and user habits that fall through to rtk proxy. This is a provider-independent tooling review; the old Claude Code hook framing no longer applies. Recheck current RTK version and usage before proposing local changes or upstream requests.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Refresh the RTK proxy usage summary for a configurable recent window without exposing raw command strings.
- [ ] #2 Compare frequent proxy patterns with current RTK native handlers and recommend only evidence-backed local or upstream work.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
- [ ] #4 Use a privacy-preserving configurable history window; do not publish raw command strings.
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ADOPTION STORY CORRECTED (2026-08-02): rtk gain reports 96.2% aggregate savings over 39k commands — the hook path does the heavy lifting (rtk grep 7,719 calls / 1.0GB tokens saved; rtk read 4,003 / 505MB). The earlier 5.2% figure measured explicit interactive rtk usage only. Remaining real gaps: rtk proxy git (411) = hook fallback for git subcommands without native handlers (upstream handler wishlist), and agent-habit rtk proxy rg — now obsolete since the 'mangling' was the rg -r flag error (Z-285). Re-scope this task to: file the git-subcommand handler wishlist upstream; drop the adoption-drive framing.

2026-10-31 scope correction: Claude-specific hook language removed. Keep this as a low-priority usage-backed review; no local matcher changes are authorized by the old report alone.
<!-- SECTION:NOTES:END -->
