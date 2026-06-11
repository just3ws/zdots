import json
import hashlib
import datetime
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
    def __init__(self, actor_id: str, model_path: str = "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"):
        self.actor_id = actor_id
        self.model_path = model_path
        self._model = None
        self._tokenizer = None

    def _ensure_model(self, progress_callback=None):
        if not self._model:
            from mlx_lm import load
            
            if progress_callback:
                progress_callback(f"[dim]Loading {self.model_path} (one-time download if not cached)...[/dim]")
            
            self._model, self._tokenizer = load(self.model_path)
            if progress_callback:
                progress_callback("[dim]Model loaded into GPU memory.[/dim]")

    def deliberate(self, topic: str, recent_discussion: List[LedgerEntry], progress_callback=None, token_callback=None) -> str:
        self._ensure_model(progress_callback=progress_callback)
        from mlx_lm import stream_generate
        
        # Build prompt from context safely
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
        prompt = (
            f"You are {self.actor_id}, an AI member of the Zsynod deliberation forum.\n"
            f"Topic: {topic}\n"
            f"Recent History:\n{context_str}\n"
            f"Your Remark (be brief and professional):"
        )
        
        full_remark = ""
        for response in stream_generate(self._model, self._tokenizer, prompt=prompt, max_tokens=200):
            full_remark += response.text
            if token_callback:
                token_callback(response.text)
        
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
