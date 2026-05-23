---
id: m-5
title: "Operation Martian — PHI-Safe Operating Mode"
---

## Description

Harden zdots for regulated medical-records work. Three layers: (1) enforce AI data boundary so no PHI reaches cloud endpoints, (2) basic PHI-pattern filtering before any session capture, (3) graceful zero-AI degradation so the system is fully operational with no LLM available. All defaults bias toward maximum safety; opt-in to relax. Designed to survive an unknown corporate proxy environment on a fresh clone.
