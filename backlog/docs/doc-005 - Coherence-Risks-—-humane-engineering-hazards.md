---
id: doc-005
title: Coherence Risks — humane engineering hazards
type: guide
created_date: '2026-06-15 01:56'
---
# Coherence Risks — humane engineering hazards

Risk patterns that recur in systems built by a strong systems-thinker working at
speed — especially solo, with AI agents amplifying output. They are *humane*
risks: not bugs, not failures, but the predictable shadow side of real strengths.
Named so they can be watched for, not moralized about. Each pairs a **signal**
(how it shows up in the repo) with a **guardrail** (the cheap counter-move).

The unifying observation: **the clearer the whole system is in the designer's
head, the more the unfinished parts register as "rough edges."** That felt
friction is the gap between a complete vision and a partial implementation — the
price of seeing the system whole before building it whole. These risks are how
that gap leaks into the artifacts.

## R1 — Structure outruns convergence

**Pattern.** New abstractions, tools, and entry points accrue faster than they are
consolidated. The strength (seeing seams everywhere) produces proliferation; the
surface grows past the point where any single mind holds it.

**Signal.** Many binaries / modules with overlapping roles; "too many entry
points"; the same capability reachable several ways; periodic felt need to
"unify."

**Guardrail.** *Convergence over proliferation* as a standing law: a new capability
is a noun/verb under an existing spine, not a new top-level surface. Before
building, verify no equivalent exists and extend it. Treat a new entry point as a
cost that must be justified, not a default.

## R2 — Documentation describes the intended state as present

**Pattern.** Docs, helptext, and READMEs describe the system as the designer
*intends* it, slightly ahead of what is built. Aspiration is written in the present
tense. This is the most reliable source of the very "burrs" later felt — the
collision point where a complete mental model meets a partial implementation.

**Signal.** Documented commands, files, or flags that do not exist yet
(`zdots doctor` before the dispatcher; `GLOSSARY.md`/`ONTOLOGY.md` referenced but
absent). A reader following the docs hits a wall the author never sees.

**Guardrail.** Docs describe what *is*; intent lives in decisions/tasks. A
contract-coverage test (docs reference only real commands/files) turns this from a
discipline into an invariant. When you must document the target state, mark it
explicitly as planned, with a task id.

## R3 — Meta-work displaces leaf-work

**Pattern.** Felt incoherence is resolved by producing *more structure* — a
decision, a schema, a taxonomy, a versioning scheme — rather than by finishing the
open thread. The scaffolding is real and good, but building the system to build the
system can quietly substitute for landing the thing.

**Signal.** Foundations sit In Progress while new fronts open. The board accretes
contracts faster than it closes tasks. Elaborate enabling work precedes simple
delivery work.

**Guardrail.** A WIP limit on foundations: land one In-Progress foundation to Done
before filing the next contract. Coherence is *felt at the moment of landing*, not
at the moment of design — so bias the next action toward closing, not opening.

## R4 — Breadth opens before depth closes

**Pattern.** Several initiatives run in parallel, each promising, each parked
before completion when the next frontier appears. The pull toward the new is
stronger than the pull to finish the last.

**Signal.** A growing Experimental / parked lane; multiple "funded but held"
threads; depth-1 on many fronts rather than depth-complete on few.

**Guardrail.** Make parking explicit and bounded (an Experimental state with a
re-entry condition — already in place). Prefer finishing the current wave's
foundation over starting the next wave. Fewer threads, each carried to Done.

## How to use this

These are *watch-fors*, not verdicts. The same trait that produces each risk
produces the system's best qualities — systemic vision, vocabulary discipline,
safety reflexes, a process ethic. The goal is not to suppress the strength but to
add the cheap counter-move so the shadow side doesn't accumulate.

When reviewing the board or the surface, scan for the four signals above. If one is
present, apply its guardrail before adding anything new. The single highest-leverage
habit across all four: **land the open thread before opening the next.**
