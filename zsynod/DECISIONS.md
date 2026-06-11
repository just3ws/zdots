# zsynod Decisions

ADR-shaped log of design decisions for the forum itself — the same
QUESTION / ALTERNATIVES / DISSENT discipline the scribe applies to ratified
proposals, applied to the machinery. A decision without its question is a 42.

Format: each record is the decision, the question it answered, the
alternatives not adopted, and the known risks (standing dissent). Newest
last. Operational details live in [LIFECYCLE.md](LIFECYCLE.md).

---

## D-001 — Blind voting (2026-06-11)

**DECISION:** Members who have not voted on the live topic deliberate with
everyone else's votes stripped from context and the `[STATE]` tally
withheld. Own votes stay visible. Dial `blind_votes`, default on.

**QUESTION:** The forum went 142–1 in its first epoch. Agents saw the
running tally and prior ayes in their context window before casting — the
textbook information cascade. How do we get positions from arguments
instead of scoreboards?

**ALTERNATIVES:** Simultaneous-reveal voting (hold all votes until round
end — rejected: heavy machinery, breaks the append-only flow); prompting
"vote independently" (rejected: instruction, not structure — structure
wins); randomizing vote order (rejected: weakens but doesn't remove the
cascade).

**DISSENT/RISKS:** A blind member may re-litigate a settled tally or
duplicate a decisive vote; the `[STATE]` summary's blocker/next-action
content is withheld along with its tally. Accepted: one slightly redundant
turn is cheaper than a cascade.

## D-002 — Devil's advocate seat (2026-06-11)

**DECISION:** One seat per proposal, rotated deterministically over the
sorted roster by proposal number, must state the strongest case against
before voting (may still vote aye, after the objection is recorded). Dial
`advocate`, default on.

**QUESTION:** When everyone genuinely agrees, the record holds no
counterargument — `ALTERNATIVES: none raised` — and future readers can't
tell consensus from cascade. Who owes the forum the case against?

**ALTERNATIVES:** A permanently seated contrarian member (exists — red-team,
P20 — but a dedicated seat externalizes dissent: everyone else stays free to
conform); forcing a nay quota (rejected: fake dissent is worse than none);
adversarial prompts for all members (rejected: blunts every voice instead of
sharpening one).

**DISSENT/RISKS:** The advocate's objection may be performative. Accepted:
a performative objection still surfaces an alternative for the record, which
is the goal. Precedent: advocatus diaboli, abolished 1983, canonizations
rose ~20×.

## D-003 — Unanimity action / second reading (2026-06-11)

**DECISION:** Dial `unanimity_action`: 0 = commit silently; 1 (default) =
commit and record unanimity as a fact in the minutes; 2 = the Sanhedrin
rule — a zero-nay quorum is held one round with a `second_reading` ledger
entry, the `⚖` event outranks all topic events ("find what everyone
missed"), and the next recognition pass commits whatever survives.
Principal `ratify` always bypasses.

**QUESTION:** In a forum with a sycophancy history, is a unanimous verdict
evidence of correctness or of process failure — and what should the
machinery do about it?

**ALTERNATIVES:** Auto-rejecting unanimous verdicts (the literal Sanhedrin
rule — rejected: most zsynod proposals are low-stakes and genuinely
agreeable); mandatory minority report on every commit (deferred: dissent
capture in the scribe covers the record half).

**DISSENT/RISKS:** Second reading adds a full round of latency (and cloud
tokens) to exactly the proposals that looked easiest. That asymmetry is the
point, but it's why 1, not 2, is the default.

## D-004 — Reasoned votes, ASSENT recorded (2026-06-11)

**DECISION:** `>vote P# aye|nay|abstain <reason>` — the reason rides the
vote entry as `note`. The decision lesson gains an ASSENT line listing
every aye voter with their reason; a bare aye is recorded as
`no reason given`.

**QUESTION:** A nay needed a reason to be useful but an aye was free — that
asymmetry *is* the sycophancy gradient. How do we make an aye cost
something without blocking it?

**ALTERNATIVES:** Rejecting unreasoned votes at the parser (rejected:
silently dropped votes corrupt tallies and punish small local models
hardest); minimum-length reasons (rejected: produces padding, not reasons).

**DISSENT/RISKS:** Models may emit boilerplate reasons. Accepted:
boilerplate in the record is still attributable and visible — and the aye%
gauge (D-005) catches the pattern.

## D-005 — aye% gauge (2026-06-11)

**DECISION:** The cockpit Members tab shows per-member aye-rate; `⚠` at
≥90% over 5+ votes. The herald's fact sheet carries the same number.

**QUESTION:** Sycophancy was an anecdote (142–1) until it was measured.
What makes it continuously visible?

**ALTERNATIVES:** Acting on the metric automatically (muting or
down-weighting yes-machines — rejected for now: what gets graphed gets
gamed; let the operator and chair act on it first).

**DISSENT/RISKS:** Small-N noise — hence the 5-vote floor before the flag.

## D-006 — Glyph brackets the prompt (2026-06-11)

**DECISION:** The per-tick glyph is the first and the last character of
the **full dispatch** a member receives: it opens the system prompt and
closes the user message, so both the combined CLI prompt
(`system\n\nuser`) and the rendered chat-completions stream begin and end
with the round's glyph. *(Amended same day: the first cut bracketed only
the user message — the identical system prompt still led every dispatch,
which is exactly the static prefix provider caches ride on. The principal
caught it: no glyph visible at the head of outbound prompts.)* The pool is
the 73 Taoist glyphs plus archetypal emoji (moon phases mirroring the
eight trigrams; water, fire, sprout, leaf, spiral, dragon, Zhuangzi's
butterfly, mirror, key, hourglass, compass, stone, owl, feather) — rich
meaning at one-token cost. Forum protocol markers (⚡ ⚖ 😈 💭 📚 📜) are
excluded so the seed never reads as protocol.

**QUESTION:** Leading-only glyph seeding proved insufficient entropy —
provider-side prompt caching can ride identical bodies to near-identical
remarks. How do we break the cache at both ends without touching content?

**ALTERNATIVES:** Random nonce in the prompt (rejected: noise with no
meaning; the glyph is already the round's shared seed); per-member glyphs
(rejected: the same symbol across all voices is the point — shared nudge,
no coordination); hexagrams only (superseded: emoji carry the same
dense-symbol-per-token property and the models know their meanings cold).

**DISSENT/RISKS:** Models occasionally echo the glyph in their remark.
Harmless; the directive parser is unaffected. A glyph leading the system
prompt could in principle be read as an instruction; archetypes (not
imperatives) keep that risk negligible.

## D-007 — The herald (2026-06-11)

**DECISION:** Every `digest_every` ticks (default 3; `digest` on demand)
the local model narrates a deterministic chain-derived fact sheet into a
plain-English briefing — log + `zsynod/minutes.md`. Clerk duty: local
model only, never a deliberation voice, degrades silently.

**QUESTION:** The principal funds the forum but can only follow it by
reading a hash-chained ledger. What is the humane view of who is voting
and proposing?

**ALTERNATIVES:** A dashboard pane of derived stats (already exists —
Members tab — but tables aren't narrative); cloud-model briefings
(rejected: clerks defer to the local LLM by doctrine — fluidity comes from
frequency, and frequency must be free).

**DISSENT/RISKS:** A 7B narrator will occasionally garble a tally. The
fact sheet is deterministic and the ledger remains authoritative; the
briefing is a view, never a source.

## D-008 — The member contract (2026-06-11)

**DECISION:** `ZsynodAgent` is the seat abstraction: prompts in, remark
out, backend bound once at seating. Three backends — `local` (llama.cpp),
`cli` (claude/gemini/codex subprocess), `openai` (any OpenAI-compatible
`/chat/completions`: `base_url` + `model` + optional `key_env`). Seats load
from `members.json`; recruiting is a data row. Keys come from the
environment only (shell sources `.zdots.secrets`); declared-but-missing
key → the seat fails loudly and the breaker benches it; no `key_env` →
keyless loopback (apfel, ollama). Dormant seats are announced at startup.

**QUESTION:** Recruiting groq, mistral, GitHub Models, or Hugging Face
seats meant writing a `_deliberate_<vendor>` method each time. What is the
predictable interface that abstracts the system being queried from the
system querying?

**ALTERNATIVES:** Per-vendor adapter classes (rejected: nearly every
candidate — groq, mistral, GitHub Models, HF router, OpenRouter, Cerebras,
Together, DeepSeek, apfel, ollama — speaks the same chat-completions
dialect; one transport covers them all); LiteLLM/langchain dependency
(rejected: stdlib urllib already does this; zsynod stays dependency-light).

**DISSENT/RISKS:** Vendor quirks (e.g. apfel 400s on a missing `model`
field) surface as per-seat config, which is where they belong. Cloud seats
move prompts off-box: PHI doctrine unchanged — remarks must stay free of
patient data; the scrub-at-source rule predates this contract.

## D-009 — @apfel seated (2026-06-11)

**DECISION:** Apple Intelligence joins as @apfel — tier local, non-voting,
experimental — via the keyless-loopback `openai` backend
(`http://127.0.0.1:11434/v1`, model `apple-foundationmodel`, served by
`brew services start apfel`). Shell entry point `zapfel`
(`providers/tools/apfel.zsh`), lazy-loaded like zpi/zaider/zopencode.
Live-verified end to end (non-streaming and SSE) on seating day.

**QUESTION:** A second on-device model is available for free on this
hardware. Does the forum get more from another voice than it costs in
tick time?

**ALTERNATIVES:** Voting seat (rejected: opencode/P18 precedent —
experimental seats prove themselves first; quorum unchanged); clerk-only
duty (rejected: clerks are the local llama's job; apfel's value is a
*different* model's perspective, which is a deliberation property).

**DISSENT/RISKS:** 4096-token context window — the tightest at the table;
deep threads must rely on the [STATE] pin. Guardrails are Apple's, not
ours: expect occasional refusals on innocuous prompts (exit-code-3
equivalent); the breaker handles them as ordinary failures. Seat is
reversible; voting reviewed after observation.

## D-010 — @gh seated; key_cmd in the member contract (2026-06-11)

**DECISION:** GitHub Models joins as @gh — frontier tier, non-voting,
experimental — via the `openai` backend (`https://models.github.ai/inference`,
default `openai/gpt-4o-mini`; the catalog spans OpenAI/DeepSeek/Llama/
Mistral/Cohere behind one seat, switchable per `model` field). The member
contract gains `key_cmd`: a shell command that prints the key, fetched once
per seat, held in memory only — `key_env` wins when both are set. @gh uses
`key_cmd: "gh auth token"` — the existing gh OAuth keyring token authorizes
models.github.ai (verified live: non-streaming, SSE, catalog). Shell entry
point `zgh` (`providers/tools/gh-models.zsh`): one-shot prompts and
`--models`, with prompt AND piped stdin passed through `phi_scrub`, and a
hard refusal to send if the scrubber can't be loaded.

**QUESTION:** GitHub Models is effectively free at zsynod's 160-token scale
and already authenticated on this machine — but the forum's seats resolved
keys only from the environment, and no shell launcher exists to export one
before the TUI starts. How does a seat obtain a key that lives in a keyring?

**ALTERNATIVES:** Export `GH_MODELS_TOKEN` at shell startup (rejected:
~50–100ms of `gh auth token` on every shell, against zdots' startup
budget, for a seat that may not convene); a `gh models` CLI adapter
(rejected: the extension isn't installed and the chat-completions endpoint
is already covered by the `openai` backend); a PAT in `.zdots.secrets`
(rejected: a second credential to rotate when the keyring token already
authorizes the API).

**DISSENT/RISKS:** `key_cmd` executes a config-supplied command via the
shell — members.json is tracked, operator-owned config, same trust level as
the code, but a malicious edit there now has an execution path; review
members.json diffs like code. CLOUD seat: remarks leave the box (PHI
doctrine unchanged), GitHub applies content filters and may train-log per
its terms — same posture as the claude/gemini/codex CLI seats. Free-tier
rate limits are real; the circuit breaker absorbs 429s as ordinary
failures.

## D-011 — @hf and @openrouter seated; malformed keys refused (2026-06-11)

**DECISION:** Two more cloud seats via the `openai` backend, zero new code
paths. @hf — Hugging Face router (`https://router.huggingface.co/v1`,
default `Qwen/Qwen3-235B-A22B-Instruct-2507`, ~120-model open-weights
catalog). @openrouter — OpenRouter (`https://openrouter.ai/api/v1`, default
`openai/gpt-oss-120b:free`; the `:free` tier fits forum-scale 160-token
remarks). Both non-voting experimental, quorum unchanged, keys via
`key_cmd: "tail -n 1 <token file>"` against the two-line (label + token)
files in `tmp/`. `tmp/` added to `.gitignore` — it was one `git add .` from
committing both tokens. The member contract now refuses any resolved key
containing interior whitespace, raising a clean "malformed key" RuntimeError
that never quotes the key.

**QUESTION:** Both tokens were parked in `tmp/` as two-line files. A naive
`cat` key_cmd produced a key with an embedded newline — and http.client's
`Invalid header value` ValueError embeds the full header, key included, into
an exception the TUI logs. How does a seat consume file-parked tokens
without ever letting one ride an error path?

**ALTERNATIVES:** Normalizing keys silently (strip/last-line inside the
contract — rejected: guessing at file formats hides operator mistakes; the
seat config owns its extraction); Keychain from day one (preferred
endgame — `key_cmd: "security find-generic-password …"` is a one-field
edit — but the tokens were already in `tmp/` and the seats shouldn't wait).

**DISSENT/RISKS:** During seating, the pre-hardening traceback printed the
HF token into a cloud session — rotate it at huggingface.co. Tokens in
flat files in `tmp/` remain weaker than Keychain even gitignored; migration
recommended. OpenRouter `:free` models 429 under congestion
(llama-3.3-70b:free was saturated at seating); the breaker treats that as
an ordinary failure and the seat's `model` field is the dial.

## D-012 — The pawl: chain verified on every load (2026-06-12)

**DECISION:** `LedgerManager.load()` walks the hash chain as it reads —
every entry's `prev` must equal the prior entry's hash, every stored hash
must recompute from its own raw line. Any break raises
`LedgerIntegrityError` naming the seq and line; the cockpit (`zsynod ui`)
refuses to open on a ledger that fails, with instructions to restore
rather than reconvene. Verified against the live chain (1179 entries)
before enforcement.

**QUESTION:** The design review found the ratchet had no pawl: hashes were
computed on append but never checked on read, and the Bash `verify` walks
the *old* ledger. A ratchet that cannot detect slipping backward is a
wheel. What makes append-only a checked promise instead of an assumed one?

**ALTERNATIVES:** A separate `verify` subcommand run on demand (rejected
as the only gate: integrity checked occasionally is integrity assumed
usually — though the Bash-side verb remains for the old ledger); verifying
only on TUI launch, not every load (rejected: `load()` is called on every
append under the lock, so the walk is nearly free and covers all readers).

**DISSENT/RISKS:** A legitimately hand-edited ledger (there should be no
such thing) now refuses to load — that is the point, but recovery requires
restoring from backup or re-migrating, not editing the complaint away.
O(n) hashing per load is negligible at forum scale (1179 entries, ms).

## D-013 — The door: petitions and receipts (2026-06-12)

**DECISION:** Outside voices reach the cockpit forum through two verbs.
`zsynod say --as <agent> [--kind ask|inform|propose|statement]
[--to @m,@m] "text"` appends a `speak` entry to the Python ledger via
`LedgerManager.petition()` — lock-safe, hash-correct, pawl-verified — and
prints the entry's seq as a receipt. The TUI's 3-second poll notices it,
the silence window resets, and the 📥 mention scheduler dispatches it to
the named members oldest-first, exactly as it does member remarks.
`zsynod reply <seq> [--json]` reports the chain-derived state: `addressed`
(responses listed), `heard` (forum convened, petitioner not yet addressed),
or `unheard` (no session convened since). Petitioners hold no seat — zero
vote weight, quorum untouched — and petition content passes `phi_scrub` at
the door, with a hard refusal if the scrubber is unavailable.

**QUESTION:** The Bash CLI's submission verbs write the old `ledger.jsonl`;
the convened forum runs on `ledger.py.jsonl` — outsiders were petitioning
an empty room. How do zdots and its dependencies inform the forum and learn
its answer (or its honest silence) so the whole system can make safe,
iterative decisions?

**ALTERNATIVES:** An inbox file the TUI ingests at tick start (rejected:
the ledger already IS the inbox — the lock, the pawl, the 3s poll, and the
mention scheduler were all in place; a second queue is a second truth);
a new `petition` entry type (rejected: the scheduler and context builder
dispatch and render `speak` — metadata in `data` marks the role without
teaching every reader a new type); an MCP server first (deferred: interfaces
arrive non-voting too — the CLI proves the shape, MCP earns its place when
an application that cannot shell out needs the door).

**DISSENT/RISKS:** `--as` identity is asserted, not authenticated — any
process may speak as any petitioner; acceptable on a single-operator box,
revisit if the door is ever networked. A flood of petitions would reset
the silence window repeatedly and starve auto-ticks; unthrottled for now,
the operator is the rate limit. Mention-based response detection misses a
reply that fails to @mention the petitioner — `heard` understates, never
overstates.
