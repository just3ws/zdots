# Documentation Inventory & Karpathy-Style Mapping

This inventory maps existing Zdots documentation into the "Infinite Brain" (AI OS) taxonomy.

## Entity Types
- **Agent**: Defines persona, goals, constraints (e.g., triage, coder).
- **Skill**: Defines capabilities, workflow rules, tools (e.g., tdd, diagnose).
- **Workflow**: Step-by-step procedures (e.g., onboarding, deployment).
- **Knowledge**: Domain-specific facts, rules, context (e.g., architecture, security).
- **Output**: Logs, reports, artifacts created by agents.

---

## Inventory Report

| Path | Taxonomy | Recommendation |
| :--- | :--- | :--- |
| `docs/architecture.md` | Knowledge | Convert to Mermaid-based "System Map" for LLM ingestion. |
| `docs/agents/` | Agent | Formalize as "Source Code" for the platform's autonomous personality. |
| `docs/wiki/` | Knowledge | Aggregate into a "Compact" format; currently too verbose for token budget. |
| `backlog/` | Workflow | Bridge to agents using structured JSON or YAML task manifests. |
| `etc/prompts/` | Agent | These *are* the "System Prompts." Move to `/docs/agents/`. |
| `docs/adr/` | Knowledge | Mark as "Immutable Core" (First Principles) for ingestion. |
| `sandbox/karpathy-method/`| Knowledge | Move to `/docs/research/karpathy/`. |
| `processed/` | Output | Archive to `/backlog/outputs/`. |

## Strategic Recommendations
1. **The "Compact" Principle:** Documentation must move from "Human-readable prose" (currently most of `/docs`) to "Agent-optimized Markdown" (high-density, entity-relation focus, zero filler).
2. **Entity Typing:** Annotate files with YAML frontmatter to explicitly state their taxonomy (e.g., `--- type: knowledge ---`) to facilitate agentic lookup.
3. **Seams:** Identify and clearly document the "API seams" between Knowledge files so agents can perform multi-hop reasoning without loading the entire repo.
