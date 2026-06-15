---
id: doc-004
title: Knowledge Ingestion & Terminology Schema
type: specification
created_date: '2026-06-15 01:50'
---
# Knowledge Ingestion & Terminology Schema

The concrete schema behind **decision-009**. Two halves — a **source envelope** in
front of the Virtuous Loop, and a **concept registry** beside it — joined by
concept tagging so the knowledge base is *linked and traversable*, not just
searchable.

Store: PostgreSQL `my`. Owner `zdots-brain` via Sequel migrations in
`db/migrations/`. Read via `zdots_ro`; write via `zdots-ctx`. New tables ship as
one migration and register in `zdots_schema_migrations`.

## Part A — Source envelope (ingestion)

One normalized record for every source type. New types are adapters behind the
envelope, never new commands.

### `source_document`

| column | type | notes |
|---|---|---|
| `id` | bigserial PK | |
| `uri` | text | canonical source locator (URL, file path) |
| `source_type` | text | `youtube` `playlist` `webpage` `pdf` `docx` `vtt` |
| `title` | text | resolved title |
| `checksum` | text | content hash — dedupe + change detection |
| `provenance` | jsonb | channel/author, duration, fetch tool, license |
| `body_md` | text | normalized markdown — the uniform output contract |
| `fetched_at` | timestamptz | |
| `ingested_at` | timestamptz | null until distilled into the Loop |

**Adapters** (resolve to `body_md`):
- `youtube` — transcript pull → markdown (timestamped sections).
- `playlist` — fan-out to N `youtube` rows sharing a `provenance.playlist_id`.
- `webpage` — readability extraction → markdown.
- `pdf`/`docx`/`vtt` — the existing `zdots-ingest-prepare` path, unchanged.

**Flow:** `zdots ctx ingest <uri>` → adapter → `source_document` →
distill into `session_residue`/`lessons`/`methodologies` (existing Loop) →
concept-tag (Part B) → set `ingested_at`.

## Part B — Concept registry (terminology)

The synonym→concept map and ontology as **data** — the real form of the
`GLOSSARY.md`/`ONTOLOGY.md` that AGENTS.md §9 references but never had.

### `concept` — canonical terms

| column | type | notes |
|---|---|---|
| `id` | bigserial PK | |
| `slug` | text unique | stable id, e.g. `seam`, `platform-service` |
| `term` | text | display form, e.g. "Seam" |
| `definition` | text | from AGENTS.md §9 / CONTEXT.md |
| `source_ref` | text | where it's defined (CONTEXT.md anchor) |

### `concept_alias` — the synonym map

| column | type | notes |
|---|---|---|
| `id` | bigserial PK | |
| `alias` | text | the non-canonical word, e.g. "boundary" |
| `concept_id` | bigint FK → concept | resolves to the canonical concept |
| `disallowed` | boolean | true = AGENTS.md "Do NOT use" term (warn on use) |

Unique on `lower(alias)`. Resolution: any incoming term is lowercased and looked
up here; a hit rewrites to the concept slug. "boundary"/"interface"/"facade" →
`seam`.

### `concept_link` — the traversable ontology

| column | type | notes |
|---|---|---|
| `id` | bigserial PK | |
| `from_concept_id` | bigint FK → concept | |
| `to_concept_id` | bigint FK → concept | |
| `relation` | text | `is-a` `part-of` `relates-to` |

Directed, typed edges → walkable graph. `methodology --is-a--> knowledge-unit`,
`phi-scrubber --part-of--> message-hygiene-pipeline`.

### Tag join — links ingestion to the graph

| column | type | notes |
|---|---|---|
| `concept_id` | bigint FK → concept | |
| `target_kind` | text | `source_document` `lesson` `methodology` `session_residue` |
| `target_id` | bigint | row in that table |

This join is the coherence: ingested material is tagged with canonical concepts,
so the KB is traversable by concept across every Loop table.

## Verb surface (decision-008 grammar)

All under `zdots-ctx` (→ `zdots ctx`), `--json` on every leaf:

```
zdots ctx ingest <uri> [--type auto]      # source envelope → Loop → concept-tag
zdots ctx concept <slug>                  # definition + aliases + links
zdots ctx concept add <slug> --term … --def …
zdots ctx concept alias <alias> <slug> [--disallowed]
zdots ctx concept link <from> <relation> <to>
zdots ctx concept resolve <word>          # synonym → canonical slug
```

## Seeding & rollout

1. Migration creates the five tables (one Sequel migration).
2. Seed `concept`/`concept_alias` from AGENTS.md §9's ~14 core terms (incl. their
   "Do NOT use" lists as `disallowed` aliases).
3. Source adapters land one `source_type` at a time behind the stable envelope —
   `webpage` first (simplest), then `youtube`, then `playlist` (fan-out).
4. AGENTS.md §9 updated: `GLOSSARY.md`/`ONTOLOGY.md` references → `zdots ctx concept`.

## Boundaries

- **PHI:** URL fetches add network egress; they must pass `ai_boundary` locality
  rules and must never carry PHI into a remote request. Ingestion runs through the
  existing prepare → scrub path.
- **Convergence:** no parallel knowledge store; everything distills into the
  existing Loop tables. No new top-level binary — only nouns/verbs under the spine.
