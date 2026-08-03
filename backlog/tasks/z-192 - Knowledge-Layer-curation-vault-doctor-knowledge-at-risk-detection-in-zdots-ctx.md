---
id: Z-192
title: >-
  Knowledge Layer curation: vault-doctor + knowledge-at-risk detection in
  zdots-ctx
status: Done
assignee: []
created_date: '2026-07-01 23:21'
updated_date: '2026-08-03 16:45'
labels:
  - feature
  - platform-service
dependencies: []
priority: low
ordinal: 88890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
work-vault-doctor (Obsidian vault structural health) and work-knowledge-map (knowledge-at-risk detection + capture) are Knowledge Layer curation — zdots-ctx territory, generalizable to every vault the platform ingests. Also converges with the 'lessons with teeth' self-improvement move: curation passes that ask what standing check makes each lesson un-forgettable. Add zdots-ctx verbs (or a zdots-vault-doctor) for vault integrity (broken links, orphans, structure) and knowledge-at-risk surfacing, vault-agnostic.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Vault structural health check runs against any vault path (links, orphans, structure)
- [x] #2 Knowledge-at-risk detection surfaces stale/undocumented areas as review candidates
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Rules-first, local-LLM-last design (same shape proven elsewhere for doc-pruning queues):

1. **Cheap rule pass over every doc/lesson** — no deep parsing, just frontmatter + a
   chunk + a link scan. Score on: age vs. cadence, verdict/review overdue, broken
   wikilinks (dangling `[[refs]]`), unverified markers (`TODO`/`FIXME`/`[unverified]`),
   thin content (below a word-count floor) or oversized (split candidate), orphan
   (no inbound links, excluding known index files).
2. **Band into action tiers** (ok / watch / review / address) by score, write a
   priority-sorted queue (ndjson or a `my` table) with which rules fired + why, so a
   human or a later Claude pass knows the reason without re-deriving it.
3. **Local LLM is OFF by default and LAST** — escalate only the top-N
   already-flagged, ambiguous items to `ai-query` for a one-sentence clue
   ("this needs REVIEW/UPDATE/PRUNE/SPLIT and why"). Never used for the scoring
   itself; cache clues by `path::score` so re-runs don't re-spend tokens on
   unchanged docs.
4. **Vault-agnostic**: accept any vault/corpus path — zdots' own doc corpus
   (AGENTS.md, docs/*.md, backlog/docs/*) and the `my` Knowledge Layer (lessons,
   methodologies) are the two first targets, but the tool takes a path, not a
   hardcoded location.
5. Self-check mode with inline fixtures (offline, no live vault needed) — same
   bar as every other zdots command's contract test.

Land as `zdots-ctx vault-doctor [path] [--json] [--llm]` (verb on the existing
tool) rather than a new standalone binary, matching how `zdots-ctx concept`/`hydrate`
already extend the same command family.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Built `zdots-ctx vault-doctor` (bin/zdots-vault-doctor, delegated via zdots-ctx) — rules-first, local-LLM-last asset catalog over any markdown corpus.

Rules: stale (mtime/frontmatter vs cadence), broken relative markdown links, unverified markers, thin/oversized word count, orphan (no inbound links) — banded into ok/watch/review/address.

Beyond the original scope: a durable per-asset registry (identifier + content hash + score/action history) and an append-only event log, so re-runs only record what actually changed, not a stateless rescan. `--ack <id> [--note]` records a human disposition that silences a finding until the content itself changes; `--history <id>` replays an asset's full evaluation/disposition trail. This is the asset-catalog shape (identifier + context + history of evaluations/dispositions), scaled to a JSON registry + ndjson log — no new database.

`--llm` escalates only the top-N already-flagged assets to `ai-query` for a one-sentence clue, cached by path+content-hash so unchanged assets never re-spend tokens.

Verified live against zdots' own doc corpus (99 assets, 62 flagged, LLM clues generated correctly, --ack/--history round-tripped). Full quality gate: --help, man page (zdots-man-gen), zsh completion, docs/tooling.md, bats self-check + 6 contract tests, docs-contract (15/15 passing).
<!-- SECTION:FINAL_SUMMARY:END -->
