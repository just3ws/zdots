---
id: decision-010
title: >-
  OKF adoption — zdots profile as knowledge interchange + authoring standard,
  riding the 009 envelope
date: '2026-06-28 16:33'
status: proposed
---
## Context

The platform's markdown knowledge surfaces — Claude memory files, `~/my/knowledge/`,
the wiki — each approximate a format by hand: YAML frontmatter, a `type`, links
between notes, an index file. There is no shared, named standard for that on-disk
shape, so each surface drifts and none is interchange-friendly.

Google's **Open Knowledge Format (OKF) v0.1**
(`GoogleCloudPlatform/knowledge-catalog/okf/SPEC.md`) is, almost exactly, a
formalization of that hand-rolled shape: Markdown + YAML frontmatter, one required
field `type` (open, producer-defined, "consumers tolerate unknown"), recommended
`title`/`description`/`resource`/`tags`/`timestamp`; *concepts* (`.md` files)
grouped into *bundles* (dirs) with reserved `index.md`/`log.md`; standard markdown
links forming an **untyped** directed graph; `okf_version` in the root `index.md`;
semver.

**The tension.** decision-009 (status: proposed) deliberately stores knowledge as
**data in the `my` Postgres DB** — "Markdown was never the right shape… no parallel
knowledge store; everything distills into the Loop tables." A naïve "OKF files =
source of truth" reading **is** the parallel store 009 forbids; adopting it that
way would silently re-litigate 009. OKF must **ride 009, not replace it.** The
conformant framing is already in 009 Part A: *"new source types are adapters behind
the envelope."*

## Decision

Adopt OKF v0.1 — **as a thin zdots profile** (doc-006) — as the platform's
knowledge **interchange and authoring standard**. OKF plays two roles, neither of
which touches 009's storage model:

**A. On-disk authoring convention** for the markdown that already exists. The DB is
not the place humans and agents *write* knowledge; OKF is the agreed shape for the
files that then flow into 009's envelope. Pilot: the Claude memory files — which
the pilot found are already a base-OKF bundle, binding OKF `type` via
`metadata.type` (the CC harness owns that frontmatter shape; see doc-006).

**B. A `source_type` adapter into 009's ingest envelope** (and, later, an export
format). A bundle's concept `.md` files each become a `source_document`
(`body_md` = the markdown body, frontmatter → `provenance`); the **type-bridge**
resolves OKF `type`/`tags` through `concept_alias` (009 Part B) to canonical
concept tags. The DB stays the single queryable store.

```
OKF files ──ingest adapter──▶ my DB (store, queryable)   [009 unchanged]
            ◀──export─────                                 [deferred]
```

**The type-bridge is the keystone.** OKF's deliberate laxness (open `type`,
tolerate unknown) and 009's `concept_alias` normalization compose exactly: the lax
producer format meets the normalizing consumer. The zdots profile (doc-006) pins
the lax bits — `type`/`tags` resolve through the concept registry; `timestamp`
becomes REQUIRED (Loop dedup); `[[slug]]` wikilinks are a permitted profile
extension equal to concept links.

## Consequences

- **Depends-on decision-009.** 009 is proposed, not accepted; this rides its
  envelope (`source_document`) and registry (`concept_alias`) and is sequenced
  after it. It ratifies nothing on its own.
- **Schema:** the profile is doc-006 (`backlog/docs/schema/`). The ingest adapter
  is **Z-174** (depends-on Z-150 source envelope + Z-151 concept registry — cannot
  precede them).
- **No parallel store.** OKF is wire format + authoring convention; everything
  still distills into the Loop tables. 009's storage model is unchanged.
- **PHI boundary unchanged:** ingest/export run the existing prepare→scrub path;
  any future DB→OKF export MUST scrub (distilled Loop content is PHI-adjacent).
- **`~/my` excluded from v1:** conforming `~/my/knowledge/` and the context-engine
  `markdown_inbox` parser is a later, PR-gated, coordinated pass (peer boundary).
- **Reversible & incremental:** the adapter lands one `source_type` behind a
  stable envelope. (Pilot lesson: the CC memory store is harness-managed — it
  binds OKF via `metadata.*`, not a top-level rewrite; doc-006.)
- **Open alternative (not taken):** files-as-truth (OKF bundles canonical, DB a
  rebuildable index — Obsidian/git+index). More portable, but reverses 009's
  storage choice; would be an *amendment to 009*, deferred to the operator.
