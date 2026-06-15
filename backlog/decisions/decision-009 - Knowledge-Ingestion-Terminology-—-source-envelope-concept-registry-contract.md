---
id: decision-009
title: >-
  Knowledge Ingestion & Terminology — source envelope + concept registry
  contract
date: '2026-06-15 01:50'
status: proposed
---
## Context

Two felt needs, one disease — the Knowledge Layer's version of the command-surface
fragmentation (decision-008):

1. **Heterogeneous ingestion is partial.** `zdots-ingest-prepare` normalizes
   PDF/docx/VTT → markdown → `zdots-ctx ingest`. But there is no path for the
   sources actually wanted: a **YouTube video, a playlist, or a webpage**. Each new
   source type risks becoming a new bespoke entry point (the same proliferation the
   command surface suffers).

2. **The same concept wears different words.** AGENTS.md §9 defines a formal
   vocabulary and references `GLOSSARY.md`/`ONTOLOGY.md` — but **those files do not
   exist**. There is no machine surface that maps synonyms to a canonical concept,
   so "Seam" / "boundary" / "interface" fragment the knowledge base, and ingested
   material can't be linked or traversed by concept. Markdown was never the right
   shape: a glossary you can't query is not traversable.

The KB store already holds the Virtuous Loop: `session_residue → lessons →
methodologies` (+ `recommendations`, `operational_feedback`). The gap is an
**ingestion envelope** in front of it and a **concept registry** beside it.

## Decision

Adopt **one source envelope** for ingestion and **one concept registry** for
terminology — both as data in the `my` KB, queryable through `zdots-ctx`. The
ingestion side *tags* content with canonical concept slugs; the registry makes
those tags consistent and traversable. That linkage is the coherence.

**A. Source envelope (ingestion contract).** Every source — `youtube`, `playlist`,
`webpage`, `pdf`, `docx`, `vtt` — resolves through one preprocessor to a single
normalized record before it touches the Loop:

- A `source_document` carries `uri`, `source_type`, `title`, `fetched_at`,
  `checksum`, `provenance`, and normalized `body_md`.
- New source types are **adapters behind the envelope**, never new top-level
  commands (convergence over proliferation — same rule as decision-008).
- YouTube/playlist transcripts and webpage readability extraction normalize to the
  same `body_md` the existing `.vtt`/`.pdf` path produces.
- Ingested documents are distilled into the existing Loop tables; they do not get
  a parallel store.

**B. Concept registry (terminology contract).** The synonym→concept map and the
ontology become **data**, replacing the fictional `GLOSSARY.md`/`ONTOLOGY.md`:

- `concept` — canonical term: `slug`, `term`, `definition`, `source` (CONTEXT.md
  reference). One row per load-bearing term in AGENTS.md §9.
- `concept_alias` — `alias` → `concept_id`. The synonym map ("boundary" → `seam`).
- `concept_link` — `from_concept_id` → `to_concept_id`, typed `relation`
  (`is-a`, `part-of`, `relates-to`). The traversable ontology graph.
- Ingested/distilled records are tagged with `concept` slugs; aliases resolve on
  ingest so different words land on the same concept.

**C. One verb surface.** Both live under `zdots-ctx` (→ `zdots ctx` per
decision-008): `zdots ctx ingest <uri>`, `zdots ctx concept <slug>`,
`zdots ctx concept link …`, all `--json`.

The full schema (tables, columns, edge types, resolution flow) is specified in
**doc-004** (`backlog/docs/schema/`).

## Consequences

- **`GLOSSARY.md`/`ONTOLOGY.md` references in AGENTS.md §9 are resolved by data,
  not by writing the missing markdown.** AGENTS.md is updated to point at
  `zdots ctx concept` as the canonical lookup. (Sister fix to decision-008's
  reconciliation of the command docs.)
- **Tasks:** Z-150 (source envelope: URL/YouTube/playlist/webpage adapters) and
  Z-151 (concept registry: tables + `zdots ctx concept` verbs). Both depend on the
  existing `zdots-ctx`/`zdots-schema` migration path and sit downstream of the
  Knowledge spine (Z-135 Runtime-insight loop).
- **Linked & traversable:** concept tagging connects ingestion to the ontology
  graph, so the KB can be walked by concept, not just full-text searched.
- **PHI boundary unchanged:** ingestion runs through the existing prepare → scrub
  path; webpage/transcript fetches add a network egress step that must respect
  `ai_boundary`/locality rules and never carry PHI into a remote fetch.
- **Reversible & incremental:** registry seeds from AGENTS.md §9's ~14 core terms;
  source adapters land one type at a time behind the stable envelope.
