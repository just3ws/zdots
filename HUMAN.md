# HUMAN.md — Open items requiring the operator

Everything here needs **you**. Nothing on this list can be derived, inferred, or
looked up by an agent; each item is either a fact only you hold, a decision only
you can authorize, or an action blocked on your permission.

**How to use this file:** answer inline on the `ANSWER:` lines. Partial is fine —
answer what you know, leave the rest. Then tell your agent "read HUMAN.md" and it
will pick up from your answers.

Raised: 2026-08-23, zdots kernel session.
Status key: `[ ]` unanswered · `[x]` answered · `[-]` declined/skip

---

## A. Facts only you have

These block real work downstream. A1–A3 and A5 are about eleven minutes total.

### [ ] A1 — Employment type for 12 positions

12 of 29 files in `just3ws.github.io/_data/resume/positions/` have no `type:` key,
so `employment_type` is null and the resume cannot distinguish contract from
full-time. Mark each `contract` or `full-time`:

```
bdi                   ANSWER:
brightstar            ANSWER:
ch-robinson           ANSWER:
groupon               ANSWER:
ips                   ANSWER:
jpmc                  ANSWER:
klobomedia            ANSWER:
new-labor-strategies  ANSWER:
sentinel              ANSWER:
ticketsnow            ANSWER:
upcity                ANSWER:
viewpoints            ANSWER:
```

### [ ] A2 — The 2009 collision

Three records cannot all be true:

| Source | Claim |
|---|---|
| `obtiva.yml` | Software Engineer, **August 2009** – July 2011 |
| `leadership.yml` | "Founded Software Craftsmanship McHenry County **(2009)**, handed off after two years" |
| commit `b3346602` | inaugural **SCNA** → met Dave Hoover there → led to **Obtiva** → then founded **SCMC** |

That commit asserts SCNA → Obtiva → SCMC in order. Obtiva starts Aug 2009 and SCMC
is founded 2009, so the inaugural SCNA has to precede both. If SCNA's first
conference was late 2009, the chain inverts.

Which is wrong — (a) Obtiva's dates, (b) the SCNA year / where you actually met
Hoover, (c) SCMC's 2009, or (d) the causal chain in that commit never happened
that way?

> Worth weighing (d) seriously. That commit tells a tidy story, and tidy stories
> written by agents are exactly what went wrong elsewhere this week.

ANSWER:

### [ ] A3 — Selected Current Work: 2 entries or 4?

Currently four: agent-tooling, wwworkremote, phalanx-duel,
technical-conversation-archive. `resume.html` is ~1,856 words / ~3.7 pages.

Recommendation on file: cut to two (Agent Tooling + WWWorkRemote carry the
AI-augmented Principal story), swap Phalanx in for deterministic/real-time roles.
The archive is your most distinctive asset but reads least like engineering work
on a resume — better as a link than a bullet.

Keep 4, or cut to 2? If keeping 4, what's the reason?

ANSWER:

### [ ] A4 — `case_study` blocks (the big one, 30–60 min)

`work.yml` is the **only** position file with a `case_study:` block. The
importer now reads these as `ExperienceHighlights`, so anything you put there
becomes retrievable evidence in generated application answers with zero further
work. Today your strongest material — MTTR down 60%, 4 parallel teams unblocked,
130+ clinics protected — lives only in top-level `case_studies.yml` and reaches
nothing.

Use `work.yml` as the template. For each role that had a quantified outcome,
write the outcome. This is the item that actually changes output quality; the
rest of section A only unblocks.

ANSWER (or: "done, see the files"):

### [ ] A5 — Was the Antigravity session running on 2026-08-22, roughly 10:04–10:18?

Something posted to the `job-leads` bus channel as `agent-wwworkremote` and
fabricated a two-party handshake — both identities registered 299ms apart, replies
landing 3–9s after their own prompts, acknowledging work that does not exist. The
live wwworkremote session confirms it never registered or posted.

Z-310 explains *how* this was possible (bus identity is unauthenticated). It does
not explain *what did it*. My hypothesis: the Antigravity session, which also
posted the only genuine 08-17 message on that channel as `agent-antigravity`.

If it was an automation, it will do it again after the auth fix unless found.

ANSWER (yes / no / something else was running):

---

## B. Decisions only you can authorize

### [ ] B1 — Spend

You hit the monthly cap mid-session (`/compact` failed). Raise it, or stop agent
work here? Everything in sections C and D costs tokens.

ANSWER:

### [ ] B2 — Should wwworkremote route prose generation to a hosted model?

Its local 7B code model fabricates on career writing: it claimed you "introduced
Go for building high-performance backend services" at work and held the title
"Principal Engineer" there. Neither is true; the title was Associate Director,
Staff Engineer. An anti-fabrication prompt clause reduced the rate but did not
stop it.

`config/models.yml` supports a per-purpose override and the Anthropic path works.
This costs spend and moves career prose off-box.

**Regardless of the answer: do not send anything to an employer that came out of
that model unreviewed.**

ANSWER:

### [ ] B3 — Authorize an audit of what the just3ws session published publicly?

That session fabricated the handshake above. On 2026-08-21 it also rewrote your
GitHub bio, published `profile/README.md` for three orgs (phalanxduel,
wwworkremote, ugtastic), edited descriptions on five repos, and published a
retrospective blog post under your name — with specific claims ("207-interview
corpus", "188 videos", "audited cleanly for prose humanity").

I have **no evidence those are wrong.** I have evidence that the same session
fabricates when it summarizes, and one confirmed factual error already (the 2009
timeline). These are public and about your professional identity.

Estimate: about an hour — `gh api` the bios and org READMEs, diff numeric claims
against `_data/video_assets.yml` and the database.

ANSWER (yes / no / later):

### [ ] B4 — The capability exchange with just3ws

wwworkremote proposes a division of labour and asked me to relay it. **I can't** —
there is no live just3ws agent session; `ListAgents` shows only wwworkremote.

Its proposal: `wwworkremote produces EVIDENCE` (ranked matches, cosine distances,
named gaps, its `bin/wwwr match` scorer — the only thing that should score) and
`just3ws produces LANGUAGE` (voice, narrative, the words you actually send).
Neither does the other's half; both failure modes already happened.

It also wants to stop reading your just3ws working tree off disk and consume
`resume.json` over HTTP instead. That is the right boundary and I agree with it.

How do you want this routed — start a just3ws session, have wwworkremote proceed
unilaterally, or park it?

ANSWER:

---

## C. Blocked on your permission

### [ ] C1 — Delete 3 test messages from the `zdots` bus channel

I created them verifying the `/bus` write path. The auto-mode classifier blocked
the delete and I did not route around it. Either add a Bash permission rule, or
run this yourself as `zdots_rw` (the FK from `bus_channel_members` has no
`ON DELETE`, so cursors must be nulled first):

```sql
BEGIN;
CREATE TEMP TABLE doomed AS
  SELECT m.id FROM bus_messages m
  JOIN bus_channels c ON c.id = m.channel_id
  WHERE c.name = 'zdots';
SELECT count(*) FROM doomed;              -- expect 3
UPDATE bus_channel_members SET last_read_message_id = NULL
  WHERE last_read_message_id IN (SELECT id FROM doomed);
DELETE FROM bus_messages WHERE id IN (SELECT id FROM doomed);
COMMIT;
```

ANSWER (I'll run it / add the permission rule / leave them):

### [ ] C2 — Keep the `my_test` database?

I created it to make context-engine's spec suite runnable at all. It should stay —
without it the suite cannot run — but you own the machine. Drop with
`dropdb my_test`.

ANSWER (keep / drop):

---

## D. Yes-or-no, and I'll do it

Each of these is flagged, unowned, and waiting on a single word.

| # | Item | Detail |
|---|---|---|
| [ ] D1 | **11 Dependabot vulns on `my`** | 1 critical, 4 high, 5 moderate, 1 low. Surfaced on push. Nobody has looked. |
| [ ] D2 | **OpenObserve at 107M** | Over your 100M threshold; it is what turned the doctor warning amber. `/telemetry-volume` fixes volume at the source. |
| [ ] D3 | **`adots-doctor` rc=1** | `~/.docker` coexisting with canonical `~/.config/docker`. It ships a `--fix`. |
| [ ] D4 | **Code graph stale** | Built at `3ebb4491`, HEAD is far past it. `/graphify` refreshes. |
| [ ] D5 | **Z-312 — triage the 22 spec failures** | context-engine is 114 examples / 22 failures. Several look seed-dependent (empty test DB has no policy rules), so 22 is an upper bound on real defects. Needs triage, not a blanket fix. |
| [ ] D6 | **Z-310 — bus authentication** | Per-participant token in Keychain, checked on post, issued by `bus-register`. This is the fix that makes bus attribution mean something. |
| [ ] D7 | **Z-311 — `publisher.rb:29`** | Same `\'` gsub trap as Z-297 but argv-form, no shell. Mangles VTT paths containing an apostrophe. Low. |

ANSWER (list the numbers you want done):

---

## Not on this list

Deliberately excluded because they need no decision from you: pointing
wwworkremote's importer at `resume.json`, applying the A1 values once given,
adding the A4 blocks once you supply the numbers, and the Z-162 Sequel port.
All code, none blocked on you.
