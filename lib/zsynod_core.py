import json
import os
import hashlib
import datetime
import re
import subprocess
import tempfile
import uuid
import random
import urllib.request
from pathlib import Path
from pydantic import BaseModel, Field
from typing import Any, List, Optional

# Hard wall-clock budgets for all tick paths.
# LOCAL_TICK_TIMEOUT is per-read on the SSE stream — if the model stalls for
# this long between tokens the request is aborted, same as a hung external CLI.
TICK_TIMEOUT = 45        # external CLIs (claude, gemini, codex)
LOCAL_TICK_TIMEOUT = 90  # llama.cpp HTTP/SSE — local inference can be slower
_MIN_TIMEOUT = 8.0       # floor — never shorter than this regardless of backoff

# A topic with no vote/second movement in this many ledger entries is STUCK.
# ~3 ticks at current roster size (6 speaks + summary per tick).
STALE_AFTER = 25

# ── Dials: the operator's control plane ──────────────────────────────────────
# Persisted to zsynod/dials.json so the TUI and headless pulse share one set.
# Every numeric dial is clamped to [min, max] on load — a hand-edited file
# can't push the forum into an undefined regime.

DIALS: dict[str, dict] = {
    "spontaneity":    {"default": 0.15, "min": 0.0, "max": 1.0, "step": 0.05,
                       "help": "chance a member's turn becomes a 💭 free thought "
                               "instead of the scheduler chain"},
    "temperature":    {"default": 0.7,  "min": 0.1, "max": 1.5, "step": 0.1,
                       "help": "llama.cpp sampling temperature for local voices"},
    "max_tokens":     {"default": 220,  "min": 60,  "max": 600, "step": 20,
                       "help": "hard token cap per local remark"},
    "loop_threshold": {"default": 0.55, "min": 0.2, "max": 1.0, "step": 0.05,
                       "help": "remark-overlap ratio above which a member is "
                               "looping and gets a forced 💭 loop-breaker"},
    "loop_window":    {"default": 3,    "min": 2,   "max": 8,   "step": 1,
                       "help": "how many recent remarks the loop detector compares"},
    "context_depth":  {"default": 5,    "min": 2,   "max": 20,  "step": 1,
                       "help": "ledger entries quoted in each member's prompt"},
    "auto_interval":  {"default": 60,   "min": 15,  "max": 600, "step": 15,
                       "help": "auto-pilot: seconds of forum silence before the "
                               "next tick fires; any new ledger entry resets the "
                               "countdown"},
    "auto_max_ticks": {"default": 12,   "min": 1,   "max": 99,  "step": 1,
                       "help": "auto-pilot run cap — pauses after this many "
                               "consecutive unattended ticks so cloud seats "
                               "can't burn tokens forever; re-engage deliberately"},
    "kb_dispatch":    {"default": 0.3,  "min": 0.0, "max": 1.0, "step": 0.05,
                       "help": "chance a 💭 free thought is seeded from the zdots "
                               "knowledge base (📚) — a lesson or methodology the "
                               "member must weigh against the platform as it is"},
    "scribe":         {"default": 1,    "min": 0,   "max": 1,   "step": 1,
                       "help": "secretary duty: 1 = every ratified decision is "
                               "written back to the knowledge base as a lesson "
                               "via zdots-ctx add-lesson; 0 = forum keeps no "
                               "external minutes"},
    "blind_votes":    {"default": 1,    "min": 0,   "max": 1,   "step": 1,
                       "help": "anti-cascade: members who haven't voted on a "
                               "topic see the discussion but not others' votes "
                               "or the tally — argue with the thread, not the "
                               "scoreboard"},
    "advocate":       {"default": 1,    "min": 0,   "max": 1,   "step": 1,
                       "help": "advocatus diaboli: one seat per proposal "
                               "(deterministic rotation) must state the "
                               "strongest case against before voting"},
    "unanimity_action": {"default": 1,  "min": 0,   "max": 2,   "step": 1,
                       "help": "when a proposal reaches quorum with zero nays: "
                               "0 = commit silently, 1 = commit + flag in the "
                               "minutes, 2 = hold one round for a second "
                               "reading before committing (Sanhedrin rule)"},
    "digest_every":   {"default": 3,    "min": 0,   "max": 20,  "step": 1,
                       "help": "herald duty: every N ticks the local model "
                               "writes a plain-English briefing of forum state "
                               "to the log and zsynod/minutes.md; 0 = off"},
    "wip_limit":      {"default": 3,    "min": 1,   "max": 10,  "step": 1,
                       "help": "max open proposals at one time; new proposals "
                               "are rejected until existing ones are ratified or "
                               "closed — prevents the forum from accumulating "
                               "an ever-growing open list nobody votes on"},
    "max_tokens_frontier": {"default": 400, "min": 60, "max": 1200, "step": 40,
                       "help": "hard token cap per frontier (CLI / OpenAI-compat) "
                               "remark; local seats use max_tokens; higher budget "
                               "allows more context and coaching depth from "
                               "frontier models"},
    "stuck_close_after": {"default": 50, "min": 10, "max": 200, "step": 5,
                       "help": "entries of silence after which a STUCK proposal "
                               "is auto-closed; STALE_AFTER (25) marks it STUCK, "
                               "this threshold closes it — set higher to let "
                               "slow-moving proposals breathe"},
}


def load_dials(path) -> dict:
    """Defaults merged with whatever is on disk; numerics clamped, unknown keys
    dropped. Missing or corrupt file → pure defaults (the forum always runs)."""
    dials: dict[str, Any] = {k: v["default"] for k, v in DIALS.items()}
    dials["muted"] = []
    try:
        on_disk = json.loads(Path(path).read_text())
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return dials
    for k, v in on_disk.items():
        if k in DIALS and isinstance(v, (int, float)) and not isinstance(v, bool):
            spec = DIALS[k]
            v = min(max(v, spec["min"]), spec["max"])
            dials[k] = int(v) if isinstance(spec["default"], int) else float(v)
        elif k == "muted" and isinstance(v, list):
            dials["muted"] = [str(m) for m in v]
    return dials


def save_dials(path, dials: dict) -> None:
    Path(path).write_text(json.dumps(dials, indent=2, sort_keys=True) + "\n")


_LOOP_WORD_RE = re.compile(r"[a-z']{3,}")


def _remark_tokens(text: str) -> set:
    """Token set for loop detection. Hashtags and @handles repeat by design
    (3-hashtag rule, mention habit) — strip them so only substance is compared."""
    text = re.sub(r"[#@]\w[\w-]*", " ", text.lower())
    return set(_LOOP_WORD_RE.findall(text))


class AgentCircuitBreaker:
    """Per-agent exponential backoff with a shrinking timeout budget.

    Each consecutive timeout doubles the skip gap and halves the allowed time
    on the next attempt. A single success resets everything. The wheel keeps
    rolling — other agents are never blocked.
    """

    MAX_SKIP_TICKS = 8  # caps the skip window (2^3 = 8)

    def __init__(self, base_timeout: float):
        self.base_timeout = base_timeout
        self._consecutive = 0       # consecutive timeout count
        self._skip_remaining = 0    # ticks left to skip

    # ── called once per agent slot per tick ───────────────────────────────────

    def is_ready(self) -> bool:
        """Return True if this agent should run this tick; False to skip."""
        if self._skip_remaining > 0:
            self._skip_remaining -= 1
            return False
        return True

    def current_timeout(self) -> float:
        """Timeout budget for this attempt: halves each consecutive failure."""
        shrunk = self.base_timeout / (2 ** self._consecutive)
        return max(shrunk, _MIN_TIMEOUT)

    def skip_label(self) -> str:
        """Human-readable skip reason for the TUI log."""
        return (
            f"backing off ({self._consecutive} timeouts, "
            f"{self._skip_remaining + 1} ticks remaining, "
            f"next budget {self.current_timeout():.0f}s)"
        )

    # ── called after each attempt ─────────────────────────────────────────────

    def record_timeout(self) -> None:
        self._consecutive += 1
        skip = min(2 ** (self._consecutive - 1), self.MAX_SKIP_TICKS)
        self._skip_remaining = skip

    def record_success(self) -> None:
        self._consecutive = 0
        self._skip_remaining = 0

# ── Directive lines: voice → ballot ──────────────────────────────────────────
# Agents act by ending lines with '>'. The parser is pure syntax — semantic
# validation (does the proposal exist? is the member seated?) belongs to the
# caller, which holds ledger state.

_DIRECTIVE_RE = re.compile(r"^\s*>\s*(vote|second|propose|handoff|pass|close|body)\b\s*(.*)$",
                           re.IGNORECASE)


def _parse_one_directive(verb: str, rest: str) -> Optional[tuple]:
    if verb == "vote":
        m = re.match(r"(?i)^(p\d+)\s+(aye|nay|abstain)\b[\s:—–-]*(.*)$", rest)
        if m:
            data = {"proposal": m.group(1).upper(), "vote": m.group(2).lower()}
            # An aye should cost a sentence, same as a nay. The reason rides
            # the vote entry as `note`; bare votes are recorded as such in the
            # decision lesson — visibility is the enforcement.
            if m.group(3).strip():
                data["note"] = m.group(3).strip()
            return ("vote", data)
    elif verb == "second":
        m = re.match(r"(?i)^(p\d+)\b", rest)
        if m:
            return ("second", {"proposal": m.group(1).upper()})
    elif verb == "propose":
        if rest:
            return ("propose", {"title": rest})
    elif verb == "handoff":
        m = re.match(r"^@?(\w[\w-]*)\s+(.+)$", rest)
        if m:
            return ("handoff", {"to": m.group(1), "task": m.group(2).strip()})
    elif verb == "pass":
        return ("pass", {"note": rest} if rest else {})
    elif verb == "close":
        m = re.match(r"(?i)^(p\d+)\b[\s:—–-]*(.*)$", rest)
        if m:
            data: dict = {"proposal": m.group(1).upper()}
            if m.group(2).strip():
                data["reason"] = m.group(2).strip()
            return ("close", data)
    elif verb == "body":
        m = re.match(r"(?i)^(p\d+)\s+(.+)$", rest)
        if m:
            return ("body", {"proposal": m.group(1).upper(), "body": m.group(2).strip()})
    return None


def parse_directives(remark: str) -> tuple[str, list[tuple[str, dict]]]:
    """Split agent output into clean speech and structured ledger intents.

    Grammar — one directive per line, line must start with '>':
        >vote P# aye|nay|abstain [reason]
        >second P#
        >propose <title>
        >handoff @member <task>
        >close P# [reason]        — proposer closes own topic; others cast a close vote
        >body P# <decision text>  — record a decision into the proposal body
        >pass [reason]

    Returns (speech_without_directive_lines, [(entry_type, data), ...]).
    A malformed directive line stays in the speech — visible feedback to the
    forum beats silently losing it.
    """
    kept: list[str] = []
    directives: list[tuple[str, dict]] = []
    for line in remark.splitlines():
        m = _DIRECTIVE_RE.match(line)
        parsed = _parse_one_directive(m.group(1).lower(), m.group(2).strip()) if m else None
        if parsed is None:
            kept.append(line)
        else:
            directives.append(parsed)
    return "\n".join(kept).strip(), directives


# 8 trigrams + yin-yang + 64 I Ching hexagrams (U+4DC0–U+4DFF).
# One glyph is rolled per tick and brackets every agent's prompt —
# same symbol across all voices, nudging probability without coordination.
TAOIST_GLYPHS: list[str] = (
    ["☯", "☰", "☱", "☲", "☳", "☴", "☵", "☶", "☷"]
    + [chr(0x4DC0 + i) for i in range(64)]
)

# Emoji carry the same property the hexagrams do: a single low-cost token
# dense with meaning a model already knows. Archetypes only — the eight
# moon phases mirror the eight trigrams, the rest are Taoist staples
# (water that yields, the butterfly of Zhuangzi's dream). Glyphs the forum
# already uses as markers (⚡ event, ⚖ second reading, 😈 advocate,
# 💭/📚 free thought, 📜 herald) are excluded — the seed must never read
# as protocol.
EMOJI_GLYPHS: list[str] = [
    "🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘",   # the moon's eight phases
    "🌊", "🔥", "🌱", "🍃", "🌀", "🐉", "🦋", "🪞",   # flow, change, growth, dream
    "🔑", "⏳", "🧭", "🪨", "🦉", "🪶",                # way-finding, stillness, wisdom
]

GLYPH_POOL: list[str] = TAOIST_GLYPHS + EMOJI_GLYPHS


def tick_seed() -> str:
    """Return a random glyph — Taoist or archetypal emoji — to seed a tick."""
    return random.choice(GLYPH_POOL)


def devils_advocate(pid: str, roster: List[str]) -> Optional[str]:
    """The advocatus diaboli seat for a proposal — deterministic rotation so
    every member knows who holds the duty without coordination. The Church
    abolished the office in 1983 and canonizations went up twentyfold; this
    forum went 142–1. One seat per proposal must argue against."""
    if not roster:
        return None
    num = int(re.sub(r"\D", "", pid) or 0)
    return sorted(roster)[num % len(roster)]

# Stable session identity for Gemini — UUID5 derived from name, same value every tick.
_GEMINI_SESSION_ID = str(uuid.uuid5(uuid.NAMESPACE_DNS, "zsynod-gemini"))


class LedgerIntegrityError(RuntimeError):
    """The hash chain failed verification on load. A ratchet that cannot
    detect slipping backward is a wheel — this is the pawl. Raised loud:
    a forum must not deliberate on a ledger it cannot trust."""


class LedgerEntry(BaseModel):
    seq: int
    ts: str = Field(default_factory=lambda: datetime.datetime.utcnow().isoformat() + "Z")
    round: int
    actor: str
    type: str
    data: dict[str, Any]
    prev: str
    hash: Optional[str] = None

    def compute_hash(self, raw_line: Optional[str] = None) -> str:
        """
        Replicates Bash logic: _hash "${prev}${canon}"
        where canon is jq -Sc . (sorted keys, compact, NO SPACES, no ASCII escape)
        """
        if raw_line:
            data = json.loads(raw_line)
            if "hash" in data:
                del data["hash"]
        else:
            data = self.model_dump(exclude={'hash'})

        canon = json.dumps(data, sort_keys=True, separators=(',', ':'), ensure_ascii=False)
        content = f"{self.prev}{canon}".encode()
        return hashlib.sha256(content).hexdigest()


class KnowledgeBase:
    """Read/write bridge between the forum and the zdots knowledge layer.

    All traffic goes through the sanctioned `zdots-ctx` interface — reads via
    `hydrate --json`, writes via `add-lesson` (the zdots_rw path; never raw
    SQL). The forum exists to deliberate the platform's accumulated knowledge,
    so this is its only window and its only pen:

      seed()    one random lesson/methodology — fuel for a 📚 dispatch
      ground()  the most relevant snippet for a topic title — pinned [KB] line
      record()  scribe duty — a ratified decision written back as a lesson

    Failure-tolerant by doctrine: KB down, command missing, slow response →
    None/empty and the forum keeps deliberating. It never blocks on its
    library. Hydrate results are cached per tag for the session — the KB
    changes on human timescales, ticks don't."""

    def __init__(self, cmd: str = "zdots-ctx", timeout: float = 12.0):
        self.cmd = cmd
        self.timeout = timeout
        self._cache: dict = {}

    def available(self) -> bool:
        import shutil
        return shutil.which(self.cmd) is not None

    def hydrate(self, tag: str = "") -> dict:
        key = tag or "_general"
        if key in self._cache:
            return self._cache[key]
        out = {"methodologies": [], "lessons": []}
        try:
            argv = [self.cmd, "hydrate"] + ([tag] if tag else []) + ["--json"]
            r = subprocess.run(argv, capture_output=True, text=True,
                               timeout=self.timeout)
            if r.returncode == 0 and r.stdout.strip():
                data = json.loads(r.stdout)
                if isinstance(data, dict):
                    out["methodologies"] = data.get("methodologies") or []
                    out["lessons"] = data.get("lessons") or []
        except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
            pass
        self._cache[key] = out
        return out

    @staticmethod
    def _snippet(item: dict, width: int = 240) -> str:
        body = " ".join((item.get("content") or "").split())
        if item.get("title"):
            return f"{item['title']}: {body}"[:width]
        return body[:width]

    def seed(self, rng=random) -> Optional[str]:
        pool = self.hydrate("")
        items = list(pool["methodologies"]) + list(pool["lessons"])
        if not items:
            return None
        return self._snippet(rng.choice(items))

    def ground(self, title: str) -> Optional[str]:
        """Best KB snippet for a topic title. Hydrates on the longest word of
        the title — crude but cached, and the semantic layer does the rest."""
        words = sorted(_LOOP_WORD_RE.findall(title.lower()), key=len, reverse=True)
        if not words:
            return None
        pool = self.hydrate(words[0])
        items = list(pool["methodologies"]) + list(pool["lessons"])
        return self._snippet(items[0]) if items else None

    def record(self, content: str, context: str = "", tags: List[str] = None) -> bool:
        try:
            argv = [self.cmd, "add-lesson", content, context] + list(tags or [])
            r = subprocess.run(argv, capture_output=True, text=True,
                               timeout=self.timeout * 2)
            return r.returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            return False


def format_decision_lesson(rec: dict, minute: str = "") -> str:
    """The scribe's lesson body — Deep Thought's lesson applied: a decision
    without its question is a 42. The deterministic record (verdict, proposer,
    dissent with stated reasons) always lands; the model-extracted
    QUESTION/ALTERNATIVES lines ride along when the local model was reachable.
    Unanimity is recorded as a fact — in a forum with a sycophancy history,
    no dissent is itself a signal."""
    t = rec["tally"]
    lines = [
        f"zsynod ratified {rec['pid']} \"{rec['title']}\" "
        f"(aye={t['aye']} nay={t['nay']} abs={t['abstain']}), "
        f"proposed by @{rec['proposer']}.",
    ]
    if minute:
        lines.append(minute.strip())
    elif rec["question"]:
        lines.append(f"QUESTION: {rec['question']}")
    if rec["dissent"]:
        for d in rec["dissent"]:
            reason = d["note"] or d["remark"] or "no reason recorded"
            lines.append(f"DISSENT: @{d['actor']} ({d['vote']}): {reason[:160]}")
    else:
        unanimous = "DISSENT: none — unanimous."
        if rec.get("second_reading"):
            unanimous += " Survived a second reading."
        lines.append(unanimous)
    if rec.get("assent"):
        parts = [f"@{a['actor']} — {a['note'][:80]}" if a["note"]
                 else f"@{a['actor']} — no reason given"
                 for a in rec["assent"]]
        lines.append("ASSENT: " + "; ".join(parts))
    return "\n".join(lines)


class ZsynodAgent:
    """One seat in the forum. The member contract: callers see `deliberate()`
    (and the clerk duties `summarize`/`minute`/`herald`); which system answers
    — local llama.cpp, a vendor CLI, or any OpenAI-compatible HTTP endpoint —
    is resolved once at seating time and never leaks into the calling code.
    Recruiting a new member is a members.json row, not a code change.

    Backends:
        local   llama.cpp at `endpoint` (sampling dials apply)
        cli     subprocess adapter — `command` ∈ {claude, gemini, codex}
        openai  any /chat/completions endpoint: groq, mistral, GitHub Models,
                HuggingFace router, OpenRouter, … (`base_url`, `model`,
                API key read from the environment via `key_env` — never from
                a file, and never logged)
    """

    def __init__(self, actor_id: str, endpoint: str = None, model: str = None,
                 backend: str = None, base_url: str = None,
                 key_env: str = None, key_cmd: str = None, command: str = None):
        self.actor_id = actor_id
        self.endpoint = (endpoint or os.environ.get("ZDOTS_AI_ENDPOINT", "http://127.0.0.1:11500")).rstrip("/")
        self.model = model  # None = per-actor default; override to force a specific model
        self.base_url = (base_url or "").rstrip("/")
        self.key_env = key_env
        self.key_cmd = key_cmd      # fallback: shell command that prints the key
        self._key_cache = ""        # key_cmd result, fetched once per seat
        self.command = command or actor_id
        # Legacy seats keep identity-based dispatch when no backend declared.
        if backend is None:
            backend = "cli" if actor_id in ("claude", "gemini", "codex") else "local"
        self.backend = backend

    def _build_context(self, recent_discussion: List[LedgerEntry], depth: int = 5,
                       blind_for: str = None) -> str:
        # Last few entries only — forces compression, keeps the prompt tight.
        # blind_for: anti-cascade — that member sees no one else's votes
        # (their own are kept so they remember where they stand).
        lines = []
        for e in recent_discussion[-depth:]:
            if e.type in ("vote", "second") and blind_for and e.actor != blind_for:
                continue
            if "remark" in e.data:
                lines.append(f"@{e.actor}: {e.data['remark']}")
            elif e.type == "propose":
                lines.append(f"@{e.actor} proposed {e.data['id']}: {e.data.get('title', '?')}")
            elif e.type == "vote":
                lines.append(f"@{e.actor} voted {e.data.get('vote', '?')} on {e.data.get('proposal', '?')}")
            elif e.type == "commit":
                lines.append(f"✓ {e.data.get('proposal', '?')} ratified")
        return "\n".join(lines)

    def _deliberate_local(self, system_prompt: str, user_prompt: str,
                          token_callback=None, timeout: float = None,
                          temperature: float = None, max_tokens: int = None) -> str:
        """OpenAI-compatible /chat/completions transport. Serves two backends:
        `local` (llama.cpp at self.endpoint, no auth) and `openai` (any compat
        vendor at self.base_url, bearer key from the env var named by
        self.key_env — the key never touches a file read or a log line)."""
        t = timeout or LOCAL_TICK_TIMEOUT
        body: dict[str, Any] = {
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "stream": token_callback is not None,
            "max_tokens": int(max_tokens or 220),
            "temperature": temperature if temperature is not None else 0.7,
        }
        if self.model:
            body["model"] = self.model
        headers = {"Content-Type": "application/json"}
        if self.backend == "openai":
            url = f"{self.base_url}/chat/completions"
            # Key resolution: env var first (operator override / rotation),
            # then key_cmd — a shell command that prints the key (gh auth
            # token, security find-generic-password …), fetched once per
            # seat and held in memory only; never logged, never written.
            # Neither declared → keyless loopback server (apfel, ollama).
            if self.key_env or self.key_cmd:
                key = os.environ.get(self.key_env, "") if self.key_env else ""
                if not key and self.key_cmd:
                    if not self._key_cache:
                        try:
                            self._key_cache = subprocess.run(
                                self.key_cmd, shell=True, capture_output=True,
                                text=True, timeout=10,
                            ).stdout.strip()
                        except (subprocess.TimeoutExpired, OSError):
                            self._key_cache = ""
                    key = self._key_cache
                src = self.key_env or f"`{self.key_cmd}`"
                if not key:
                    raise RuntimeError(f"{src} yielded no key — seat dormant")
                # A key with interior whitespace (multi-line file, label
                # prefix) would be embedded verbatim in http.client's
                # "Invalid header value" ValueError — and the TUI logs
                # str(e). Refuse it here, without quoting the key.
                if any(c.isspace() for c in key):
                    self._key_cache = ""
                    raise RuntimeError(
                        f"{src} yielded a malformed key (contains whitespace"
                        " — multi-line file?) — seat dormant")
                headers["Authorization"] = f"Bearer {key}"
        else:
            url = f"{self.endpoint}/v1/chat/completions"

        req = urllib.request.Request(
            url,
            data=json.dumps(body).encode(),
            headers=headers,
            method="POST",
        )

        full_remark = ""
        with urllib.request.urlopen(req, timeout=t) as resp:
            if token_callback:
                for raw_line in resp:
                    line = raw_line.decode().strip()
                    if not line.startswith("data:"):
                        continue
                    data = line[5:].strip()
                    if data == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data)
                        token = chunk["choices"][0]["delta"].get("content", "")
                        if token:
                            full_remark += token
                            token_callback(token)
                    except (json.JSONDecodeError, KeyError, IndexError):
                        continue
            else:
                body = json.loads(resp.read())
                full_remark = body["choices"][0]["message"]["content"]

        return full_remark.strip()

    def _deliberate_claude(self, system_prompt: str, user_prompt: str,
                           token_callback=None, suggestion_callback=None,
                           timeout: float = None) -> str:
        t = timeout or TICK_TIMEOUT
        model = self.model or "claude-haiku-4-5"
        prompt = f"{system_prompt}\n\n{user_prompt}"
        cmd = [
            "claude", "-p",
            "--output-format", "stream-json",
            "--verbose",
            "--model", model,
            "--safe-mode",
            "--prompt-suggestions",
            "--no-session-persistence",
            "--disallowedTools", "Bash,Edit,Write,NotebookEdit",
            "--append-system-prompt",
            "You are a member of the zsynod deliberation forum. Be concise.",
        ]
        result = subprocess.run(cmd, input=prompt, capture_output=True, text=True, timeout=t)
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or f"claude exited {result.returncode}")

        remark = ""
        suggestion = ""
        for line in result.stdout.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                t = obj.get("type", "")
                if t == "result":
                    remark = obj.get("result", "").strip()
                elif t == "prompt_suggestion":
                    suggestion = obj.get("suggestion", "").strip()
            except json.JSONDecodeError:
                continue

        if token_callback and remark:
            token_callback(remark)
        if suggestion_callback and suggestion:
            suggestion_callback(suggestion)
        return remark

    def _deliberate_gemini(self, system_prompt: str, user_prompt: str,
                           token_callback=None, timeout: float = None) -> str:
        t = timeout or TICK_TIMEOUT
        prompt = f"{system_prompt}\n\n{user_prompt}"

        def _cmd(resume=False):
            c = ["gemini",
                 "--resume" if resume else "--session-id", _GEMINI_SESSION_ID,
                 "--approval-mode", "plan", "-o", "json", "-p", prompt]
            if self.model:
                c += ["-m", self.model]
            return c

        result = subprocess.run(_cmd(), capture_output=True, text=True, timeout=t)
        # Session already exists from a prior tick — switch to --resume
        if result.returncode != 0 and "already exists" in result.stderr:
            result = subprocess.run(_cmd(resume=True), capture_output=True, text=True, timeout=t)

        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or f"gemini exited {result.returncode}")

        try:
            data = json.loads(result.stdout)
            remark = (data.get("response") or data.get("text") or data.get("content") or result.stdout).strip()
        except (json.JSONDecodeError, KeyError):
            remark = result.stdout.strip()

        if token_callback and remark:
            token_callback(remark)
        return remark

    def _deliberate_codex(self, system_prompt: str, user_prompt: str,
                          token_callback=None, timeout: float = None) -> str:
        t = timeout or TICK_TIMEOUT
        prompt = f"{system_prompt}\n\n{user_prompt}"
        fd, output_path = tempfile.mkstemp(suffix=".txt", prefix="zsynod-codex-")
        os.close(fd)
        try:
            cmd = ["codex", "exec", "--ephemeral", "-o", output_path]
            if self.model:
                cmd += ["-m", self.model]
            cmd.append(prompt)

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=t)
            if result.returncode != 0:
                raise RuntimeError(result.stderr.strip() or f"codex exited {result.returncode}")

            remark = Path(output_path).read_text().strip()
        finally:
            Path(output_path).unlink(missing_ok=True)

        if token_callback and remark:
            token_callback(remark)
        return remark

    def summarize(self, pid: str, title: str,
                  discussion: List[LedgerEntry], tally: dict) -> str:
        """Neutral state summary written to the ledger after each tick round.
        Not a deliberation voice — no hashtags, no opinion, no 160-token rule."""
        votes_str = " ".join(f"@{a}:{v[0]}" for a, v in sorted(tally["votes"].items()))
        tally_line = f"aye={tally['aye']} nay={tally['nay']} abs={tally['abstain']} ({tally['state']})"
        context_str = self._build_context(discussion)
        system_prompt = (
            "Neutral summarizer. Output compact proposal state only. "
            "No opinion. No hashtags. ≤80 tokens."
        )
        user_prompt = (
            f"{pid}: {title}\n"
            f"Tally: {tally_line}  Votes: {votes_str}\n"
            f"Recent:\n{context_str}\n"
            "Summarize: tally, each actor 1-word position, key blocker, next action."
        )
        return self._deliberate_local(system_prompt, user_prompt)

    def minute(self, pid: str, title: str,
               discussion: List[LedgerEntry], question: str = "") -> str:
        """ADR extraction for the scribe: the question behind the decision
        and the alternatives that lost. Neutral recorder voice, local model
        only — callers degrade to the deterministic record when this raises."""
        context_str = self._build_context(discussion, depth=12)
        system_prompt = (
            "Neutral recorder. From the thread, output exactly two lines:\n"
            "QUESTION: the problem this proposal answered, one sentence.\n"
            "ALTERNATIVES: competing approaches raised and not adopted, "
            "comma-separated; 'none raised' if the thread offered none.\n"
            "No opinion. No hashtags. ≤90 tokens."
        )
        hint = f"Proposer's framing: {question}\n" if question else ""
        user_prompt = (f"{pid}: {title}\n{hint}Thread:\n{context_str}\n"
                       "Write the two lines.")
        return self._deliberate_local(system_prompt, user_prompt)

    def herald(self, facts: str) -> str:
        """The principal's briefing: forum state in plain, humane English so a
        person can follow along without reading the ledger. Local model only —
        a clerk duty, not a deliberation voice."""
        system_prompt = (
            "You are the forum herald. From the fact sheet, write a short "
            "plain-English briefing for the principal: what is being debated, "
            "who is pushing what, where the votes stand, and any warning "
            "signs (unanimity streaks, stuck topics, members looping). "
            "Conversational, readable, no jargon, no hashtags, no directives. "
            "≤180 tokens."
        )
        return self._deliberate_local(system_prompt, f"Fact sheet:\n{facts}\nBriefing:")

    def complete(self, system_prompt: str, user_prompt: str,
                 token_callback=None, suggestion_callback=None,
                 timeout: float = None, temperature: float = None,
                 max_tokens: int = None) -> str:
        """The member contract: prompts in, remark out. The backend was bound
        at seating time; callers never branch on who is behind the seat."""
        if self.backend == "cli":
            if self.command == "claude":
                return self._deliberate_claude(system_prompt, user_prompt,
                                               token_callback, suggestion_callback, timeout)
            cli = {"gemini": self._deliberate_gemini, "codex": self._deliberate_codex}
            fn = cli.get(self.command)
            if fn is None:
                raise RuntimeError(f"no CLI adapter for '{self.command}'")
            return fn(system_prompt, user_prompt, token_callback, timeout)
        # local llama.cpp and openai-compat share one transport; only the
        # local path honors the sampling dials (vendors get their defaults).
        return self._deliberate_local(system_prompt, user_prompt, token_callback,
                                      timeout, temperature=temperature,
                                      max_tokens=max_tokens)

    def deliberate(self, topic: str, recent_discussion: List[LedgerEntry],
                   progress_callback=None, token_callback=None, suggestion_callback=None,
                   glyph: str = "", timeout: float = None,
                   members: List[str] = None, summary: str = "",
                   trend: str = "", event: str = "",
                   temperature: float = None, max_tokens: int = None,
                   context_depth: int = 5, kb_note: str = "",
                   blind: bool = False, advocate: bool = False,
                   prior_decisions: str = "") -> str:
        # Sanitize all prompt ingredients before string assembly. None or
        # whitespace-only values become safe sentinels — an empty topic is the
        # root cause of Pi's z-999 loop (nothing to reason about → hallucinate
        # a plan to plan). The glyph and actor_id are internal; only the
        # operator-supplied fields need guarding.
        topic = (topic or "").strip() or "(untitled topic — add a body before ticking)"
        summary = (summary or "").strip()
        kb_note = (kb_note or "").strip()
        trend = (trend or "").strip()
        event = (event or "").strip()

        # blind: the member hasn't voted on this topic yet — strip everyone
        # else's votes from the context so the position comes from the
        # arguments, not the running tally (information-cascade prevention).
        context_str = self._build_context(recent_discussion, depth=context_depth,
                                          blind_for=self.actor_id if blind else None)
        context_str = context_str.strip() or "(feed is empty — you go first)"
        handles = " ".join(f"@{m}" for m in (members or [])) or "@mike @pi @aider @opencode @claude @gemini @codex"
        _hard_cap = max_tokens or 220
        system_prompt = (
            f"You are @{self.actor_id} in the zsynod — a deliberation feed, "
            f"like a public timeline everyone reads and anyone can post to. "
            f"Members: {handles}. "
            f"Read the feed. Reply to what matters. "
            f"Use #HashTag to tie your remark to a thread. "
            f"Start with @handle to direct a reply at that member (DM-style — free, doesn't eat your budget). "
            f"You have {_hard_cap} tokens. Write until you're done or the wall stops you. "
            f"End every post with exactly 3 hashtags. "
            f"A line starting with ⚡ is the loudest signal in the feed — address it first. "
            f"End with exactly one directive line starting with '>': "
            f"'>vote P# aye|nay|abstain <one-line reason>'  '>second P#'  "
            f"'>propose <title>'  '>handoff @member <task>'  "
            f"'>close P# [reason]'  '>body P# <decision text>'  '>pass'. "
            f"Every vote carries its reason — a bare aye is noise. "
            f"Vote when you hold a position; '>pass' only if you truly have nothing. "
            f"Few word do trick."
        )
        if advocate:
            system_prompt += (
                " You hold the devil's advocate seat for this proposal: "
                "state the strongest case AGAINST it before you vote. "
                "You may still vote aye — but the objection posts first."
            )
        trend_line = f"{trend}\n" if trend else ""
        event_line = f"⚡ {event}\n" if event else ""
        pinned = f"[STATE] {summary}\n" if summary else ""
        kb_line = f"[KB] {kb_note}\n" if kb_note else ""
        ratified_line = f"[RATIFIED]\n{prior_decisions}\n" if prior_decisions else ""
        body = f"{trend_line}{event_line}{pinned}{kb_line}{ratified_line}--- feed ---\n{context_str}\n---\n@{self.actor_id}:"
        # The tick glyph BRACKETS the full dispatch — the very first and
        # very last character the member receives. The system prompt is the
        # long static prefix that provider caches ride on, so the glyph must
        # lead IT, not the user message; the user message carries the close.
        # CLI seats join system+user into one prompt, chat seats send them
        # as a messages array — either way the payload opens and closes with
        # the round's glyph.
        if glyph:
            system_prompt = f"{glyph} {system_prompt}"
            user_prompt = f"{glyph} {body}\n{glyph}"
        else:
            user_prompt = body

        labels = {"claude": "Claude CLI", "gemini": "Gemini CLI", "codex": "Codex CLI"}
        if progress_callback:
            progress_callback(f"[dim]Connecting to {labels.get(self.command, self.base_url or self.endpoint)}...[/dim]")

        return self.complete(system_prompt, user_prompt,
                             token_callback=token_callback,
                             suggestion_callback=suggestion_callback,
                             timeout=timeout, temperature=temperature,
                             max_tokens=max_tokens)


class LedgerManager:
    def __init__(self, path: Path):
        self.path = path
        self.entries: List[LedgerEntry] = []
        self.load()

    def load(self):
        """Load the ledger, verifying the hash chain as it is walked — every
        entry's `prev` must equal the previous entry's hash, and every stored
        hash must recompute from its own raw line. Any break raises
        LedgerIntegrityError naming the seq: append-only is a promise the
        pawl checks, not one it assumes."""
        self.entries = []
        if not self.path.exists():
            return
        prev = "GENESIS"
        with open(self.path, "r") as f:
            for lineno, line in enumerate(f, 1):
                if not line.strip():
                    continue
                entry = LedgerEntry.model_validate_json(line)
                if entry.prev != prev:
                    raise LedgerIntegrityError(
                        f"chain broken at seq {entry.seq} (line {lineno}): "
                        f"prev {entry.prev[:12]}… does not match the prior "
                        f"entry's hash {prev[:12]}…")
                if entry.hash != entry.compute_hash(raw_line=line):
                    raise LedgerIntegrityError(
                        f"entry altered at seq {entry.seq} (line {lineno}): "
                        f"stored hash does not recompute from its content")
                prev = entry.hash
                self.entries.append(entry)

    def get_discussion(self, limit: int = 100) -> List[LedgerEntry]:
        return self.entries[-limit:]

    def get_proposals(self) -> List[LedgerEntry]:
        proposals = {e.data["id"]: e for e in self.entries if e.type == "propose"}
        done = {e.data["proposal"] for e in self.entries if e.type in ("commit", "close")}
        return [p for pid, p in proposals.items() if pid not in done]

    def get_proposal_discussion(self, pid: str) -> List[LedgerEntry]:
        return [
            e for e in self.entries
            if (e.type == "propose" and e.data.get("id") == pid)
            or e.data.get("proposal") == pid
        ]

    def get_tally(self, pid: str) -> dict:
        votes: dict[str, str] = {}
        for e in self.entries:
            if e.type == "vote" and e.data.get("proposal") == pid:
                votes[e.actor] = e.data.get("vote", "abstain")
            elif e.type == "second" and e.data.get("proposal") == pid:
                votes[e.actor] = "aye"
        committed = any(e.type == "commit" and e.data.get("proposal") == pid for e in self.entries)
        closed = any(e.type == "close" and e.data.get("proposal") == pid for e in self.entries)
        return {
            "aye": sum(1 for v in votes.values() if v == "aye"),
            "nay": sum(1 for v in votes.values() if v == "nay"),
            "abstain": sum(1 for v in votes.values() if v == "abstain"),
            "state": "committed" if committed else ("closed" if closed else "open"),
            "votes": votes,
        }

    def get_lifecycle_state(self, pid: str, quorum: int) -> str:
        """Derived lifecycle state — never stored, always recomputed from the chain.

        RATIFIED  commit entry exists (quorum or principal)
        CLOSED    close entry exists (principal or sweep) — out of rotation
        PASSING   one aye short of quorum or better — needs a decisive vote
        NEW       fewer than 2 discussion entries in the thread
        STUCK     no vote/second movement in the last STALE_AFTER ledger entries
        ACTIVE    everything else
        """
        tally = self.get_tally(pid)
        if tally["state"] == "committed":
            return "RATIFIED"
        if tally["state"] == "closed":
            return "CLOSED"
        if tally["aye"] >= max(quorum - 1, 1):
            return "PASSING"
        thread = self.get_proposal_discussion(pid)
        if sum(1 for e in thread if e.type in ("speak", "discuss")) < 2:
            return "NEW"
        moves = [e.seq for e in self.entries
                 if e.type in ("vote", "second") and e.data.get("proposal") == pid]
        if not moves:
            moves = [e.seq for e in self.entries
                     if e.type == "propose" and e.data.get("id") == pid]
        if self.entries and self.entries[-1].seq - max(moves, default=0) > STALE_AFTER:
            return "STUCK"
        return "ACTIVE"

    def pending_second_reading(self, pid: str) -> bool:
        """A second_reading entry exists and the proposal is still open —
        the forum owes it one adversarial re-read before commit."""
        return any(e.type == "second_reading" and e.data.get("proposal") == pid
                   for e in self.entries)

    def commit_on_quorum(self, quorum: int,
                         unanimity_action: int = 0) -> tuple[List[str], List[str]]:
        """Recognize quorum for every open proposal. Returns (committed, held).

        unanimity_action 2 is the Sanhedrin rule: a proposal that reaches
        quorum with ZERO nays is held one round — a second_reading entry is
        appended instead of the commit, the schedulers surface an adversarial
        re-read event, and only on the next recognition pass does it commit
        (whatever the re-read did to the tally, quorum permitting)."""
        newly, held = [], []
        for p in self.get_proposals():
            pid = p.data["id"]
            t = self.get_tally(pid)
            if t["aye"] < quorum:
                continue
            if (unanimity_action >= 2 and t["nay"] == 0
                    and not self.pending_second_reading(pid)):
                self.append("synod", "second_reading", {
                    "proposal": pid,
                    "note": f"unanimous at quorum (aye={t['aye']}) — held for "
                            f"second reading before commit",
                })
                held.append(pid)
                continue
            self.append("synod", "commit", {
                "proposal": pid, "by": "quorum",
                "note": f"aye={t['aye']} >= quorum={quorum}",
            })
            newly.append(pid)
        return newly, held

    def get_title(self, pid: str) -> str:
        for e in self.entries:
            if e.type == "propose" and e.data.get("id") == pid:
                return e.data.get("title", pid)
        return pid

    def get_decision_record(self, pid: str) -> dict:
        """ADR material for the scribe, derived from the chain: the question
        the proposal answered, who asked it, and who dissented with what
        stated reason. A decision recorded without these is just a 42."""
        title, body, proposer = pid, "", "?"
        for e in self.entries:
            if e.type == "propose" and e.data.get("id") == pid:
                title = e.data.get("title", pid)
                body = e.data.get("body", "")
                proposer = e.actor
                break
        tally = self.get_tally(pid)
        thread = self.get_proposal_discussion(pid)
        # The question: the explicit body if one was given, else the
        # proposer's first remark in the thread — the closest thing the
        # chain holds to a why.
        question = body
        if not question:
            for e in thread:
                if e.actor == proposer and e.data.get("remark"):
                    question = e.data["remark"]
                    break
        # Dissent: every non-aye voter, their vote note, and their last
        # remark in the thread — the reasons, not just the count.
        # Assent: aye voters with whatever reason they gave; a bare aye is
        # recorded as bare — the cost of a free aye is being seen giving one.
        dissent, assent = [], []
        for actor, vote in sorted(tally["votes"].items()):
            note = next((e.data.get("note", "") for e in reversed(self.entries)
                         if e.type == "vote" and e.actor == actor
                         and e.data.get("proposal") == pid), "")
            if vote == "aye":
                assent.append({"actor": actor, "note": note})
                continue
            remark = next((e.data["remark"] for e in reversed(thread)
                           if e.actor == actor and e.data.get("remark")), "")
            dissent.append({"actor": actor, "vote": vote,
                            "note": note, "remark": remark})
        return {"pid": pid, "title": title, "proposer": proposer,
                "question": question, "tally": tally, "dissent": dissent,
                "assent": assent,
                "second_reading": self.pending_second_reading(pid)}

    def get_subscriptions(self, member: str) -> set:
        """Topics a member is invested in: proposed, voted, seconded, or spoke
        in (when the speak entry carries a proposal ref). Derived, never stored."""
        subs = set()
        for e in self.entries:
            if e.actor != member:
                continue
            if e.type == "propose":
                subs.add(e.data.get("id"))
            elif e.data.get("proposal"):
                subs.add(e.data["proposal"])
        subs.discard(None)
        return subs

    def get_repetition(self, member: str, window: int = 3) -> float:
        """Max pairwise Jaccard similarity over the member's last `window`
        remarks (hashtags/@handles excluded). 1.0 = saying the same thing
        verbatim; 0.0 = fresh every time or not enough history to judge."""
        remarks = [e.data.get("remark", "") for e in self.entries
                   if e.actor == member and e.type in ("speak", "discuss")][-window:]
        sets = [s for s in (_remark_tokens(r) for r in remarks) if s]
        if len(sets) < 2:
            return 0.0
        best = 0.0
        for i in range(len(sets)):
            for j in range(i + 1, len(sets)):
                union = len(sets[i] | sets[j])
                if union:
                    best = max(best, len(sets[i] & sets[j]) / union)
        return best

    def get_member_stats(self, loop_window: int = 3) -> dict:
        """Per-member activity profile derived from the chain — speaks, vote
        split, proposals and their ratification count, passes, mention graph
        (out/in), handoffs, last activity, repetition score."""
        stats: dict[str, dict] = {}

        def s(m: str) -> dict:
            return stats.setdefault(m, {
                "speaks": 0, "aye": 0, "nay": 0, "abstain": 0, "seconds": 0,
                "proposed": 0, "ratified": 0, "closed": 0, "passes": 0,
                "mentions_out": 0, "mentions_in": 0,
                "handoffs_out": 0, "handoffs_in": 0, "last_seq": -1,
            })

        proposer: dict[str, str] = {}
        for e in self.entries:
            m = s(e.actor)
            m["last_seq"] = e.seq
            if e.type in ("speak", "discuss"):
                m["speaks"] += 1
                for h in re.findall(r"@(\w[\w-]*)", e.data.get("remark", "")):
                    if h != e.actor:
                        m["mentions_out"] += 1
                        s(h)["mentions_in"] += 1
            elif e.type == "vote":
                v = e.data.get("vote", "abstain")
                m[v if v in ("aye", "nay", "abstain") else "abstain"] += 1
            elif e.type == "second":
                m["seconds"] += 1
            elif e.type == "propose":
                m["proposed"] += 1
                proposer[e.data.get("id")] = e.actor
            elif e.type == "commit":
                author = proposer.get(e.data.get("proposal"))
                if author:
                    s(author)["ratified"] += 1
            elif e.type == "close":
                author = proposer.get(e.data.get("proposal"))
                if author:
                    s(author)["closed"] += 1
            elif e.type == "pass":
                m["passes"] += 1
            elif e.type == "handoff":
                m["handoffs_out"] += 1
                s(e.data.get("to", "?"))["handoffs_in"] += 1

        for name, m in stats.items():
            m["repetition"] = self.get_repetition(name, loop_window)
        return stats

    def topic_event(self, member: str, pid: str, quorum: int) -> str:
        """Event line for a member on a FIXED topic (operator-focused tick)."""
        t = self.get_tally(pid)
        if t["state"] == "open" and self.pending_second_reading(pid):
            return (f"⚖ second reading: {pid} passed without a single nay — "
                    f"find what everyone missed, or confirm your vote with a reason")
        if t["state"] == "open" and t["aye"] == quorum - 1 and member not in t["votes"]:
            return f"🗳 {pid} is one aye from quorum ({t['aye']}/{quorum}) — your vote decides"
        if self.get_lifecycle_state(pid, quorum) == "STUCK":
            return f"🧊 {pid} is stuck — move it forward or vote it down"
        return ""

    def next_event(self, member: str, quorum: int,
                   spontaneity: float = 0.0,
                   loop_threshold: float = 2.0,
                   loop_window: int = 3,
                   rng=random) -> tuple[str, Optional[str]]:
        """Highest-priority event for a member's turn: (event_line, pid).

        Priority: 💭 loop-breaker (forced when the member's recent remarks
        overlap past loop_threshold — health intervention, beats everything)
        → 💭 spontaneous free thought (probability = spontaneity dial)
        → 📥 mention since the member's last entry (oldest first — patience)
        → 🗳 decisive vote (subscribed topics first) → 🆕 newest untouched
        proposal → 🧊 least-recently-touched stuck topic → 🎲 random open
        floor. The member's own ledger activity is the cursor; acting (even
        '>pass') acknowledges everything before it. Defaults (loop_threshold
        2.0, spontaneity 0.0) disable both 💭 paths — callers opt in via dials.
        """
        rep = self.get_repetition(member, loop_window)
        if rep >= loop_threshold:
            return (f"💭 loop detected — your last {loop_window} remarks are "
                    f"{int(rep * 100)}% the same. Drop the script: one NEW "
                    f"observation, question, or proposal", None)

        if spontaneity > 0 and rng.random() < spontaneity:
            return ("💭 free thought — surface one fresh observation, question, "
                    "or proposal; no obligation to any open topic", None)

        open_pids = [p.data["id"] for p in self.get_proposals()]

        last_seq = max((e.seq for e in self.entries if e.actor == member), default=-1)
        pat = re.compile(rf"@{re.escape(member)}\b")
        for e in self.entries:
            if e.seq <= last_seq or e.actor == member:
                continue
            if e.type in ("speak", "discuss") and pat.search(e.data.get("remark", "")):
                pid = e.data.get("proposal")
                if pid is None or pid in open_pids:
                    quote = e.data["remark"][:80]
                    return (f'📥 @{e.actor} mentioned you: "{quote}"', pid)

        # ⚖ second reading outranks everything topic-driven: the forum owes
        # an adversarial re-read before an unanimous proposal may commit.
        for pid in open_pids:
            if self.pending_second_reading(pid):
                return (f"⚖ second reading: {pid} passed without a single nay "
                        f"— find what everyone missed, or confirm your vote "
                        f"with a reason", pid)

        subs = self.get_subscriptions(member)
        decisive = []
        for pid in open_pids:
            t = self.get_tally(pid)
            if t["aye"] == quorum - 1 and member not in t["votes"]:
                decisive.append((pid not in subs, pid))
        if decisive:
            pid = min(decisive)[1]
            return (f"🗳 {pid} is one aye from quorum ({quorum-1}/{quorum}) — your vote decides", pid)

        fresh = []
        for pid in open_pids:
            thread = self.get_proposal_discussion(pid)
            if not any(e.actor == member for e in thread):
                first = next(e for e in self.entries
                             if e.type == "propose" and e.data.get("id") == pid)
                fresh.append((first.seq, pid, first.actor))
        if fresh:
            _, pid, author = max(fresh)
            return (f'🆕 {pid} "{self.get_title(pid)[:40]}" by @{author} — take a position', pid)

        stuck = []
        for pid in open_pids:
            if self.get_lifecycle_state(pid, quorum) == "STUCK":
                last = max((e.seq for e in self.get_proposal_discussion(pid)), default=0)
                stuck.append((last, pid))
        if stuck:
            last, pid = min(stuck)
            idle = (self.entries[-1].seq - last) if self.entries else 0
            return (f"🧊 {pid} idle for {idle} entries — revive it or vote it down", pid)

        if open_pids:
            pid = random.choice(open_pids)
            return (f'🎲 open floor: {pid} "{self.get_title(pid)[:40]}"', pid)
        return ("", None)

    def get_hashtag_analytics(self) -> dict:
        """Bi-directional hashtag index.

        Returns:
            tags:   {tag_lower: {tag, first_actor, first_ts, first_seq,
                                  actor_order, topics, total_uses, lifespan}}
            topic_tags: {pid: [{tag, first_actor, first_ts, seq}...]}  intro order
            titles: {pid: title}
        """
        # Build pid->title and a seq->pid map using last-propose-wins heuristic
        titles: dict[str, str] = {}
        seq_to_pid: dict[int, str] = {}
        current_pid = None
        for e in self.entries:
            if e.type == "propose":
                current_pid = e.data.get("id")
                titles[current_pid] = e.data.get("title", current_pid)
            if current_pid:
                seq_to_pid[e.seq] = current_pid

        tags: dict[str, dict] = {}
        topic_tags: dict[str, list] = {}

        for e in self.entries:
            if e.type not in ("speak", "discuss"):
                continue
            remark = e.data.get("remark", "")
            # Explicit topic ref (written by the tick loop) beats the
            # last-propose-wins heuristic kept for pre-scheduler entries.
            pid = e.data.get("proposal") or seq_to_pid.get(e.seq)
            for raw in re.findall(r"#\w+", remark):
                key = raw.lower()
                if key not in tags:
                    tags[key] = {
                        "tag": raw,
                        "first_seq": e.seq,
                        "first_actor": e.actor,
                        "first_ts": e.ts,
                        "actor_order": [],
                        "topics": [],
                        "uses": [],
                    }
                t = tags[key]
                t["uses"].append({"actor": e.actor, "ts": e.ts, "seq": e.seq, "pid": pid})
                if e.actor not in t["actor_order"]:
                    t["actor_order"].append(e.actor)
                if pid and pid not in t["topics"]:
                    t["topics"].append(pid)
                if pid:
                    if pid not in topic_tags:
                        topic_tags[pid] = []
                    if key not in {x["key"] for x in topic_tags[pid]}:
                        topic_tags[pid].append({
                            "tag": raw,
                            "key": key,
                            "first_actor": e.actor,
                            "first_ts": e.ts,
                            "seq": e.seq,
                        })

        for t in tags.values():
            seqs = [u["seq"] for u in t["uses"]]
            t["lifespan"] = max(seqs) - min(seqs) if len(seqs) > 1 else 0
            t["total_uses"] = len(t["uses"])

        return {
            "tags": dict(sorted(tags.items(), key=lambda x: x[1]["first_seq"])),
            "topic_tags": topic_tags,
            "titles": titles,
        }

    def get_trend_preamble(self) -> str:
        """Build a trend-temperature line for the tick preamble.

        Scores each hashtag by recency-weighted use count:
            score = Σ (seq_i / max_seq)  for each use i
        Then selects percentile representatives at p97, p50, p05 from the
        score distribution and formats them as a single prompt line:
            Trend: 🔥#hot(9.4) — #mid(3.1) — ❄#cold(0.2)
        """
        import math

        speak_entries = [e for e in self.entries if e.type in ("speak", "discuss")]
        if not speak_entries:
            return ""

        max_seq = max(e.seq for e in self.entries) or 1
        scores: dict[str, float] = {}

        for e in speak_entries:
            weight = e.seq / max_seq
            for raw in re.findall(r"#\w+", e.data.get("remark", "")):
                key = raw.lower()
                scores[key] = scores.get(key, 0.0) + weight

        if not scores:
            return ""

        # Build (tag_str, score) sorted ascending by score
        ranked = sorted(scores.items(), key=lambda x: x[1])
        n = len(ranked)

        def pick(pct: float) -> tuple[str, float]:
            idx = max(0, min(int(pct * n), n - 1))
            return ranked[idx]

        hot_key, hot_s  = pick(0.97)
        mid_key, mid_s  = pick(0.50)
        cold_key, cold_s = pick(0.05)

        # Compute mean and stddev for display
        vals = [s for _, s in ranked]
        mean = sum(vals) / n
        stddev = math.sqrt(sum((v - mean) ** 2 for v in vals) / n)

        def fmt_tag(key: str, score: float) -> str:
            # Recover original capitalisation from entries
            for e in reversed(speak_entries):
                for raw in re.findall(r"#\w+", e.data.get("remark", "")):
                    if raw.lower() == key:
                        return f"{raw}({score:.1f})"
            return f"{key}({score:.1f})"

        return (
            f"Trend [σ={stddev:.1f} μ={mean:.1f}]: "
            f"🔥{fmt_tag(hot_key, hot_s)} "
            f"— {fmt_tag(mid_key, mid_s)} "
            f"— ❄{fmt_tag(cold_key, cold_s)}"
        )

    def get_latest_summary(self, pid: str) -> str:
        """Return the text of the most recent summary entry for a proposal, or ''."""
        for e in reversed(self.entries):
            if e.type == "summary" and e.data.get("proposal") == pid:
                return e.data.get("text", "")
        return ""

    def get_ratified_decisions(self, limit: int = 6) -> list[tuple[str, str, str]]:
        """Return (pid, title, body) for the most recently ratified proposals,
        newest first. Used to pin settled decisions into the deliberation prompt
        so members argue forward, not in circles."""
        committed_pids = [
            e.data["proposal"] for e in self.entries
            if e.type == "commit"
        ]
        seen: set[str] = set()
        results = []
        for pid in reversed(committed_pids):
            if pid in seen:
                continue
            seen.add(pid)
            title = self.get_title(pid)
            body = self.get_proposal_body(pid)
            results.append((pid, title, body))
            if len(results) >= limit:
                break
        return results

    def get_proposal_body(self, pid: str) -> str:
        """Return the most recent body for a proposal — either from the propose
        entry or from a subsequent `body` entry (cockpit `body P# <text>`)."""
        body = ""
        for e in self.entries:
            if e.type == "propose" and e.data.get("id") == pid:
                body = e.data.get("body", "")
            elif e.type == "body" and e.data.get("proposal") == pid:
                body = e.data.get("body", body)
        return body

    # ── quality analytics ─────────────────────────────────────────────────────

    def get_engagement_signal(self, actor: str, seq: int, window: int = 10) -> bool:
        """True if any entry within `window` positions after `seq` @mentions
        `actor`. This is the proxy for "another member found this remark worth
        responding to" — the lightest possible quality signal from the chain,
        requiring no new voting mechanism."""
        pat = re.compile(rf"@{re.escape(actor)}\b")
        count = 0
        for e in self.entries:
            if e.seq <= seq:
                continue
            count += 1
            if count > window:
                break
            if e.type in ("speak", "discuss") and pat.search(e.data.get("remark", "")):
                return True
        return False

    def get_quality_records(self, member: str, n: int = 60,
                            engagement_window: int = 10) -> list:
        """For each of `member`'s last `n` speak/discuss entries, return a
        quality record: engagement signal, loop state, token estimate, and the
        operating conditions snapshot (_c) if the tick recorded one.

        This is the raw material for the graph and the condition delta. Records
        for ticks within the last `engagement_window` entries are marked
        pending — the window hasn't closed yet, so engaged=None."""
        speaks = [
            e for e in self.entries
            if e.actor == member and e.type in ("speak", "discuss")
        ][-n:]
        last_seq = self.entries[-1].seq if self.entries else 0
        records = []
        for e in speaks:
            words = e.data.get("remark", "").split()
            cond = e.data.get("_c", {})
            looped = (cond.get("rep", 0) >= cond.get("loop_threshold",
                      cond.get("rep", 0) + 1)) if cond else False
            pending = (last_seq - e.seq) < engagement_window
            records.append({
                "seq": e.seq,
                "ts": e.ts,
                "topic": e.data.get("proposal") or e.data.get("topic", ""),
                "tokens": max(1, int(len(words) / 1.3)),
                "engaged": None if pending else self.get_engagement_signal(
                    member, e.seq, engagement_window),
                "looped": looped,
                "conditions": cond,
            })
        return records

    def get_condition_delta(self, member: str, n: int = 60,
                            engagement_window: int = 10) -> list:
        """Compare operating conditions between engaged and non-engaged ticks
        for `member`. Returns a list of (label, good_mean, bad_mean, delta)
        sorted by absolute delta descending — the conditions that differ most
        between high and low quality turns.

        Only ticks with a `_c` conditions snapshot are included. Ticks where
        engaged=None (window not closed) are excluded."""
        records = [
            r for r in self.get_quality_records(member, n, engagement_window)
            if r["conditions"] and r["engaged"] is not None
        ]
        if len(records) < 4:
            return []

        good = [r["conditions"] for r in records if r["engaged"]]
        bad  = [r["conditions"] for r in records if not r["engaged"]]
        if not good or not bad:
            return []

        keys = {
            "t":   "temperature",
            "mt":  "max_tokens",
            "cd":  "context_depth",
            "tbl": "topic_body_len",
            "kb":  "kb_grounded",
            "rep": "rep_at_entry",
        }
        results = []
        for k, label in keys.items():
            gv = [c.get(k, 0) for c in good]
            bv = [c.get(k, 0) for c in bad]
            g_mean = sum(gv) / len(gv)
            b_mean = sum(bv) / len(bv)
            delta = abs(g_mean - b_mean)
            if delta > 0.01:
                results.append((label, g_mean, b_mean, delta))
        return sorted(results, key=lambda x: -x[3])

    def get_brief(self, quorum: int) -> dict:
        """Generate the prescriptive operator brief: what needs human action,
        what is agent-ready, and what the session's quality data reveals as
        coaching for the human. The brief is the surface where forum signal
        becomes actionable intelligence."""
        attention, agent_ready, coaching = [], [], []

        for p in self.get_proposals():
            pid = p.data["id"]
            state = self.get_lifecycle_state(pid, quorum)
            t = self.get_tally(pid)
            if t["aye"] >= quorum:
                attention.append({
                    "type": "ratify",
                    "pid": pid,
                    "detail": f"aye={t['aye']}/{quorum} — quorum reached, awaiting ratification",
                })
            elif state == "STUCK":
                last_move = max(
                    (e.seq for e in self.entries
                     if e.type in ("vote", "second")
                     and e.data.get("proposal") == pid),
                    default=0,
                )
                staleness = (self.entries[-1].seq - last_move) if self.entries else 0
                last_actor = next(
                    (e.actor for e in reversed(self.entries)
                     if e.type in ("vote", "second")
                     and e.data.get("proposal") == pid),
                    "nobody",
                )
                attention.append({
                    "type": "stuck",
                    "pid": pid,
                    "detail": f"STUCK {staleness} entries — last move by @{last_actor}",
                })

        # Ratified proposals without a subsequent handoff entry
        ratified_pids = {
            e.data["proposal"] for e in self.entries if e.type == "commit"
        }
        handed_pids = {
            e.data.get("ref") or e.data.get("proposal", "")
            for e in self.entries if e.type == "handoff"
        }
        for pid in ratified_pids - handed_pids:
            title = self.get_title(pid)
            agent_ready.append({
                "type": "handoff_needed",
                "pid": pid,
                "detail": f"ratified, no executor assigned — handoff to aider or claude-code",
                "title": title,
            })

        # Pending handoffs with no exec entry
        for e in self.entries:
            if e.type == "handoff":
                task_ref = e.data.get("ref") or e.data.get("proposal", e.seq)
                executed = any(
                    x.type == "exec" and x.data.get("handoff") == e.seq
                    for x in self.entries
                )
                if not executed:
                    agent_ready.append({
                        "type": "pending_handoff",
                        "pid": str(task_ref),
                        "detail": (f"→ @{e.data.get('to','?')}: "
                                   f"{e.data.get('task','')[:60]}"),
                    })

        # Coaching: per-member quality insights
        all_actors = list({
            e.actor for e in self.entries
            if e.type in ("speak", "discuss") and e.actor != "system"
        })
        for actor in sorted(all_actors):
            records = self.get_quality_records(actor, n=60)
            closed_records = [r for r in records if r["engaged"] is not None]
            if len(closed_records) < 3:
                continue

            engaged_n = sum(1 for r in closed_records if r["engaged"])
            loop_n    = sum(1 for r in closed_records if r["looped"])
            total = len(closed_records)
            pct = int(100 * engaged_n / total) if total else 0

            lines = []
            if loop_n > 0:
                empty_loops = sum(
                    1 for r in closed_records
                    if r["looped"] and r["conditions"].get("tbl", 1) == 0
                )
                if empty_loops:
                    lines.append(
                        f"{loop_n} loop(s) — {empty_loops} on empty topics "
                        f"(add proposal body before ticking)"
                    )
                else:
                    lines.append(f"{loop_n} loop(s) detected")

            delta = self.get_condition_delta(actor)
            if delta:
                label, g_mean, b_mean, _ = delta[0]
                if label == "topic_body_len":
                    lines.append(
                        f"engaged ticks had avg body {g_mean:.0f} chars, "
                        f"low-quality had {b_mean:.0f} — write the proposal body"
                    )
                elif label == "kb_grounded":
                    lines.append(
                        f"KB grounding present in {g_mean:.0%} of engaged ticks "
                        f"vs {b_mean:.0%} of others"
                    )
                elif label == "context_depth":
                    lines.append(
                        f"best context_depth for {actor}: ~{g_mean:.0f} "
                        f"(engaged avg) vs {b_mean:.0f} (others)"
                    )
                elif label == "rep_at_entry":
                    lines.append(
                        f"repetition score was {b_mean:.2f} before bad ticks "
                        f"vs {g_mean:.2f} before good — loop was building"
                    )

            if lines or pct < 30:
                coaching.append({
                    "member": actor,
                    "engaged_pct": pct,
                    "engaged_n": engaged_n,
                    "total": total,
                    "insights": lines or [f"engagement at {pct}% — insufficient condition data yet"],
                    "delta": delta[:3],
                })

        return {
            "attention": attention,
            "agent_ready": agent_ready,
            "coaching": coaching,
        }

    # ── the door: outside voices speak to the forum ──────────────────────────

    def petition(self, actor: str, text: str, kind: str = "inform",
                 to: Optional[List[str]] = None) -> LedgerEntry:
        """An outside voice — agent, cron job, any zdots dependency — speaks
        to the forum. Appended as a `speak` entry so the mention scheduler
        dispatches it like any member remark (📥, oldest first); petitioner
        metadata rides the data. The actor holds no seat: petitions carry no
        vote weight and never touch quorum. `to` handles are prepended to the
        remark when absent so the scheduler has mentions to dispatch. The
        entry's seq is the receipt for petition_status()."""
        handles = [h if h.startswith("@") else f"@{h}" for h in (to or [])]
        missing = [h for h in handles if not re.search(rf"{re.escape(h)}\b", text)]
        remark = f"{' '.join(missing)}: {text}" if missing else text
        return self.append(actor, "speak", {
            "remark": remark,
            "petition": {"kind": kind, "role": "petitioner"},
        })

    def petition_status(self, seq: int) -> dict:
        """Response or honest non-response for a petition receipt. States:
        `unheard` — nothing appended since (no session convened);
        `heard` — the forum has convened but no one has addressed the
        petitioner; `addressed` — entries since the receipt @mention the
        petitioner, listed. Silence is data the chain already holds."""
        entry = next((e for e in self.entries if e.seq == seq), None)
        if entry is None:
            return {"found": False, "receipt": seq}
        pat = re.compile(rf"@{re.escape(entry.actor)}\b")
        since = [e for e in self.entries if e.seq > seq]
        addressed = [
            {"seq": e.seq, "ts": e.ts, "actor": e.actor, "type": e.type,
             "remark": e.data.get("remark", "")}
            for e in since
            if e.actor != entry.actor and pat.search(str(e.data.get("remark", "")))
        ]
        state = "addressed" if addressed else ("heard" if since else "unheard")
        return {
            "found": True, "receipt": seq, "petitioner": entry.actor,
            "ts": entry.ts, "remark": entry.data.get("remark", ""),
            "state": state, "entries_since": len(since),
            "last_activity": since[-1].ts if since else entry.ts,
            "addressed": addressed,
        }

    def get_herald_facts(self, quorum: int, recent: int = 6) -> str:
        """Deterministic fact sheet the herald narrates from. Plain text —
        everything derived from the chain, nothing the model must invent."""
        lines: list[str] = []
        for p in self.get_proposals():
            pid = p.data["id"]
            t = self.get_tally(pid)
            votes = " ".join(f"@{a}:{v}" for a, v in sorted(t["votes"].items()))
            lines.append(
                f"{pid} \"{self.get_title(pid)[:60]}\" by @{p.actor} — "
                f"{self.get_lifecycle_state(pid, quorum)}, "
                f"aye={t['aye']} nay={t['nay']} abs={t['abstain']} "
                f"(quorum {quorum}){' — ' + votes if votes else ''}"
            )
        ratified = [e for e in self.entries if e.type == "commit"][-3:]
        for e in ratified:
            rp = e.data.get("proposal", "?")
            lines.append(f"RATIFIED {rp} \"{self.get_title(rp)[:60]}\" by {e.data.get('by', '?')}")
        stats = self.get_member_stats()
        for name, m in sorted(stats.items(), key=lambda kv: -kv[1]["speaks"]):
            if name in ("synod", "summarizer", "recorder", "herald"):
                continue
            cast = m["aye"] + m["nay"] + m["abstain"]
            rate = f"{m['aye'] / cast:.0%} aye" if cast else "no votes"
            lines.append(
                f"@{name}: {m['speaks']} remarks, {cast} votes ({rate}), "
                f"{m['proposed']} proposed, {m['passes']} passes"
            )
        remarks = [e for e in self.entries
                   if e.type in ("speak", "discuss") and e.data.get("remark")][-recent:]
        for e in remarks:
            lines.append(f"latest @{e.actor}: {e.data['remark'][:100]}")
        return "\n".join(lines)

    def next_proposal_id(self) -> str:
        n = sum(1 for e in self.entries if e.type == "propose")
        return f"P{n + 1}"

    @staticmethod
    def normalize_title(title: str) -> str:
        """Canonical form for dedup comparison: lowercase, strip punctuation,
        collapse whitespace. 'Seat the Librarian!' == 'seat the librarian'."""
        return re.sub(r"\s+", " ", re.sub(r"[^\w\s]", "", title.lower())).strip()

    def find_duplicate_title(self, title: str) -> Optional[str]:
        """Return the ID of a prior proposal with the same normalized title,
        or None if no duplicate exists. Checks open AND closed proposals."""
        norm = self.normalize_title(title)
        for e in self.entries:
            if e.type == "propose":
                if self.normalize_title(e.data.get("title", "")) == norm:
                    return e.data.get("id")
        return None

    def get_blocking_items(self) -> List[dict]:
        items = []
        for p in self.get_proposals():
            items.append({"id": p.data["id"], "type": "proposal", "label": p.data["title"]})
        return items

    def append(self, actor: str, entry_type: str, data: dict, round_num: Optional[int] = None) -> LedgerEntry:
        lock_path = self.path.parent / ".lock"

        import time
        retries = 0
        while True:
            try:
                lock_path.mkdir()
                break
            except FileExistsError:
                time.sleep(0.1)
                retries += 1
                if retries > 50:
                    raise TimeoutError("Ledger is locked by another process.")

        try:
            self.load()
            prev_hash = self.entries[-1].hash if self.entries else "GENESIS"
            seq = len(self.entries)

            if round_num is None:
                round_num = self.entries[-1].round if self.entries else 0

            entry = LedgerEntry(
                seq=seq,
                round=round_num,
                actor=actor,
                type=entry_type,
                data=data,
                prev=prev_hash
            )
            entry.hash = entry.compute_hash()

            with open(self.path, "a") as f:
                f.write(entry.model_dump_json() + "\n")

            self.entries.append(entry)
            return entry

        finally:
            try:
                lock_path.rmdir()
            except FileNotFoundError:
                pass

    def reset(self) -> Path:
        """Archive the current ledger and start a fresh chain.

        Copies the live file to a timestamped .dump-* sibling, truncates,
        and writes a single genesis reset entry so the new chain is auditable.
        Returns the archive path. Safe to call while the TUI is running —
        the ledger lock protects the append."""
        import shutil as _shutil
        ts = datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        arc = self.path.with_name(f"{self.path.name}.dump-{ts}")
        prior_count = len(self.entries)
        _shutil.copy2(self.path, arc)
        self.entries = []
        self.path.write_text("")
        self.append("system", "reset", {
            "reason": "operator core dump",
            "archive": str(arc),
            "prior_entries": prior_count,
        })
        return arc
