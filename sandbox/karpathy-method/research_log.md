# Research Log: Software 3.0 in Zdots

## Mapping: Software 3.0 to `pi-ctx`

### Karpathy's Definition
Software 3.0: LLMs as the new computing infrastructure where natural language prompts serve as the primary "source code."

### Zdots Context
`pi-ctx` infrastructure: Uses natural language queries (via `pi-ctx-query` and `pi-ctx-hydrate`) to dynamically shape the context (the "Brain") for LLM-based agents.

### Synthesis
The `pi-ctx` framework is effectively a Zdots implementation of Software 3.0. The "source code" is the set of semantic patterns, context tags, and user queries that define the state/knowledge available to agents.

- **Source Code:** `pi-ctx` tag definitions & user semantic queries.
- **Compiler/Runtime:** `context-engine` (Rails API) + RAG retrieval mechanisms.
- **Execution:** Agent decision-making based on the hydrated context.

### Next Step: Autonomous Verification Experiment
Objective: Automate the verification of context hydration quality.
Hypothesis: If we can define a "golden state" for a given context tag, an agent can autonomously run `pi-ctx-hydrate <tag>`, compare the resulting context against the golden state, and report discrepancies.
