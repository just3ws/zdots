# Insight Report: Karpathy Methodology vs. Zdots

## Comparative Analysis
Karpathy's methodology prioritizes **first principles understanding** and **autonomous experimentation (ratchet loops)**. Zdots excels in **observability** and **structured knowledge retrieval** but relies heavily on high-level abstractions (`zdots-ctx`, RAG pipelines).

## Key Gaps
1.  **Fundamental Calculus Gap:** We lack deep intuition into how our context retrieval (RAG) actually performs, as we treat the `context-engine` as a black box.
2.  **Experimentation Gap:** We lack a formal "Ratchet Loop" for testing improvements to our automation (`bin/` scripts), relying on manual validation.
3.  **Context Compaction Gap:** We currently dump raw, uncompacted context into sessions, risking context dilution and "lost in the middle" phenomena.

## Proposed Improvement Roadmap
1.  **Context Engineering:** Implement proactive context compaction in `pi-ctx`.
2.  **Ratchet Loops:** Introduce automated, git-backed experiment loops for shell tools.
3.  **Fundamental Calculus Sandbox:** Build minimal, pure-implementation versions of our core engine components.
