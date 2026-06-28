---
id: doc-006
title: zdots OKF Profile — Open Knowledge Format v0.1 profiled for the platform
type: specification
created_date: '2026-06-28 16:33'
---
# zdots OKF Profile

The concrete profile behind **decision-010**. A thin specialization of
**Open Knowledge Format (OKF) v0.1**
(`GoogleCloudPlatform/knowledge-catalog/okf/SPEC.md`) for this platform. OKF is
adopted unchanged as the on-disk shape; this profile only *pins the lax bits* so
that bundles ride the **decision-009** envelope and concept registry cleanly.

Conformance to base OKF is preserved: a zdots-profile bundle is a valid OKF
bundle. The profile adds requirements, never removes OKF's tolerances.

## Base OKF v0.1 (unchanged)

- Markdown + YAML frontmatter, UTF-8. One **required** field: `type` (non-empty).
- Recommended: `title`, `description`, `resource` (URI), `tags` (list), `timestamp`
  (ISO 8601).
- *Concepts* = `.md` files; *bundles* = directories. Reserved `index.md` (listing,
  no frontmatter) and `log.md` (dated change history). Root `index.md` may carry
  `okf_version`.
- Links = standard markdown → untyped directed graph. Broken links tolerated.
- Conformance: parseable frontmatter + non-empty `type` in every non-reserved
  `.md`; consumers must not reject on unknown types/keys/missing optionals.

## zdots profile pins

| OKF says | zdots profile pins | Why |
|---|---|---|
| `type` open, unknown tolerated | `type` **SHOULD** resolve through the concept registry (`concept_alias` → canonical slug). Unknown types are tolerated **and logged** for registry curation. | The **type-bridge** — links OKF to the 009 ontology |
| `tags` = free strings | `tags` are concept slugs; resolved via `concept_alias` on ingest | tags become traversable concept edges, not free text |
| `timestamp` recommended | `timestamp` **REQUIRED** (ISO 8601) | Loop dedup / change-detection (`source_document.checksum` + `fetched_at`) |
| links = standard markdown, untyped | `[[slug]]` wikilinks **permitted** as a profile extension; semantically = concept links | matches how memory files already link; resolves to concept slugs |
| `okf_version` in root `index.md` | unchanged — `okf_version: "0.1"` | bundle conformance marker |
| (none) | **PHI:** ingest/export run the existing prepare→scrub path; DB→OKF export MUST scrub | distilled Loop content is PHI-adjacent |

## The type-bridge (keystone)

OKF's deliberate laxness (open `type`, "tolerate unknown") and 009's
`concept_alias` normalization compose exactly — the lax *producer* format meets the
normalizing *consumer*:

```
OKF frontmatter type/tags  ──lowercase──▶ concept_alias lookup
   "Seam" / "boundary" / "interface"          │
                                              ▼
                                    canonical concept slug  →  concept tag (009)
   (no match) ──▶ tolerated + logged for registry curation
```

This is the same resolution doc-004 Part B already specifies for ingestion; the
adapter reuses it rather than inventing tag handling.

## Mapping: OKF → decision-009 store (doc-004)

| OKF | decision-009 / `my` DB |
|---|---|
| concept document (`.md` + frontmatter) | `source_document` (`body_md` = body; frontmatter → `provenance`) → distilled `lesson`/`methodology` |
| frontmatter `type` | type-bridge → `concept` (via `concept_alias`) |
| frontmatter `tags` | concept tag join (`concept_id` → target) |
| markdown / `[[slug]]` links | concept tags in v1 (untyped); `concept_link` typed edges deferred |
| `okf_version` (root `index.md`) | bundle conformance marker (not stored) |
| reserved `log.md` | change history (≈ `session_residue` trail) |
| `# Citations` → `references/` | `provenance` / source refs |

## Bundle shape (profile-conformant)

```
bundle_root/
├── index.md          # OKF index + okf_version: "0.1"  (sole frontmatter in index)
├── log.md            # optional; dated history, newest first
├── <concept>.md      # type: <resolves via concept_alias>; timestamp REQUIRED
└── <subdir>/ …
```

## Reference bundle: the Claude memory store (pilot finding)

The agent's memory store (`~/.claude/projects/.../memory/`) was the v1 pilot. The
empirical finding redefined the binding: **the Claude Code harness owns this
bundle's frontmatter shape.** Writes through the memory path are normalized to
`name` / `description` / `metadata.{node_type, type, title, timestamp,
originSessionId}` — any top-level key other than `name`/`description` is relocated
under `metadata`. A literal top-level-`type` rewrite does not survive.

So a **harness-managed bundle binds OKF fields under `metadata.*`**:

- OKF `type` ← `metadata.type` (already present on every file — the store was
  *already* a base-OKF bundle by this mapping, before any edit).
- OKF `title`/`timestamp` ← `metadata.title`/`metadata.timestamp` (harness accepts
  these into `metadata`).
- `okf_version` ← `metadata.okf_version` (the harness nests even index frontmatter;
  marking it on the index is optional and not worth fighting — omitted here).
- `[[wikilinks]]` conform as the profile's link extension.

**Profile rule — harness-managed bundles:** a consumer MUST read OKF fields from
`metadata.*` when top-level is absent. The `timestamp` REQUIRED rule applies to
**ingested** bundles (Loop dedup); the CC memory store is not Loop-ingested, so it
conforms at the base-OKF bar (`type` present via `metadata.type`).

## Boundaries

- **Depends-on decision-009** (proposed). Rides its envelope + registry; does not
  introduce a parallel store.
- **`~/my` excluded from v1** — coordinate, don't reach. `~/my/knowledge/`
  conformance + context-engine `markdown_inbox` OKF parsing are a later PR-gated pass.
- **Deferred ("add when"):** conformance linter `zdots ctx okf lint`; DB→OKF
  export (file-back loop, must scrub); prose→typed-relation inference (v1 ingests
  links as untyped concept tags).
