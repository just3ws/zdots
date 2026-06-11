import json
import os
import hashlib
import datetime
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


class ZsynodAgent:
    def __init__(self, actor_id: str, endpoint: str = None, model: str = None):
        self.actor_id = actor_id
        self.endpoint = (endpoint or os.environ.get("ZDOTS_AI_ENDPOINT", "http://127.0.0.1:11500")).rstrip("/")
        self.model = model  # None = per-actor default; override to force a specific model

    def _build_context(self, recent_discussion: List[LedgerEntry]) -> str:
        # Last 5 entries only — forces compression, keeps the prompt tight.
        lines = []
        for e in recent_discussion[-5:]:
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
                          token_callback=None, timeout: float = None) -> str:
        t = timeout or LOCAL_TICK_TIMEOUT
        payload = json.dumps({
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "stream": token_callback is not None,
            "max_tokens": 220,
            "temperature": 0.7,
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
                   members: List[str] = None, summary: str = "") -> str:
        context_str = self._build_context(recent_discussion)
        handles = " ".join(f"@{m}" for m in (members or [])) or "@mike @pi @aider @opencode @claude @gemini @codex"
        system_prompt = (
            f"You are @{self.actor_id} in the zsynod deliberation forum. "
            f"Members: {handles}. "
            f"Reply in ≤160 tokens. End every response with exactly 3 hashtags. "
            f"You may @mention members by handle. Few word do trick."
        )
        seed = f"{glyph} " if glyph else ""
        pinned = f"[STATE] {summary}\n" if summary else ""
        user_prompt = f"{seed}Topic: {topic}\n{pinned}{context_str}\n@{self.actor_id}:"

        labels = {"claude": "Claude CLI", "gemini": "Gemini CLI", "codex": "Codex CLI"}
        if progress_callback:
            progress_callback(f"[dim]Connecting to {labels.get(self.actor_id, self.endpoint)}...[/dim]")

        if self.actor_id == "claude":
            return self._deliberate_claude(system_prompt, user_prompt, token_callback, suggestion_callback, timeout)

        dispatch = {
            "gemini": self._deliberate_gemini,
            "codex":  self._deliberate_codex,
        }
        fn = dispatch.get(self.actor_id, self._deliberate_local)
        return fn(system_prompt, user_prompt, token_callback, timeout)


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
        committed = {e.data["proposal"] for e in self.entries if e.type == "commit"}
        return [p for pid, p in proposals.items() if pid not in committed]

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
        return {
            "aye": sum(1 for v in votes.values() if v == "aye"),
            "nay": sum(1 for v in votes.values() if v == "nay"),
            "abstain": sum(1 for v in votes.values() if v == "abstain"),
            "state": "committed" if committed else "open",
            "votes": votes,
        }

    def get_hashtag_analytics(self) -> dict:
        """Bi-directional hashtag index.

        Returns:
            tags:   {tag_lower: {tag, first_actor, first_ts, first_seq,
                                  actor_order, topics, total_uses, lifespan}}
            topic_tags: {pid: [{tag, first_actor, first_ts, seq}...]}  intro order
            titles: {pid: title}
        """
        import re
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
            pid = seq_to_pid.get(e.seq)
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
