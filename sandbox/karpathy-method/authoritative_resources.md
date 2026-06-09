# Authoritative Resource Registry: Andre Karpathy Methodologies

This document serves as the high-signal, verified source of truth for Karpathy-style methodologies. All other community interpretations are considered secondary.

## 1. Primary Source Repositories
- **[karpathy/autoresearch](https://github.com/karpathy/autoresearch)**: The definitive implementation of the "Ratchet Loop" and "Three-File Architecture" (`prepare.py`, `train.py`, `program.md`).
- **[karpathy/nanoGPT](https://github.com/karpathy/nanoGPT)**: The foundational codebase for understanding Transformer implementation from first principles.
- **[karpathy/micrograd](https://github.com/karpathy/micrograd)**: The fundamental "calculus" of neural network backpropagation in ~150 lines of Python.

## 2. Essential Essays & Documentation
- **[karpathy.ai (The Blog)](https://karpathy.ai)**:
    - *Software 2.0*: The foundational thesis on data-as-source-code.
    - *The Busy Person's Intro to LLMs*: High-signal conceptual framework.
    - *AI Operating System*: His latest framing on agentic loops and orchestration.

## 3. Organizational Initiatives
- **[Eureka Labs](https://eurekalabs.ai)**: The home of his "AI-Native Education" philosophy and the "LLM101n" tracer-bullet curriculum.

## 4. Usage for Zdots Agents
- **Ingestion Policy:** When performing deep analysis, agents **must** prioritize content from these sources. 
- **Validation:** If community sources contradict these primary sources, default to primary sources.
- **Context Hydration:** Use `pi-ctx` to treat these repositories as the "system-level kernel" for our knowledge layer.
