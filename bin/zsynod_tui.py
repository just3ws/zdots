import json
import os
import random
import shutil
import sys
import argparse
from pathlib import Path
from textual.app import App, ComposeResult, Screen
from textual.widgets import (
    Header, Footer, Static, RichLog, Input,
    ListView, ListItem, Label, TabbedContent, TabPane,
)
from textual.containers import Container, Horizontal, Vertical
from textual.binding import Binding
from textual.reactive import reactive

sys.path.append(str(Path(__file__).parent.parent / "lib"))
from zsynod_core import (
    LedgerManager, ZsynodAgent, AgentCircuitBreaker,
    TICK_TIMEOUT, LOCAL_TICK_TIMEOUT, tick_seed,
)
from zsynod_otel import setup_otel

_MEMBERS_PATH = Path(__file__).parent.parent / "zsynod" / "members.json"


# ── Hashtag / Topic Stats Screen ──────────────────────────────────────────────

class HashtagStatsScreen(Screen):
    """Page 2 — bi-directional hashtag ↔ topic analytics."""

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back", show=True),
        Binding("q",      "app.pop_screen", "Back", show=False),
    ]

    CSS = """
    HashtagStatsScreen #ht-list  { width: 32; border-right: solid $primary; }
    HashtagStatsScreen #top-list { width: 32; border-right: solid $primary; }
    HashtagStatsScreen RichLog   { height: 1fr; }
    HashtagStatsScreen .pane-row { height: 1fr; }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        with TabbedContent():
            with TabPane("Hashtags", id="tab-ht"):
                with Horizontal(classes="pane-row"):
                    yield ListView(id="ht-list")
                    yield RichLog(id="ht-detail", highlight=True, markup=True)
            with TabPane("Topics", id="tab-topics"):
                with Horizontal(classes="pane-row"):
                    yield ListView(id="top-list")
                    yield RichLog(id="top-detail", highlight=True, markup=True)
        yield Footer()

    def on_mount(self) -> None:
        ledger: LedgerManager = self.app.ledger
        ledger.load()
        self._analytics = ledger.get_hashtag_analytics()
        self._ledger = ledger
        self._ht_keys: list[str] = list(self._analytics["tags"].keys())
        self._top_pids: list[str] = self._all_proposal_ids()
        self._populate_ht_list()
        self._populate_top_list()

    def _all_proposal_ids(self) -> list[str]:
        # All proposals — open AND committed — sorted by first seq
        seen = {}
        for e in self._ledger.entries:
            if e.type == "propose":
                pid = e.data.get("id")
                if pid and pid not in seen:
                    seen[pid] = e.seq
        return sorted(seen, key=lambda p: seen[p])

    def _populate_ht_list(self) -> None:
        lv = self.query_one("#ht-list", ListView)
        lv.clear()
        for key in self._ht_keys:
            t = self._analytics["tags"][key]
            lv.append(ListItem(Label(
                f"[cyan]{t['tag']}[/cyan] "
                f"[dim]{t['total_uses']}× "
                f"{len(t['actor_order'])}mbr[/dim]"
            )))

    def _populate_top_list(self) -> None:
        lv = self.query_one("#top-list", ListView)
        lv.clear()
        titles = self._analytics["titles"]
        for pid in self._top_pids:
            tally = self._ledger.get_tally(pid)
            sc = "green" if tally["state"] == "committed" else "yellow"
            tag_count = len(self._analytics["topic_tags"].get(pid, []))
            lv.append(ListItem(Label(
                f"[{sc}][b]{pid}[/b][/{sc}] "
                f"{titles.get(pid, pid)[:20]} "
                f"[dim]{tag_count}#[/dim]"
            )))

    def on_list_view_highlighted(self, event: ListView.Highlighted) -> None:
        if event.item is None:
            return
        lv = event.list_view
        idx = lv._index if hasattr(lv, "_index") else None
        try:
            idx = list(lv._nodes).index(event.item)
        except (ValueError, AttributeError):
            return

        if lv.id == "ht-list" and idx < len(self._ht_keys):
            self._show_ht_detail(self._ht_keys[idx])
        elif lv.id == "top-list" and idx < len(self._top_pids):
            self._show_top_detail(self._top_pids[idx])

    def _show_ht_detail(self, key: str) -> None:
        t = self._analytics["tags"][key]
        log = self.query_one("#ht-detail", RichLog)
        log.clear()
        log.write(f"[b][cyan]{t['tag']}[/cyan][/b]  {t['total_uses']} uses  lifespan {t['lifespan']} entries")
        log.write(f"coined by [green]@{t['first_actor']}[/green] at {t['first_ts'][:19]}")
        log.write("")
        log.write("[b]Members (adoption order):[/b]")
        for i, actor in enumerate(t["actor_order"], 1):
            uses_by = sum(1 for u in t["uses"] if u["actor"] == actor)
            log.write(f"  {i}. [green]@{actor}[/green]  {uses_by}×")
        log.write("")
        log.write("[b]Topics:[/b]")
        titles = self._analytics["titles"]
        for pid in t["topics"]:
            tally = self._ledger.get_tally(pid)
            sc = "green" if tally["state"] == "committed" else "yellow"
            log.write(f"  [{sc}]{pid}[/{sc}] {titles.get(pid, pid)}")
        log.write("")
        log.write("[b]All uses (chronological):[/b]")
        for u in t["uses"]:
            pid_label = f" [{u['pid']}]" if u["pid"] else ""
            log.write(f"  seq {u['seq']:>4}  [green]@{u['actor']}[/green]{pid_label}  {u['ts'][:19]}")

    def _show_top_detail(self, pid: str) -> None:
        log = self.query_one("#top-detail", RichLog)
        log.clear()
        titles = self._analytics["titles"]
        tally = self._ledger.get_tally(pid)
        disc = self._ledger.get_proposal_discussion(pid)
        all_disc = [e for e in self._ledger.entries
                    if e.type in ("speak", "discuss")
                    and self._ledger.get_hashtag_analytics  # analytics already built
                    ]
        sc = "green" if tally["state"] == "committed" else "yellow"

        log.write(f"[b][{sc}]{pid}[/{sc}][/b]  {titles.get(pid, pid)}")
        log.write(
            f"[green]aye {tally['aye']}[/green]  "
            f"[red]nay {tally['nay']}[/red]  "
            f"abs {tally['abstain']}  "
            f"state: [{sc}]{tally['state']}[/{sc}]"
        )

        if tally["votes"]:
            vote_line = "  ".join(
                f"[{'green' if v=='aye' else 'red' if v=='nay' else 'dim'}]@{a}:{v[0]}[/]"
                for a, v in sorted(tally["votes"].items())
            )
            log.write(f"Votes: {vote_line}")

        # Participants from discussion entries
        participants = list(dict.fromkeys(e.actor for e in disc))
        log.write(f"Participants: {' '.join(f'[cyan]@{a}[/cyan]' for a in participants)}")
        log.write(f"Entries in thread: {len(disc)}")

        # Hashtag timeline
        topic_ht = self._analytics["topic_tags"].get(pid, [])
        log.write("")
        if topic_ht:
            log.write("[b]Hashtags (introduction order):[/b]")
            for i, h in enumerate(topic_ht, 1):
                log.write(
                    f"  {i}. [cyan]{h['tag']}[/cyan]  "
                    f"coined by [green]@{h['first_actor']}[/green]  "
                    f"seq {h['seq']}  {h['first_ts'][:19]}"
                )
        else:
            log.write("[dim](no hashtags recorded in this thread)[/dim]")

        # Summary if available
        summary = self._ledger.get_latest_summary(pid)
        if summary:
            log.write("")
            log.write(f"[b]Latest state:[/b] [dim]{summary}[/dim]")


# ── Main App ──────────────────────────────────────────────────────────────────

class ZsynodApp(App):
    THEME = "dracula"

    CSS = """
    Screen { layers: base; }
    #main-container { height: 1fr; }
    #sidebar {
        width: 36;
        background: $panel;
        border-right: solid $primary;
    }
    #proposal-list { height: 1fr; border-bottom: solid $primary; }
    #tally-box {
        height: 9;
        padding: 1;
    }
    #content-area { height: 1fr; }
    #discussion-log { height: 1fr; border: solid $accent; }
    #thinking-box {
        height: auto;
        min-height: 1;
        max-height: 5;
        background: $surface;
        color: $accent;
        padding: 0 1;
        border-top: tall $accent;
        display: none;
    }
    """

    BINDINGS = [
        Binding("q",     "quit",          "Quit",    show=True),
        Binding("t",     "tick",          "Tick",    show=True),
        Binding("a",     "vote_aye",      "Aye",     show=True),
        Binding("n",     "vote_nay",      "Nay",     show=True),
        Binding("s",     "second",        "Second",  show=True),
        Binding("r",     "ratify",        "Ratify",  show=True),
        Binding("slash", "toggle_view",   "All/Prop",show=True),
        Binding("p",     "hashtag_stats", "Stats",   show=True),
    ]

    show_all = reactive(False)

    def compose(self) -> ComposeResult:
        yield Header()
        with Container(id="main-container"):
            with Horizontal():
                with Vertical(id="sidebar"):
                    yield ListView(id="proposal-list")
                    yield Static(id="tally-box")
                with Vertical(id="content-area"):
                    yield RichLog(id="discussion-log", highlight=True, markup=True)
                    yield Static(id="thinking-box")
        yield Input(
            placeholder="speak <remark> | propose <title> | aye/nay/ratify [PID]",
            id="command-input",
        )
        yield Footer()

    def on_mount(self) -> None:
        self.tracer = setup_otel("zsynod-py-tui")
        self.ledger = LedgerManager(self.args.ledger)
        self.selected_pid = None
        self.last_seen_seq = -1
        self.current_thought = ""

        # Triumvirate (pi/aider/opencode) share local llama.cpp but carry
        # distinct lane identities in the system prompt — same model, different voice.
        self.agents = [
            ZsynodAgent("pi",       endpoint=self.args.endpoint),
            ZsynodAgent("aider",    endpoint=self.args.endpoint),
            ZsynodAgent("opencode", endpoint=self.args.endpoint),
            ZsynodAgent("claude"),
            ZsynodAgent("gemini"),
            ZsynodAgent("codex"),
        ]
        _cli_ids = {"claude", "gemini", "codex"}
        self.breakers = {
            a.actor_id: AgentCircuitBreaker(
                TICK_TIMEOUT if a.actor_id in _cli_ids else LOCAL_TICK_TIMEOUT
            )
            for a in self.agents
        }

        def _cli(name): return "[green]✓[/green]" if shutil.which(name) else "[dim]–[/dim]"
        log = self.query_one("#discussion-log", RichLog)
        log.write(f"[b][cyan]Zsynod-Py[/cyan][/b]  local:{self.agents[0].endpoint}")
        log.write(
            f"[dim]claude:{_cli('claude')} "
            f"gemini:{_cli('gemini')} "
            f"codex:{_cli('codex')}[/dim]"
        )
        self.refresh_data()
        self.set_interval(3.0, self.refresh_data)

    # ── members / quorum ──────────────────────────────────────────────────────

    def _all_members(self) -> list:
        try:
            data = json.loads(_MEMBERS_PATH.read_text())
            return [m["id"] for m in data["members"]]
        except Exception:
            return [a.actor_id for a in self.agents] + ["mike"]

    def _voting_members(self) -> list:
        try:
            data = json.loads(_MEMBERS_PATH.read_text())
            return [m["id"] for m in data["members"] if m.get("voting")]
        except Exception:
            return []

    def _quorum(self) -> int:
        n = len(self._voting_members())
        return n // 2 + 1

    # ── rendering ────────────────────────────────────────────────────────────

    def log_message(self, message: str) -> None:
        self.query_one("#discussion-log", RichLog).write(message)

    def update_thinking(self, token: str, actor: str = "?") -> None:
        self.current_thought += token
        box = self.query_one("#thinking-box", Static)
        box.display = True
        box.update(f"[i]{actor}:[/i] {self.current_thought}█")

    def _clear_thinking(self) -> None:
        self.current_thought = ""
        box = self.query_one("#thinking-box", Static)
        box.display = False
        box.update("")

    @staticmethod
    def _style_remark(text: str) -> str:
        """Dim hashtags, highlight @mentions, append token estimate."""
        import re
        words = text.split()
        styled = []
        for w in words:
            if w.startswith("#"):
                styled.append(f"[dim]{w}[/dim]")
            elif w.startswith("@"):
                styled.append(f"[bold]{w}[/bold]")
            else:
                styled.append(w)
        # rough token estimate: words ≈ tokens at ~1.3 ratio
        est = max(1, int(len(words) / 1.3))
        return " ".join(styled) + f" [dim][{est}t][/dim]"

    def _render_entry(self, log: RichLog, e) -> None:
        ac = "green" if e.actor == "mike" else "cyan"
        actor = f"[{ac}]@{e.actor}[/{ac}]"
        if e.type in ["speak", "discuss"]:
            log.write(f"{actor}: {self._style_remark(e.data.get('remark', ''))}")
        elif e.type == "propose":
            log.write(f"[b][yellow]── {e.data['id']}: {e.data['title']} ──[/yellow][/b]")
            if "body" in e.data:
                log.write(f"   [dim]{e.data['body']}[/dim]")
        elif e.type == "vote":
            v = e.data["vote"]
            vc = "green" if v == "aye" else "red" if v == "nay" else "yellow"
            note = f" — {e.data['note']}" if e.data.get("note") else ""
            log.write(f"{actor}: [{vc}]{v}[/{vc}] on {e.data.get('proposal', '?')}{note}")
        elif e.type == "second":
            log.write(f"{actor}: seconded {e.data.get('proposal', '?')}")
        elif e.type == "commit":
            note = f" — {e.data.get('note', '')}" if e.data.get("note") else ""
            log.write(f"[b][green]★ RATIFIED {e.data.get('proposal', '?')}[/green][/b]{note}")
        elif e.type == "handoff":
            log.write(
                f"{actor} [magenta]→[/magenta] "
                f"{e.data.get('to','?')}: {e.data.get('task','')}"
            )

    def _update_tally(self) -> None:
        box = self.query_one("#tally-box", Static)
        pid = self.selected_pid
        if not pid:
            box.update("[dim](select a proposal)[/dim]")
            return
        t = self.ledger.get_tally(pid)
        q = self._quorum()
        n = len(self._voting_members())
        sc = "green" if t["state"] == "committed" else ("yellow" if t["aye"] >= q else "red")
        lines = [
            f"[b]{pid}[/b]  [{sc}]{t['state']}[/{sc}]",
            f"aye [b]{t['aye']}[/b]/{q}  nay {t['nay']}  abs {t['abstain']}  ({n} voting)",
        ]
        if t["votes"]:
            lines.append("  ".join(
                f"[{'green' if v=='aye' else 'red' if v=='nay' else 'dim'}]{a}:{v[0]}[/]"
                for a, v in sorted(t["votes"].items())
            ))
        box.update("\n".join(lines))

    def _rebuild_proposal_list(self) -> None:
        lv = self.query_one("#proposal-list", ListView)
        proposals = self.ledger.get_proposals()
        lv.clear()
        q = self._quorum()
        for p in proposals:
            pid = p.data["id"]
            t = self.ledger.get_tally(pid)
            c = "green" if t["state"] == "committed" else ("yellow" if t["aye"] >= q else "white")
            item = ListItem(Label(f"[{c}][b]{pid}[/b][/{c}] {p.data['title'][:24]}"))
            item.pid = pid
            lv.append(item)
        if not proposals:
            blank = ListItem(Label("[dim](no open proposals)[/dim]"))
            blank.pid = None
            lv.append(blank)

    def on_list_view_highlighted(self, event: ListView.Highlighted) -> None:
        pid = getattr(event.item, "pid", None) if event.item else None
        if pid == self.selected_pid:
            return
        self.selected_pid = pid
        self._update_tally()
        if pid and not self.show_all:
            self._show_proposal_thread(pid)

    def _show_proposal_thread(self, pid: str) -> None:
        log = self.query_one("#discussion-log", RichLog)
        log.clear()
        log.write(f"[dim]── {pid} thread  ([/][b]/[/b][dim] for full timeline) ──[/dim]")
        for e in self.ledger.get_proposal_discussion(pid):
            self._render_entry(log, e)

    # ── actions ───────────────────────────────────────────────────────────────

    def action_tick(self) -> None:
        self.run_worker(self.perform_tick, thread=True)

    def action_vote_aye(self) -> None:
        self._cast_vote("aye")

    def action_vote_nay(self) -> None:
        self._cast_vote("nay")

    def action_second(self) -> None:
        if self.selected_pid:
            self.ledger.append("mike", "second", {"proposal": self.selected_pid})
            self.log_message(f"[green]mike:[/green] seconded {self.selected_pid}")
            self.refresh_data()

    def action_ratify(self) -> None:
        if self.selected_pid:
            self.ledger.append("mike", "commit", {
                "proposal": self.selected_pid, "by": "principal",
                "note": "ratified via cockpit",
            })
            self.log_message(f"[green]mike:[/green] [green]★ RATIFIED[/green] {self.selected_pid}")
            self.refresh_data()

    def action_toggle_view(self) -> None:
        self.show_all = not self.show_all
        if self.show_all or not self.selected_pid:
            log = self.query_one("#discussion-log", RichLog)
            log.clear()
            log.write(f"[dim]── full timeline ──[/dim]")
            self.last_seen_seq = -1
            for e in self.ledger.get_discussion(limit=200):
                self._render_entry(log, e)
                self.last_seen_seq = e.seq
        else:
            self._show_proposal_thread(self.selected_pid)

    def action_hashtag_stats(self) -> None:
        self.push_screen(HashtagStatsScreen())

    def _cast_vote(self, vote: str) -> None:
        pid = self.selected_pid
        if not pid:
            self.log_message("[yellow]select a proposal first[/yellow]")
            return
        self.ledger.append("mike", "vote", {"proposal": pid, "vote": vote, "note": "via cockpit"})
        vc = "green" if vote == "aye" else "red"
        self.log_message(f"[green]mike:[/green] [{vc}]{vote}[/{vc}] on {pid}")
        self.refresh_data()

    # ── tick ──────────────────────────────────────────────────────────────────

    def perform_tick(self) -> None:
        with self.tracer.start_as_current_span("deliberation_tick") as span:
            discussion = self.ledger.get_discussion(limit=200)
            proposals = self.ledger.get_proposals()
            # Tick on the selected proposal if one is focused, else the first open one
            if self.selected_pid:
                topic = next(
                    (p.data["title"] for p in proposals if p.data["id"] == self.selected_pid),
                    self.selected_pid,
                )
            else:
                topic = proposals[0].data["title"] if proposals else "General status"
            span.set_attribute("zsynod.topic", topic)

            glyph = tick_seed()
            self.call_from_thread(self.log_message, f"[dim]── {glyph} ──[/dim]")

            # Fetch the pinned state summary for context (written at end of last tick)
            pid = self.selected_pid
            members = self._all_members()
            summary = self.ledger.get_latest_summary(pid) if pid else ""

            import subprocess
            active = 0
            for agent in self.agents:
                actor = agent.actor_id
                breaker = self.breakers[actor]

                if not breaker.is_ready():
                    self.call_from_thread(
                        self.log_message,
                        f"[dim]⏭ {actor}: {breaker.skip_label()}[/dim]",
                    )
                    continue

                active += 1
                self.current_thought = ""

                def token_cb(token, a=actor):
                    self.call_from_thread(self.update_thinking, token, a)

                def suggestion_cb(s, a=actor):
                    self.call_from_thread(
                        self.log_message,
                        f"[dim]nudge ({a}): {s}[/dim]",
                    )

                try:
                    remark = agent.deliberate(
                        topic, discussion,
                        progress_callback=self.log_message,
                        token_callback=token_cb,
                        suggestion_callback=suggestion_cb,
                        glyph=glyph,
                        timeout=breaker.current_timeout(),
                        members=members,
                        summary=summary,
                    )
                    breaker.record_success()
                    self.ledger.append(actor, "speak", {"remark": remark})
                    discussion = self.ledger.get_discussion(limit=200)
                except (TimeoutError, subprocess.TimeoutExpired):
                    breaker.record_timeout()
                    self.call_from_thread(
                        self.log_message,
                        f"[yellow]⏱ {actor} timed out[/yellow] [dim]→ backing off "
                        f"({breaker._consecutive}×, next budget {breaker.current_timeout():.0f}s, "
                        f"skip {breaker._skip_remaining} ticks)[/dim]",
                    )
                except Exception as e:
                    self.call_from_thread(
                        self.log_message,
                        f"[yellow]⚠ {actor} skipped:[/yellow] [dim]{e}[/dim]",
                    )
                finally:
                    self.call_from_thread(self._clear_thinking)

            if active == 0:
                self.call_from_thread(
                    self.log_message,
                    "[dim]── all agents backed off; wheel rolls on ──[/dim]",
                )

            # ── summarizer pass ───────────────────────────────────────────────
            # After all voices have spoken, write a compact state summary for
            # the focused proposal. Next tick reads it as pinned [STATE] context.
            if pid and active > 0:
                try:
                    self.ledger.load()
                    prop_discussion = self.ledger.get_proposal_discussion(pid)
                    tally = self.ledger.get_tally(pid)
                    prop_entry = next(
                        (e for e in self.ledger.entries
                         if e.type == "propose" and e.data.get("id") == pid), None
                    )
                    title = prop_entry.data.get("title", pid) if prop_entry else pid
                    summarizer = ZsynodAgent("summarizer", endpoint=self.agents[0].endpoint)
                    text = summarizer.summarize(pid, title, prop_discussion, tally)
                    self.ledger.append("summarizer", "summary", {"proposal": pid, "text": text})
                    self.call_from_thread(
                        self.log_message,
                        f"[dim]📋 {pid} state: {text[:80]}{'…' if len(text) > 80 else ''}[/dim]",
                    )
                except Exception as e:
                    self.call_from_thread(
                        self.log_message,
                        f"[dim]summarizer skipped: {e}[/dim]",
                    )

    # ── polling refresh ────────────────────────────────────────────────────────

    def refresh_data(self) -> None:
        self.ledger.load()
        self._rebuild_proposal_list()
        self._update_tally()

        # Append-only in full-timeline mode; filtered view rebuilds on selection
        if self.selected_pid and not self.show_all:
            self._show_proposal_thread(self.selected_pid)
        else:
            log = self.query_one("#discussion-log", RichLog)
            for e in self.ledger.get_discussion(limit=200):
                if e.seq > self.last_seen_seq:
                    self._render_entry(log, e)
                    self.last_seen_seq = e.seq

    # ── input bar ─────────────────────────────────────────────────────────────

    def on_input_submitted(self, event: Input.Submitted) -> None:
        cmd_text = event.value.strip()
        if not cmd_text:
            return
        self.query_one("#command-input").value = ""
        parts = cmd_text.split(maxsplit=1)
        action = parts[0].lower()
        rest = parts[1] if len(parts) > 1 else ""

        try:
            with self.tracer.start_as_current_span(f"cmd_{action}"):
                if action == "speak":
                    self.ledger.append("mike", "speak", {"remark": rest or cmd_text})
                elif action == "propose":
                    if not rest:
                        self.log_message("[red]propose needs a title[/red]")
                        return
                    pid = self.ledger.next_proposal_id()
                    self.ledger.append("mike", "propose", {"id": pid, "title": rest})
                    self.log_message(f"[green]mike:[/green] proposed [b]{pid}[/b]: {rest}")
                elif action in ["aye", "nay", "abstain"]:
                    pid = rest.upper() if rest else self.selected_pid
                    if not pid:
                        self.log_message("[yellow]no proposal selected[/yellow]")
                        return
                    self.ledger.append("mike", "vote", {"proposal": pid, "vote": action, "note": "via cockpit"})
                    vc = "green" if action == "aye" else "red" if action == "nay" else "yellow"
                    self.log_message(f"[green]mike:[/green] [{vc}]{action}[/{vc}] on {pid}")
                elif action == "ratify":
                    pid = rest.upper() if rest else self.selected_pid
                    if not pid:
                        self.log_message("[yellow]no proposal selected[/yellow]")
                        return
                    self.ledger.append("mike", "commit", {"proposal": pid, "by": "principal", "note": "ratified via cockpit"})
                    self.log_message(f"[green]mike:[/green] [green]★ RATIFIED[/green] {pid}")
                elif action == "tick":
                    self.action_tick()
                    return
                else:
                    self.ledger.append("mike", "speak", {"remark": cmd_text})
                self.refresh_data()
        except Exception as e:
            self.log_message(f"[red]Error:[/red] {e}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Zsynod Cockpit — proposal navigation, voting, and deliberation.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--ledger", type=Path,
        default=Path.home() / ".config" / "zsh" / "zsynod" / "ledger.py.jsonl",
    )
    parser.add_argument("--endpoint", type=str, default=None)
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    if not args.ledger.exists():
        print(f"Error: Ledger not found at {args.ledger}. Run 'zsynod-migrate' first.")
        sys.exit(1)
    app = ZsynodApp()
    app.args = args
    app.run()
