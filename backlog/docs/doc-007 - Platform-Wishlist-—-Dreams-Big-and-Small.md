---
id: doc-007
title: Platform Wishlist — Dreams Big and Small
type: other
created_date: '2026-06-28 16:48'
---
# Platform Wishlist — Dreams Big and Small

*An analysis of the direction this repo has been moving, where it's heading, and
how to keep refining toward it — with the dreams that flow from that, big and
small. Written 2026-06-28.*

This is not a brain-dump. The question was "what am I trying to get to **here**,"
so it starts where your hands are — the media→knowledge pipeline — reads the
pattern that's already there, and only then names the larger thesis it serves.

---

## 1. The living edge — what you've actually built

The transcription pipeline is the most complete thing on the platform right now,
and it is not a side feature. It is the whole platform's thesis, working, on one
input type:

```
ingest → RAW → CLEANED → DISTILLED (editable, grounded to [mm:ss]) → PROMOTED → embedded → semantically searchable
                                  ▲ doubt loop                              ▲ full provenance backlink
```

- **The doubt loop is shipped (Z-167).** Doubts are *derived on the fly* from
  whisper token probabilities + `known_terms` — two signals (low-confidence
  spelling, unknown entity), noise-filtered. The operator confirms/corrects on
  the source page; the correction persists (the mis-hearing folds in as an
  alias); re-detect drops it. And the *same* registry primes the next whisper
  `--prompt`, so terms come back spelled right before review. Reactive **and**
  proactive.
- **The loop is closed (Z-170).** Edited distilled content promotes to a `lesson`
  via the canonical `LessonIntake` seam, auto-embeds, and is returned by
  `zdots-ctx query --semantic` — with a provenance backlink to the source and
  `[mm:ss]`.
- **The output axis is specced (Z-171, deferred):** the distilled stage emits a
  timeline of moments (screenshot / clip / snippet / excerpt), human-curated,
  ffmpeg-materialized. Your "shorts with context" and "screenshot key moments"
  already live here.

So most of what you described in passing is **done or specced.** The dreaming
should start from that, not behind it.

## 2. The pattern it reveals — your design signature

Read back from Z-167/170/171, the platform has a consistent taste. Every good
dream here should match it:

- **Derive, don't store.** Doubts are computed at render, not warehoused. No
  `transcript_doubts` table. *Resolutions* persist; transient judgments don't.
- **Self-seeding loops.** The system gets better from corrections, not from a
  training pipeline you have to feed.
- **Local-only identity stays local.** `known_terms` identity data lives in the
  DB, never git. (This is the PHI discipline showing up as a design reflex.)
- **Human-gated materialization.** Nothing extracts dozens of clips on its own; a
  person curates before anything is cut.
- **Reactive + proactive halves.** Catch the problem this run; prevent it next run
  from the same persisted knowledge.

This is the shape to copy. The next frontier is not a new kind of system — it's
this shape, pointed at the next kind of doubt.

## 3. What "here" is becoming — the near frontier

### 3a. The speaker loop = the voice analog of the term loop *(the big one — new)*

Your words — *"clues to who is talking, refining that; a doubts remover; a trainer
for it; train the names; train the voices"* — describe, almost exactly, the
**speaker-identity twin of the term loop you already shipped.** Same four
surfaces, same shape:

| Term loop (shipped, Z-167) | Speaker loop (the dream) |
|---|---|
| low-confidence word → doubt | low-confidence speaker turn → doubt (diarization boundary / attribution) |
| confirm/correct panel | confirm/correct: label `[Speaker A]` → "Mike" on the source page |
| `known_terms` registry (names, local-only) | **speaker registry** (who the speakers are — local-only identity, never git) |
| whisper `--prompt` priming (proactive) | **voiceprint enrollment** → auto-attribute on the next ingest (proactive) |

Built in your idiom: attributions *derived* from diarization + voiceprints at
render; *corrections* persist; self-seeds as you label; voiceprints never leave
the box. "Train the names" = the speaker registry. "Train the voices" =
enrollment. "Trainer for the doubt remover" = the same confirm/correct loop, now
for people instead of words. → **Z-175.**

### 3b. The output axis — artifact frameworks *(new, under-built)*

Z-170 promotes distilled content to a *lesson* (knowledge, inward). The missing
half is *artifacts* (outward): the same distilled, `[mm:ss]`-grounded content
poured into **frameworks** — an article, a thread, show-notes, a quote card —
human-gated, provenance-preserved. Distinct from a lesson: a lesson is for the
engine, an artifact is for an audience. → **Z-176.**

### 3c. Un-defer the timeline (Z-171)

You've now reached for shorts/screenshots twice. That's a signal its `deferred`
/`low` is stale. It's the output-axis sibling of 3b (clips/screenshots vs.
text). Worth promoting — your call, noted here rather than re-prioritized
unilaterally.

## 4. The thesis it serves — the lift

Now zoom out, because the pipeline is a microcosm. The platform is one bet, stated
many ways across the memory and the decisions: a **Virtuous Loop** — Work →
Capture → Curate → Infer → Repeat — that turns *everything you encounter or
produce* into durable, traversable, **compounding** knowledge that makes you
better at the work that matters, while staying local-first and PHI-safe.

The transcription pipeline is that loop proven on media. The destination is the
same loop running on **every input axis**:

- what you **do** → command analytics, session residue, the intelligence loop
  (Seam ⑦, history-intelligence built; session-debrief write-back is the open end)
- what you **read/watch** → the ingestion envelope (Z-150: url/youtube/webpage),
  the transcription pipeline, OKF bundles (decision-010 / Z-174)
- what you **mean** → the concept registry (Z-151) + OKF type-bridge: one
  ontology so all of it is *traversable by concept*, not just full-text searched
- and eventually, an AI council (**zsynod**) that reasons over the whole
  compounding corpus on your behalf

One loop, many inputs, one store, one language. That's the "here" the pipeline is
a prototype of.

## 5. How to keep refining — the spine

The dominant *engineering* discipline in this repo is **fighting fragmentation.**
Three convergence decisions in a row — decision-008 (one DSL grammar:
`zdots <noun> <verb> --json`), decision-009 (one ingestion envelope + one
terminology), decision-010 (OKF as one knowledge file standard, riding 009). The
way to refine toward the thesis is to keep that discipline:

1. **Keep converging. Resist new top-level surfaces.** Every dream below is a
   temptation to add a binary, a table, a store. Almost always the right move is a
   *noun/verb under the spine* or an *adapter behind an envelope* — never a new
   silo. (009's "adapters behind the envelope" is the template; Z-174 OKF rode it.)
2. **Rule of three before abstracting.** The term loop is instance one of
   "human-in-the-loop doubt resolution." Build the speaker loop (3a) as instance
   two *in the same shape* — do **not** build a generalized "doubt primitive"
   yet. Extract the abstraction after a third instance asks for it. (Naming the
   pattern: good. Building the framework now: premature.)
3. **Extend the input axis, then build the output axis.** Inward (capture →
   distill → lesson) is mature; outward (distill → artifact) is the gap. Balance
   the loop.
4. **Human-in-the-loop is the cheap learning mechanism — lean on it.** No model
   training apparatus. Corrections that persist and self-seed, every time.
5. **Close the loop's open ends.** Session-debrief write-back (the Infer→Capture
   return). DB→OKF export (the file-back end of the Karpathy loop). These finish
   what's started before opening new fronts.

---

## 6. The dream catalog — big and small

Grouped by the loop's anatomy. Ripe ones are seeded as `dream` tasks; the rest
live here until they ripen. *Big or small, it moves us all.*

### Ingest (more inputs, same envelope — never a new silo)
- Speaker loop: diarization + voiceprints (3a, **Z-175**).
- The Z-150 envelope adapters as they land: webpage, youtube, playlist.
- OKF bundle ingest (**Z-174**) — external knowledge bundles flow into the Loop.
- Small: a "drop a file / paste a URL" quick-ingest from the dashboard.
- Small: email/newsletter → ingest; podcast feed → transcription pipeline.

### Reduce doubt (derive, correct, self-seed)
- The speaker confirm/correct trainer (part of **Z-175**).
- Small: a "doubts across all sources" review queue (derived, not stored).
- Dream: cross-source term reconciliation — the same concept spelled two ways in
  two transcripts resolves to one `concept` (Z-151 territory).

### Distill (grounded, provenanced)
- Auto-chaptering of long transcripts (extends Z-169 chunking).
- Dream: "what changed my mind" — diff a new distillation against prior lessons on
  the same concept; surface the delta.

### Produce artifacts (the output axis — the gap)
- Article / thread / show-notes frameworks (3b, **Z-176**).
- Timeline: clips / screenshots / shorts (un-defer **Z-171**).
- Small: quote cards from `[mm:ss]`-grounded highlights.
- Dream: a weekly "what I learned" digest auto-assembled from the week's lessons.

### Compound (one store, one ontology, queryable)
- DB→OKF export — git-distributable, diffable knowledge bundles (deferred from 010).
- Concept-graph browser: walk the ontology (Z-151), not just search it.
- Dream: knowledge-decay detection — flag lessons no recent session corroborates.
- Dream: provenance graph — every lesson traceable to the session/source that bore it.

### Reason (the council, someday)
- zsynod over the compounding corpus: quorum answers, dissent recorded.
- Dream: "ask my second brain" — a local Q&A that answers *as you*, from your
  lessons + methodologies, PHI-safe.
- Dream: ambient assist — the speaker loop pointed at *live* audio (meetings),
  local, opt-in, the ultimate "capture" edge.

### Keep it coherent & safe (the spine, always)
- `zdots <noun> <verb> --json` parity across the surface (decision-008).
- Continuous PHI-posture attestation surfaced on the dashboard.
- Small: `my.local` health probe in `zdots-doctor` (today's 502 was a silent miss).
- Dream: self-healing — the platform detects its own drift and proposes the fix.

---

*Seeded this round: **Z-175** (speaker loop), **Z-176** (artifact frameworks).
Un-defer candidate: **Z-171**. Everything else waits here until it ripens — the
spine (§5) decides the order, not the length of this list.*
