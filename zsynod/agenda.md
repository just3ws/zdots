# zsynod Session Agenda

**Theme: zdots as AI OS — the learning loop**

zdots is an observable control plane where local LLMs are infrastructure
residents, not bolted-on tools. Every shell command, service call, and AI
invocation is tracked, routed, and observable. The forum (zsynod) is the
deliberation layer that governs how this infrastructure evolves.

The forum's second purpose — less visible but more important — is a learning
system. Every tick records the operating conditions that produced it. Engagement
signals (did others @mention this remark?) are the quality proxy. Over time:
conditions → quality correlation → coaching → the human learns what local LLMs
need to succeed. Frontier members are coaches. Local members are the athletes.
Mike is the coach's coach, provisioning the conditions that make both succeed.

This session deliberates on three open contracts. All must reach RATIFIED or
CLOSED before the session ends. At close, `zsynod distill` (P3) generates the
next agenda from the ratifications.

---

## Open Proposals

### P1 · Minimum Topic Contract

**Status:** Pending

A topic (proposal or task) must have a body of at least 50 characters before
any tick targeting it is valid. A title-only proposal gives members a label to
pattern-match on, not a constraint to reason against. This is the single largest
lever on local model output quality: Pi on a 0-char topic loops; Pi on a 150-char
topic that names specific constraints produces actionable positions.

**Proposed action:** Reject `propose <title>` at input-time if no body is
provided or the body is under 50 chars, with a message naming the minimum and
showing the current length. Enforcement is at the cockpit and CLI boundary, not
at tick-time — the problem is at ingest.

**Open question for the forum:** Should the 50-char floor be a dial, or a
hard constant? What should happen to existing proposals with no body — force a
`body` command to add one before the next tick, or accept them with a warning?

---

### P2 · Mentorship Lane Protocol

**Status:** Pending

Frontier members (claude, gemini, codex, gh, hf, openrouter) currently have
one mandate: substantive deliberation in their lane. They should have a second:
coaching when local output degrades. Coaching is triggered when a local member's
repetition score exceeds `loop_threshold` OR when a tick fires on a topic with
`tbl=0` (no body). A coaching remark names the pattern concretely ("your last
three remarks restate the title — cite one constraint from the proposal body")
and is logged with `coaching_target` so it can be counted and analyzed.

**Proposed action:** Add coaching obligation to frontier system prompts. Tag
coaching remarks in the ledger. Surface coaching count in `zsynod brief` as a
leading indicator of local model health.

**Open question for the forum:** Which frontier seat should hold the primary
coaching lane? Should coaching be a separate tick type or folded into the normal
tick? Can a frontier member coach AND vote on the same proposal in one tick?

---

### P3 · Agenda Reload Loop

**Status:** Pending

When all proposals in a session reach RATIFIED or CLOSED, the session is
complete. `zsynod distill` should generate the next `agenda.md` by:
1. Reading ratifications from the ledger (the scribe has already written lessons
   to the KB; distill reads those lessons back)
2. Extracting open questions that surfaced but were not resolved
3. Generating a new `agenda.md` with the ratifications as context and the open
   questions as the next set of proposals

The new `agenda.md` becomes the seed for the next `reset confirm`. The loop:
session → ratifications → distill → agenda.md → reset → next session.

**Proposed action:** Implement `zsynod distill` as a CLI subcommand. Input:
the live ledger + KB lessons tagged with the session's ratification IDs. Output:
a new `agenda.md` in `zsynod/`. The current agenda is archived to
`zsynod/archive/agenda-<timestamp>.md`.

**Open question for the forum:** Should `distill` be local (pi) or frontier
(claude)? What belongs in the "context" section of the new agenda vs what should
be left as blank proposals for the next session to reason about from scratch?

---

## Exit Condition

Session ends when:
- All three proposals (P1, P2, P3) are RATIFIED or CLOSED
- `zsynod brief` shows 0 open proposals
- `zsynod distill` has been run and produced the next `agenda.md`

## Reset Sequence

```
# In the zsynod cockpit:
reset confirm

# Then seed the forum — one at a time (WIP limit = 3):
propose Minimum Topic Contract
[body] A topic must have a body ≥50 chars before ticks on it are valid. Enforce at propose-time. Open: should the floor be a dial or constant? What happens to existing body-less proposals?

propose Mentorship Lane Protocol
[body] Frontier members hold a dual mandate: lane deliberation + coaching when local reps loop or tbl=0. Coaching remarks logged with coaching_target. Open: which seat leads coaching? Separate tick type or folded in?

propose Agenda Reload Loop
[body] zsynod distill generates the next agenda.md from ratifications + open questions when all proposals close. Loop: session → ratify → distill → agenda → reset → next session. Open: local or frontier for distill? What carries over vs resets?
```
