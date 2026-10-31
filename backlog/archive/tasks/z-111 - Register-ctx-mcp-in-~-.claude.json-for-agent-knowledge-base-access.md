---
id: Z-111
title: Register ctx-mcp in ~/.claude.json for agent knowledge-base access
status: Done
assignee: []
created_date: '2026-05-27 16:52'
updated_date: '2026-05-27 17:14'
labels:
  - manual-step
  - agent-ready
dependencies: []
modified_files:
  - bin/ctx-mcp-register
priority: high
ordinal: 5890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ctx-mcp (bin/ctx-mcp) exists and works but is not registered as an MCP server in ~/.claude.json. Until registered, AI agents cannot query the zdots knowledge base (lessons, methodologies, session residue) during sessions.

Manual registration — run once as operator:
```python
python3 -c "
import json, os
p = os.path.expanduser('~/.claude.json')
d = json.load(open(p))
d.setdefault('mcpServers', {})['ctx'] = {
  'type': 'stdio',
  'command': os.path.expanduser('~/.config/zsh/bin/ctx-mcp'),
  'env': {'ZDOTDIR': os.path.expanduser('~/.config/zsh')}
}
json.dump(d, open(p, 'w'), indent=2)
print('ctx-mcp registered')
"
```

Automated modification of ~/.claude.json is blocked by Claude Code's auto-mode classifier — operator must run this manually.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ctx-mcp appears in ~/.claude.json mcpServers
- [x] #2 Claude Code session shows ctx MCP server connected
- [x] #3 zdots-ctx query returns results via MCP
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Registered ctx-mcp in ~/.claude.json via new bin/ctx-mcp-register script. Script is idempotent (--force to overwrite), uses jq for safe JSON manipulation, and guards against missing claude.json or non-executable server binary. MCP tools (ctx_query, ctx_hydrate, ctx_enqueue, ctx_status, living_docs) confirmed live in session.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
