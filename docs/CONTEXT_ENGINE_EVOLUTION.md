# Context Engine Evolution Strategy

This document outlines the roadmap to elevate the Zdots "my" system from a basic knowledge vault into an agentic context engine, leveraging state-of-the-art RAG practices.

## Status: Production (2026-06-19)

context-engine is live in production at `my.local`. Key milestones reached this session:

- **Boot:** launchd-managed Puma (com.my.context-engine-api) at `/tmp/my_prod.sock`; nginx proxy at `my.local`
- **DB:** 8 context-engine tables migrated via `zdots-ctx migrate` (policy_*, markdown_inbox_*, policy_resolution_events, policy_gaps)
- **API:** `POST /api/v1/context/query` processes full request cycle; `PolicyResolutionEvent` and `PolicyGap` persisted
- **Dashboard:** Dark-themed landing page at `/` with stat cards, platform service links, API surface reference
- **Deploy:** `bin/deploy` — bundle → assets:precompile → restart → verify
- **Eliminated:** dev.my.local (nginx block removed, plist deleted, launchd unloaded)

Active gaps from the Quick Wins list (§2) remain open. Backlog items B-101 through B-104 are pre-production runway.

---

## 1. Architectural Philosophy
We are shifting from **Naive RAG** (semantic chunking) to **Agentic Context Engineering**:
- **Entity-Relational Reasoning**: Moving beyond chunks to understanding relationships (Graph-lite).
- **Agentic Loops**: Implementing retrieval evaluation and reranking.
- **Context Distillation**: Focusing on signal-to-noise ratio over total data volume.

---

## 2. Quick Wins (Refine Current System)
*Low-effort improvements that yield immediate precision gains.*

| Task | Description | Impact |
| :--- | :--- | :--- |
| **Enforce Entity Tagging** | Update `zdots-ctx ingest` process to explicitly extract key entities (e.g., Service names, Jira IDs) into JSONB metadata. | High precision for exact lookups. |
| **Transcript Hygiene** | Enforce a "Decision/Lesson" block in all transcript markdown before ingestion. | Immediately boosts signal quality in the context. |
| **Metadata Filtering** | Use the `sync_state` or `metadata` column in queries to prioritize newer docs over stale historical ones. | Reduces hallucination by favoring current truth. |
| **Interactive Query Refinement** | Add a `--refine` flag to `zdots-ctx query` that asks the LLM to rewrite the user prompt based on metadata before searching. | Significantly improves recall for ambiguous queries. |

---

## 3. Backlog (New Refinements)
*Architectural changes requiring deeper integration or new components.*

### [B-101] Implement Reranking Pass
- **Goal:** Implement a Cross-Encoder reranking step in the retrieval pipeline.
- **Detail:** After initial retrieval of $N$ documents, use a local lightweight reranker to pick the top $K$ most relevant snippets.

### [B-102] Graph-lite Association
- **Goal:** Enable cross-referencing between ADRs, backlog items, and lessons.
- **Detail:** Extend the ingest pipeline to parse internal markdown links or explicit entity references to build a lightweight relationship graph in the `Brain` database.

### [B-103] MCP Server Integration
- **Goal:** Allow the context engine to "talk" to live Rails platform services.
- **Detail:** Build an MCP server that exposes platform status, schema, or critical operational metrics to `zdots-ctx` via the Model Context Protocol.

### [B-104] Corrective RAG (CRAG) Loop
- **Goal:** Enable the agent to recognize insufficient context.
- **Detail:** Add an LLM "Evaluator" pass after retrieval. If the retrieved context scores poorly, trigger an automatic re-query or suggest manual intervention.

---

## 4. Implementation Guidelines
- **Security First**: All agentic loops must honor PHI/PII boundaries defined by the current `phi_scrubber` infrastructure.
- **Local-first**: Prioritize local inference (`llama.cpp`) for all agentic retrieval and evaluation steps.
- **Observability**: Every agentic step must emit a trace ID so failures (e.g., an LLM hallucination in retrieval) can be diagnosed via OpenObserve.
