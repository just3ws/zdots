---
id: Z-326
title: >-
  [agent-issue] Evaluate and plan integration of historical conversation corpus
  (chatgpt-dump) into zdots-brain: in-
status: To Do
assignee: []
created_date: '2026-08-29 15:48'
labels:
  - agent-reported
  - request
dependencies: []
priority: low
ordinal: 201895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** low
**Trace ID:** `16682dee1b64574038be68803dac69a1`

### Summary & Architecture Assessment: ChatGPT Corpus & Career History Search

**Corpus Scope:** 1,493 conversations / 32,385 messages (~150MB uncompressed) across multiple career eras (Architect, Associate Director Staff, Senior Staff).

#### 1. Engine Evaluation (OpenSearch vs. zdots-brain vs. SQLite/DuckDB)

- **OpenSearch (Rejected)**:
  - High memory footprint (1–2+ GB JVM heap idle) and launchd daemon management overhead.
  - Isolated silo outside `zdots-brain` / PostgreSQL control plane and PHI scrubber.
  - Unnecessary for 32k records where sub-5ms latency is achieved in-process.

- **Option 2: Native `zdots-brain` (Target Permanent Home)**:
  - Direct integration into `my` PostgreSQL (`zdots-ctx`, `zdots-brain`).
  - Hybrid search via Reciprocal Rank Fusion (RRF): `pgvector` (cosine distance `<=>`) + PostgreSQL FTS (`tsvector` + GIN).
  - Encrypted fields (`content_enc`), local embeddings via `zsvc embed` (127.0.0.1:11501), OTel telemetry.
  - Links raw conversation turns directly to `methodologies`, `lessons`, and career claims (`CAREER_WIKI.md`).

- **Option 3: In-Situ SQLite FTS5 + DuckDB (Immediate Working Solution)**:
  - Local to `/Volumes/Dock_1TB/chatgpt-dump-2026-03`.
  - Zero daemon overhead, portable file-based DB.
  - FTS5 BM25 lexical search + DuckDB analytics + CLI mining and pruning tool.
  - Serves as the interactive curation and staging workbench before migrating pruned high-signal records to Option 2.

#### 2. Staged Rollout Strategy

1. **Phase 1 (Immediate In-Situ Mining)**:
   - Build `career_query.py` / CLI suite on the external drive using existing SQLite FTS5 (`chatgpt_corpus.db`) and DuckDB (`chatgpt_corpus.duckdb`).
   - Implement filters for quarter, date, role era, speaker, min length, and career themes (e.g. `OTel`, `clarity_`, `Moty`, `Remediation`, `Geekfest`).
   - Implement structured staging/export (`--stage-for-zdots`) to export curated candidate turns/milestones into clean JSON/Markdown.

2. **Phase 2 (Curation & Refinement)**:
   - User reviews, prunes, and annotates key historical milestones and defensible career claims.
   - Run local PHI scrubber before ingestion.

3. **Phase 3 (zdots-ctx / PostgreSQL Migration)**:
   - Apply migration in `~/.config/zsh/etc/db/migrations/` for `career_archive` / `conversation_turns`.
   - Batch ingest pruned records into `my` Postgres DB with embeddings from `zsvc embed`.
   - Wire into `zdots-ctx query --career` and `zdots-ask`.

---
*Filed via `zdots-issue`. Updated with operator architectural analysis.*
<!-- SECTION:DESCRIPTION:END -->
