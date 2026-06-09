# AI and Knowledge Layer

Primary commands:

- `ai-query`
- `zdots-ask`
- `zdots-ctx query`
- `zdots-ctx hydrate`
- `llama-ctl`

The default posture is local AI. `ZDOTS_AI_MODE=local` requires a loopback or RFC-1918 endpoint. Use `ZDOTS_AI_MODE=none` when inference must be disabled.

`zdots-ctx` writes through the app interface. Use `psql -U zdots_ro my` for read-only exploration.

## Agent Discovery Workflow

Use the knowledge base before claiming context is missing. It stores two primary
record types:

- `methodologies`: durable procedures, operating guides, forensics reports, and
  reference material.
- `lessons`: session residue and learned facts from prior work.

Start broad, then narrow:

```bash
zdots-ctx status
zdots-ctx query "search phrase"
zdots-ctx query --semantic "conceptual description"
zdots-ctx hydrate [tag]
```

Text query is exact-substring style over decrypted record content and titles. It
is useful for known words such as `forensics`, `postgres`, or a report title.
Semantic query embeds the prompt and ranks stored vectors; use it when wording is
uncertain or when looking for related process knowledge. Hydrate emits an
AI-ready context bundle, optionally filtered by tag.

Pi agents should use the capped wrappers instead of raw `zdots-ctx`:

```bash
pi-ctx-status
pi-ctx-query "forensics"
pi-ctx-query "delivery process risk" --semantic
pi-ctx-hydrate github
```

## Landing New Knowledge

Use the app interface for writes; do not write KB rows directly with SQL.

```bash
zdots-ctx add-methodology <slug> <title> <content-file> [tags...]
zdots-ctx add-lesson <content> [context] [tags...]
zdots-ctx ingest <file.md | dir/>
```

For generated reports, success means more than "the command exited 0". Verify
all three layers:

1. Storage: the record exists in `my`, content is encrypted, and tags/title/slug
   identify it.
2. Embedding: the corresponding `embed` job completed and the record has a
   non-null vector.
3. Retrieval: both text or tag-based discovery and semantic discovery can find
   the record.

Read-only verification examples:

```bash
rtk psql -d my -c \
  "select slug, title, tags, embedding is not null as has_embedding,
          octet_length(content_enc) as encrypted_bytes
     from methodologies
    where slug like '%github%' or title ilike '%github%';"

rtk psql -d my -c \
  "select status, count(*) from jobs where type='embed' group by status;"

zdots-ctx query "forensics"
zdots-ctx query --semantic "delivery process forensics"
```

If text search misses an exact slug but semantic search finds the record, check
the model search fields before assuming ingestion failed: text search scans
decrypted content and title, not every metadata field. If semantic search misses
and the vector is null or the embed job failed, fix the embed path or requeue via
`zdots-ctx requeue <job_id>` after the underlying issue is resolved.

## GitHub Analysis Example

`zdots-gh run <owner> --html` produces delivery-health and process-forensics
reports, then ingests them into the knowledge base.

Expected verification for `phalanxduel`:

```bash
zdots-ctx query "forensics"
zdots-ctx query "GitHub Delivery Health"
zdots-ctx query --semantic "delivery process forensics phalanxduel"
```

The semantic query should return both `gh-forensics-<owner>` and
`gh-delivery-health-<owner>`. The embed queue should have no pending or dead
`embed` jobs before the work is considered landed.
