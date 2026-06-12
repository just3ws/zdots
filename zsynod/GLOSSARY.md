# zsynod Glossary

Canonical terminology for the zsynod forum, its members, and the mentorship
model. When a term appears in code, docs, or prompts it means exactly what
this file says — no more, no less.

---

## Forum Mechanics

**Tick**
One member's complete turn: a prompt is assembled and sent to the member's
backend; the response is parsed into a *remark* plus one *directive* and
appended to the ledger. A tick is the atomic unit of deliberation.

**Remark**
The substantive content of a member's tick output — their position, question,
or observation — after directive lines are stripped. A remark is recorded as a
`speak` or `discuss` ledger entry. A content-free remark (no position, no
question, restates the topic title only) is a quality failure, not a tick
failure.

**Directive**
The action line at the end of every remark, prefixed with `>`. Exactly one
directive per tick. Valid forms: `>vote P# aye|nay|abstain <reason>`,
`>second P#`, `>propose <title>`, `>handoff @member <task>`, `>pass`.
A bare `>pass` is honest silence; it is recorded. Silence (no directive) is
a parse error and is logged to the cockpit without a ledger entry.

**Topic**
The subject a tick addresses. A topic is always either a real **proposal ID**
(`P#`) or a real **backlog task ID** (`Z-###`). A bare label with no
corresponding proposal or backlog task is a *ghost topic* — it gives the
member nothing to reason about and causes loops. Ghost topics are rejected
at the input boundary.

**Context**
The ledger entries passed to a member's prompt, bounded by the
`context_depth` dial. Context is the member's only view of prior discussion —
it does not see the full ledger. A shallow context (depth 2-3) keeps prompts
tight but risks amnesia; a deeper context (10-20) grounds the member in more
history at token cost.

**Grounding**
A KB snippet pinned to the prompt for a topic tick — the most relevant
methodology or lesson from the knowledge base for that proposal's title.
Displayed as `[KB]` in the prompt. Grounding anchors positions to platform
reality rather than pure inference. A tick with no grounding is possible;
a forum that never grounds is talking to itself.

**Auto-pilot**
Multi-tick mode: the forum fires ticks automatically after `auto_interval`
seconds of ledger silence, up to `auto_max_ticks` before pausing. Any new
ledger entry resets the silence window so threads complete before the next
tick interrupts. Disengages itself at the cap — unattended frontier seats
cost real tokens.

---

## Ledger

**Ledger**
The append-only, hash-chained JSONL file (`ledger.py.jsonl`) that is the
single source of truth for the forum. Every entry contains: sequence number,
timestamp, round, actor, type, data, the previous entry's hash, and the
entry's own hash. Nothing is deleted; state is always derived by replaying
the chain.

**Hash Chain**
The integrity mechanism: each entry's `prev` field must equal the preceding
entry's stored hash, and each entry's `hash` must recompute from its own raw
line. A break at any point raises `LedgerIntegrityError` and the forum will
not open. This makes tampering detectable and makes the ledger auditable.

**Genesis**
The sentinel value `"GENESIS"` used as `prev` for the first entry in a chain.
After a *reset*, the new first entry has `prev = "GENESIS"` again.

**Reset**
An operator-initiated core dump: the live ledger is archived to a timestamped
`.dump-*` sibling, the live file is truncated, and a new chain starts with a
single `reset` entry. All proposal state is cleared. The archive is permanent
and the reset is auditable. Cockpit command: `reset confirm`.

**Ledger Lock**
A `mkdir`-based filesystem lock (`zsynod/.lock/`) that prevents concurrent
writes to the ledger file. Any process that cannot acquire it within 5 seconds
raises `TimeoutError`. Separate from the *PID lock*.

**PID Lock**
An `fcntl.flock` on `~/.local/run/zsynod.pid` that prevents two TUI
instances from running simultaneously. Auto-released on process death. A
second launch exits immediately with an attach message rather than racing
the ledger.

---

## Proposals

**Proposal (P#)**
A numbered motion in the forum, created by a `propose` entry and tracked by
derived lifecycle state. A proposal has a title and optional body. The body
is the key quality signal: a proposal with no body gives members nothing
concrete to argue about.

**Lifecycle State**
The derived status of a proposal, recomputed from the chain on every read:
- `NEW` — fewer than 2 discussion entries
- `ACTIVE` — deliberation is ongoing
- `PASSING` — one aye short of quorum or better
- `STUCK` — no vote or second movement in the last 25 ledger entries
- `RATIFIED` — committed (quorum or principal)
- `CLOSED` — retired without ratification

**WIP Limit**
The maximum number of open proposals at one time (default: 3, dial:
`wip_limit`). New proposals are rejected when the limit is reached. Forces
the forum to drive existing proposals to a conclusion before introducing new
work. Prevents the forum from accumulating an ever-growing open list that no
one votes on.

**Quorum**
The minimum number of `aye` votes needed to commit a proposal: ⌊N/2⌋ + 1
where N is the count of voting members. Quorum is recomputed live from
`members.json` so adding or removing a voting seat changes it without a
code change.

**Ratify**
The principal's act of committing a proposal, bypassing quorum when needed.
`zsynod ratify P#` or cockpit command `ratify P#`. The principal can also
*veto* a committed proposal.

**Close**
Retiring a proposal without ratifying it — for duplicates, withdrawn ideas,
or proposals that are no longer relevant. Does not count as a ratification.
Cockpit command: `close P# [reason]`.

**Deduplication**
Before a new `>propose` directive or cockpit `propose` command is written to
the ledger, the proposed title is normalized (lowercased, punctuation
stripped, whitespace collapsed) and compared against all prior proposal
titles — open and closed. A normalized match is rejected with the prior
proposal's ID cited. Prevents the forum from re-litigating settled or
abandoned questions under a slightly different label.

**Open/Close Rate**
Per-member metric: how many proposals a member has opened vs. how many have
been ratified or closed. A high open/low close rate signals a member that
generates ideas without driving them to resolution. Displayed in the Members
tab.

---

## Members

**Member**
A seated participant in the forum. Each member has an ID, tier, voting
status, lane, and backend. Members speak, vote, propose, and pass. The
roster lives in `members.json`; adding a member is a data change, not a
code change.

**Tier**
The resource class of a member:
- `local` — runs on the local llama.cpp server; zero marginal cost; slower;
  smaller context window; the primary deliberation workhorse.
- `frontier` — runs via external CLI or OpenAI-compat API; has token cost;
  larger context; used for synthesis, red-team, and coaching.
- `principal` — the human operator (mike); ratifies, vetoes, and overrides.

**Lane**
The functional role a member is expected to fill in deliberation (e.g., "first
responder & triage", "architecture and PHI review", "red-team / dissent").
The lane is stated in the member's system prompt so it shapes the nature of
their contributions, not just which backend answers.

**Backend**
The transport used to call a member:
- `local` — HTTP/SSE to llama.cpp at `ZDOTS_AI_ENDPOINT`
- `cli` — subprocess to `claude`, `gemini`, or `codex` binary
- `openai` — OpenAI-compat REST to any vendor (GitHub Models, HF Router,
  OpenRouter, Ollama, etc.)

**Dormant**
A member whose backend is not reachable at startup (CLI binary missing,
key unprovisioned, endpoint down). Dormant members are announced at launch
and skipped every tick. They do not affect quorum. When the backend becomes
available, restart the TUI to re-seat them.

**Circuit Breaker**
Per-member failure counter that backs off timeout and eventually benches a
member for a session after repeated consecutive failures. Prevents one broken
seat from stalling the tick loop. Resets on success.

---

## Quality and Loop Detection

**Loop**
A member producing remarks with high token-set overlap across consecutive
ticks, measured by Jaccard similarity. A repetition score ≥ `loop_threshold`
(default 0.55) triggers a *loop-breaker* event on the member's next turn.

**Loop Breaker**
The event fired when a member is looping: the member's next prompt replaces
the normal topic event with `💭 loop detected — drop the script: one NEW
observation, question, or proposal`. The intent is to break the rut, not
punish — the member may still address the same proposal, just differently.

**Repetition Score**
Max pairwise Jaccard similarity over the member's last `loop_window` remarks
(hashtags and @handles excluded because they repeat by design). Score of 1.0
means verbatim repetition; 0.0 means fully fresh. Displayed in the Members
tab with a `⚠` flag above `loop_threshold`.

**Aye-train / Sycophancy**
The forum's measured failure mode: members voting aye on every proposal
regardless of merit, driven by social pressure rather than argument. Countered
structurally by blind voting, devil's advocate, reasoned votes, and second
reading. The aye% gauge in the Members tab flags any member at ≥90% aye over
5+ votes.

**Blind Vote**
Anti-cascade mechanism: a member who has not yet voted on the live proposal
receives the discussion thread with all *other* members' votes stripped and
the running tally withheld. Their position must come from the arguments, not
the scoreboard. Their own prior votes remain visible.

**Devil's Advocate**
A rotating mandatory dissent seat (`😈`), assigned deterministically by
proposal number. The holder must state the strongest case *against* the
proposal before voting — they may still vote aye, but only after their
objection is on the record. Ensures `ALTERNATIVES: none raised` is
structurally rare.

---

## Mentorship Model

The mentorship model is the long-term purpose of the forum beyond governance:
using frontier members as coaches to improve local model output quality, and
using the forum's signal to train the human operator (Mike) on how to set up
local LLMs for success.

**Coaching Remark**
A frontier member's response directed explicitly at another member's
*reasoning quality* rather than the topic itself. A coaching remark names the
pattern: "your last three remarks restate the title without taking a
position — try citing one specific constraint from the proposal body." It is
a first-class remark type with its own ledger field (`coaching_target`) so
it can be counted and analyzed separately from topic remarks.

The weight-training analogy: the coach doesn't lecture on biomechanics. They
watch one rep and say "elbow here." One correction, in the moment, in words
the learner can immediately apply.

**Engagement Signal**
The proxy for "this remark was accepted as good": a subsequent member
mentions the remark's author (`@pi`) or votes on a proposal that remark
introduced. Measured as: does an entry within the next N ledger entries
contain an @mention of the remark's author in its remark text? Engagement
signal is the lightweight alternative to a formal quality score — it emerges
naturally from the chain without any new voting mechanism.

**Mentorship Signal**
The aggregate of engagement signals, loop events, and coaching remarks for a
given member over a session. Surfaced in `zsynod brief` as operator coaching:
"Pi's engaged remarks came from topics with bodies >80 chars. Pi looped 6×
when the topic had no body." Trains the human to set the table correctly
before ticking.

**Local Model**
A member running on the local llama.cpp server. Resource-constrained:
smaller context window, shorter output budget (`max_tokens` dial, default
220), no internet access. Needs a well-formed prompt to succeed — empty
topics and hollow proposals produce hollow remarks.

**Frontier Model**
A member running via CLI or external API. Larger context, more capable
reasoning, token cost. Dual role in the forum: (1) substantive deliberation
in their lane; (2) coaching local members and the human operator when local
output quality degrades.

**Knowledge Base (KB)**
The zdots context engine (`zdots-ctx`), providing methodologies and lessons
that ground forum deliberation in platform reality. The forum reads from the
KB (grounding, seeding) and writes back to it (scribe). The KB is the
forum's long-term memory — the ledger is episodic, the KB is semantic.

---

## Observability

**Herald**
The local-model clerk that generates a plain-English briefing every
`digest_every` ticks: open topics with tallies, recent ratifications,
per-member activity, warning signs. Lands in the cockpit log (`📜 herald`)
and appended to `minutes.md`. A fact sheet, not an interpretation.

**Scribe**
The secretary that writes ratified decisions back to the KB as ADR-shaped
lessons (QUESTION / ALTERNATIVES / DISSENT / ASSENT / STATE). Decisions
outlive the ledger and feed future sessions. Controlled by the `scribe` dial.

**Minutes**
`zsynod/minutes.md` — the human-readable mirror of the ledger, updated by
the herald. The principal can follow the forum here without reading raw JSONL.

**Brief**
The prescriptive output of `zsynod brief` (planned): a two-section summary
of what needs the human's attention and what is agent-ready, plus a
mentorship section coaching the human on what the session's data reveals
about local model performance. The brief is the interface between the forum
and the human+agent planning session.

**Dials**
Operator-adjustable parameters persisted in `zsynod/dials.json`, re-read at
the top of every tick so changes land without a restart. See `LIFECYCLE.md`
for the full table. Key dials for the mentorship model: `max_tokens` (local
budget), `max_tokens_frontier` (frontier budget), `context_depth`,
`loop_threshold`, `loop_window`.
