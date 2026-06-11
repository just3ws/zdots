import json
import os
import hashlib
import datetime
import urllib.request
from pathlib import Path
from pydantic import BaseModel, Field
from typing import Any, List, Optional

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
    def __init__(self, actor_id: str, endpoint: str = None):
        self.actor_id = actor_id
        self.endpoint = (endpoint or os.environ.get("ZDOTS_AI_ENDPOINT", "http://127.0.0.1:11500")).rstrip("/")

    def deliberate(self, topic: str, recent_discussion: List[LedgerEntry], progress_callback=None, token_callback=None) -> str:
        context_lines = []
        for e in recent_discussion:
            if "remark" in e.data:
                context_lines.append(f"{e.actor}: {e.data['remark']}")
            elif e.type == "propose":
                context_lines.append(f"{e.actor} PROPOSED: {e.data.get('title', 'Untitled')}")
            elif e.type == "vote":
                context_lines.append(f"{e.actor} VOTED: {e.data.get('vote', 'unknown')} on {e.data.get('proposal', '?')}")
            elif e.type == "commit":
                context_lines.append(f"PRINCIPAL RATIFIED: {e.data.get('proposal', '?')}")

        context_str = "\n".join(context_lines)

        if progress_callback:
            progress_callback(f"[dim]Connecting to {self.endpoint}...[/dim]")

        payload = json.dumps({
            "messages": [
                {"role": "system", "content": f"You are {self.actor_id}, an AI member of the Zsynod deliberation forum."},
                {"role": "user", "content": f"Topic: {topic}\nRecent History:\n{context_str}\nYour Remark (be brief and professional):"},
            ],
            "stream": token_callback is not None,
            "max_tokens": 200,
            "temperature": 0.7,
        }).encode()

        req = urllib.request.Request(
            f"{self.endpoint}/v1/chat/completions",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        full_remark = ""
        with urllib.request.urlopen(req, timeout=120) as resp:
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
        # Return most recent entries of all types for a full timeline
        return self.entries[-limit:]

    def get_proposals(self) -> List[LedgerEntry]:
        # Track active proposals (not yet committed)
        proposals = {e.data["id"]: e for e in self.entries if e.type == "propose"}
        committed = {e.data["proposal"] for e in self.entries if e.type == "commit"}
        return [p for pid, p in proposals.items() if pid not in committed]

    def get_blocking_items(self) -> List[dict]:
        # Simple logic for now: proposals that are open
        items = []
        for p in self.get_proposals():
            items.append({"id": p.data["id"], "type": "proposal", "label": p.data["title"]})
        return items

    def append(self, actor: str, entry_type: str, data: dict, round_num: Optional[int] = None) -> LedgerEntry:
        """
        Safely append a new entry to the ledger with locking and hash-chaining.
        """
        lock_path = self.path.parent / ".lock"
        
        # 1. Acquire Lock (Simple spin-lock matching Bash logic)
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
            # 2. Prepare Entry
            self.load() # Refresh to get latest state
            prev_hash = self.entries[-1].hash if self.entries else "GENESIS"
            seq = len(self.entries)
            
            # Use current round if not specified
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

            # 3. Write to File
            with open(self.path, "a") as f:
                f.write(entry.model_dump_json() + "\n")
            
            self.entries.append(entry)
            return entry

        finally:
            # 4. Release Lock
            try:
                lock_path.rmdir()
            except FileNotFoundError:
                pass
