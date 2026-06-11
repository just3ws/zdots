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

_DIRECTIVE_RE = re.compile(r"^\s*>\s*(vote|second|propose|handoff|pass)\b\s*(.*)$",
                           re.IGNORECASE)


def _parse_one_directive(verb: str, rest: str) -> Optional[tuple]:
    if verb == "vote":
        m = re.match(r"(?i)^(p\d+)\s+(aye|nay|abstain)\b", rest)
        if m:
            return ("vote", {"proposal": m.group(1).upper(), "vote": m.group(2).lower()})
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
    return None


def parse_directives(remark: str) -> tuple[str, list[tuple[str, dict]]]:
    """Split agent output into clean speech and structured ledger intents.

    Grammar — one directive per line, line must start with '>':
        >vote P# aye|nay|abstain
        >second P#
        >propose <title>
        >handoff @member <task>
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
# One glyph is rolled per tick and prepended to every agent's prompt —
# same symbol across all voices, nudging probability without coordination.
TAOIST_GLYPHS: list[str] = (
    ["☯", "☰", "☱", "☲", "☳", "☴", "☵", "☶", "☷"]
    + [chr(0x4DC0 + i) for i in range(64)]
)


def tick_seed() -> str:
    """Return a random Taoist glyph to seed a tick round."""
    return random.choice(TAOIST_GLYPHS)

# Stable session identity for Gemini — UUID5 derived from name, same value every tick.
_GEMINI_SESSION_ID = str(uuid.uuid5(uuid.NAMESPACE_DNS, "zsynod-gemini"))


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


class ZsynodAgent:
    def __init__(self, actor_id: str, endpoint: str = None, model: str = None):
        self.actor_id = actor_id
        self.endpoint = (endpoint or os.environ.get("ZDOTS_AI_ENDPOINT", "http://127.0.0.1:11500")).rstrip("/")
        self.model = model  # None = per-actor default; override to force a specific model

    def _build_context(self, recent_discussion: List[LedgerEntry], depth: int = 5) -> str:
        # Last few entries only — forces compression, keeps the prompt tight.
        lines = []
        for e in recent_discussion[-depth:]:
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
        t = timeout or LOCAL_TICK_TIMEOUT
        payload = json.dumps({
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "stream": token_callback is not None,
            "max_tokens": int(max_tokens or 220),
            "temperature": temperature if temperature is not None else 0.7,
        }).encode()

        req = urllib.request.Request(
            f"{self.endpoint}/v1/chat/completions",
            data=payload,
            headers={"Content-Type": "application/json"},
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

    def deliberate(self, topic: str, recent_discussion: List[LedgerEntry],
                   progress_callback=None, token_callback=None, suggestion_callback=None,
                   glyph: str = "", timeout: float = None,
                   members: List[str] = None, summary: str = "",
                   trend: str = "", event: str = "",
                   temperature: float = None, max_tokens: int = None,
                   context_depth: int = 5, kb_note: str = "") -> str:
        context_str = self._build_context(recent_discussion, depth=context_depth)
        handles = " ".join(f"@{m}" for m in (members or [])) or "@mike @pi @aider @opencode @claude @gemini @codex"
        system_prompt = (
            f"You are @{self.actor_id} in the zsynod deliberation forum. "
            f"Members: {handles}. "
            f"Reply in ≤160 tokens. End every response with exactly 3 hashtags. "
            f"You may @mention members by handle. "
            f"A line starting with ⚡ is the event you are responding to — address it first. "
            f"End with exactly one directive line starting with '>': "
            f"'>vote P# aye|nay|abstain'  '>second P#'  '>propose <title>'  "
            f"'>handoff @member <task>'  '>pass'. "
            f"Vote when you hold a position — speech alone moves no tally; "
            f"'>pass' only if you truly have nothing. Few word do trick."
        )
        seed = f"{glyph} " if glyph else ""
        trend_line = f"{trend}\n" if trend else ""
        event_line = f"⚡ {event}\n" if event else ""
        pinned = f"[STATE] {summary}\n" if summary else ""
        kb_line = f"[KB] {kb_note}\n" if kb_note else ""
        user_prompt = f"{seed}{trend_line}{event_line}Topic: {topic}\n{pinned}{kb_line}{context_str}\n@{self.actor_id}:"

        labels = {"claude": "Claude CLI", "gemini": "Gemini CLI", "codex": "Codex CLI"}
        if progress_callback:
            progress_callback(f"[dim]Connecting to {labels.get(self.actor_id, self.endpoint)}...[/dim]")

        if self.actor_id == "claude":
            return self._deliberate_claude(system_prompt, user_prompt, token_callback, suggestion_callback, timeout)

        dispatch = {
            "gemini": self._deliberate_gemini,
            "codex":  self._deliberate_codex,
        }
        fn = dispatch.get(self.actor_id)
        if fn:
            return fn(system_prompt, user_prompt, token_callback, timeout)
        # Local llama.cpp path is the only backend with sampling dials.
        return self._deliberate_local(system_prompt, user_prompt, token_callback,
                                      timeout, temperature=temperature,
                                      max_tokens=max_tokens)


class LedgerManager:
    def __init__(self, path: Path):
        self.path = path
        self.entries: List[LedgerEntry] = []
        self.load()

    def load(self):
        self.entries = []
        if self.path.exists():
            with open(self.path, "r") as f:
                for line in f:
                    if line.strip():
                        self.entries.append(LedgerEntry.model_validate_json(line))

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

    def commit_on_quorum(self, quorum: int) -> List[str]:
        """Append a commit (by: quorum, actor: synod) for every open proposal
        at or over quorum. Idempotent — committed proposals leave get_proposals().
        Returns the newly committed proposal IDs."""
        newly = []
        for p in self.get_proposals():
            pid = p.data["id"]
            t = self.get_tally(pid)
            if t["aye"] >= quorum:
                self.append("synod", "commit", {
                    "proposal": pid, "by": "quorum",
                    "note": f"aye={t['aye']} >= quorum={quorum}",
                })
                newly.append(pid)
        return newly

    def get_title(self, pid: str) -> str:
        for e in self.entries:
            if e.type == "propose" and e.data.get("id") == pid:
                return e.data.get("title", pid)
        return pid

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
                "proposed": 0, "ratified": 0, "passes": 0,
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

    def next_proposal_id(self) -> str:
        n = sum(1 for e in self.entries if e.type == "propose")
        return f"P{n + 1}"

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
