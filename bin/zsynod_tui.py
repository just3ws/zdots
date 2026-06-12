import datetime
import fcntl
import json
import os
import random
import re
import shutil
import sys
import time
import argparse
from pathlib import Path
from rich.markup import escape as _esc
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
    LedgerManager, ZsynodAgent, AgentCircuitBreaker, KnowledgeBase,
    TICK_TIMEOUT, LOCAL_TICK_TIMEOUT, tick_seed, parse_directives,
    DIALS, load_dials, save_dials, format_decision_lesson, devils_advocate,
    LedgerIntegrityError,
)
from zsynod_otel import setup_otel

_MEMBERS_PATH = Path(__file__).parent.parent / "zsynod" / "members.json"
_PID_FILE = Path.home() / ".local" / "run" / "zsynod.pid"

_STATE_COLORS = {
    "NEW": "cyan", "ACTIVE": "white", "PASSING": "yellow",
    "STUCK": "red", "RATIFIED": "green", "CLOSED": "bright_black",
}


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


# ── Control Plane Screen ──────────────────────────────────────────────────────

class ControlPlaneScreen(Screen):
    """Page 3 — dials, mute toggles, and per-member insight.

    Dials tab: ←/→ adjusts the highlighted knob by its step; m (or space)
    toggles mute on a member row. Every change writes zsynod/dials.json
    immediately, so the next tick — TUI or headless pulse — picks it up.
    Members tab: activity profile derived from the chain, including the
    repetition gauge that drives the 💭 loop-breaker.
    """

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back",  show=True),
        Binding("q",      "app.pop_screen", "Back",  show=False),
        Binding("left",   "adjust(-1)",     "−step", show=True),
        Binding("right",  "adjust(1)",      "+step", show=True),
        Binding("m",      "toggle_mute",    "Mute",  show=True),
        Binding("space",  "toggle_mute",    "Mute",  show=False),
    ]

    CSS = """
    ControlPlaneScreen #dial-list { width: 36; border-right: solid $primary; }
    ControlPlaneScreen RichLog    { height: 1fr; }
    ControlPlaneScreen .pane-row  { height: 1fr; }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        with TabbedContent():
            with TabPane("Dials", id="tab-dials"):
                with Horizontal(classes="pane-row"):
                    yield ListView(id="dial-list")
                    yield RichLog(id="dial-detail", highlight=True, markup=True)
            with TabPane("Members", id="tab-members"):
                yield RichLog(id="member-stats", highlight=True, markup=True)
        yield Footer()

    def on_mount(self) -> None:
        self._members = [m for m in self.app._all_members() if m != "mike"]
        self._rows = [("dial", name) for name in DIALS] \
                   + [("mute", m) for m in self._members]
        self._refresh_rows(keep=0)
        self._render_member_stats()

    # ── dials tab ─────────────────────────────────────────────────────────────

    def _refresh_rows(self, keep: int = None) -> None:
        lv = self.query_one("#dial-list", ListView)
        old = keep if keep is not None else (lv.index or 0)
        lv.clear()
        dials = self.app.dials
        for kind, name in self._rows:
            if kind == "dial":
                spec = DIALS[name]
                v = dials[name]
                val = f"{v:.2f}" if isinstance(spec["default"], float) else f"{int(v)}"
                lv.append(ListItem(Label(f"🎛 [b]{name:<15}[/b] [cyan]{val}[/cyan]")))
            else:
                muted = name in dials["muted"]
                icon = "[red]🔇 muted[/red]" if muted else "[green]🔊 live[/green]"
                lv.append(ListItem(Label(f"  [b]@{name:<14}[/b] {icon}")))
        lv.index = min(old, len(self._rows) - 1)

    def _row_at_cursor(self):
        lv = self.query_one("#dial-list", ListView)
        idx = lv.index if lv.index is not None else 0
        return self._rows[idx] if idx < len(self._rows) else (None, None)

    def on_list_view_highlighted(self, event: ListView.Highlighted) -> None:
        if event.list_view.id != "dial-list":
            return
        kind, name = self._row_at_cursor()
        log = self.query_one("#dial-detail", RichLog)
        log.clear()
        if kind == "dial":
            spec = DIALS[name]
            log.write(f"[b][cyan]{name}[/cyan][/b] = {self.app.dials[name]}")
            log.write(f"[dim]range {spec['min']}–{spec['max']}, step {spec['step']}[/dim]")
            log.write("")
            log.write(spec["help"])
        elif kind == "mute":
            muted = name in self.app.dials["muted"]
            log.write(f"[b]@{name}[/b] — {'[red]muted[/red]' if muted else '[green]live[/green]'}")
            log.write("[dim]m toggles. Muted members are skipped in every tick "
                      "until unmuted; the ledger records nothing for them.[/dim]")
            rep = self.app.ledger.get_repetition(name, int(self.app.dials["loop_window"]))
            warn = " [red]⚠ looping[/red]" if rep >= self.app.dials["loop_threshold"] else ""
            log.write(f"repetition: {rep:.0%}{warn}")

    def action_adjust(self, direction: int) -> None:
        kind, name = self._row_at_cursor()
        if kind != "dial":
            return
        spec = DIALS[name]
        v = self.app.dials[name] + direction * spec["step"]
        v = min(max(v, spec["min"]), spec["max"])
        self.app.dials[name] = int(v) if isinstance(spec["default"], int) else round(v, 4)
        save_dials(self.app.dials_path, self.app.dials)
        self._refresh_rows()
        self._show_detail_for_cursor()

    def action_toggle_mute(self) -> None:
        kind, name = self._row_at_cursor()
        if kind != "mute":
            return
        muted = self.app.dials["muted"]
        if name in muted:
            muted.remove(name)
        else:
            muted.append(name)
        save_dials(self.app.dials_path, self.app.dials)
        self._refresh_rows()
        self._show_detail_for_cursor()

    def _show_detail_for_cursor(self) -> None:
        class _Ev:  # minimal stand-in to reuse the highlight renderer
            pass
        ev = _Ev()
        ev.list_view = self.query_one("#dial-list", ListView)
        self.on_list_view_highlighted(ev)

    # ── members tab ───────────────────────────────────────────────────────────

    def _render_member_stats(self) -> None:
        ledger: LedgerManager = self.app.ledger
        ledger.load()
        dials = self.app.dials
        stats = ledger.get_member_stats(loop_window=int(dials["loop_window"]))
        top_seq = ledger.entries[-1].seq if ledger.entries else 0
        q = self.app._quorum()
        open_n = len(ledger.get_proposals())

        log = self.query_one("#member-stats", RichLog)
        log.clear()
        log.write(f"[dim]ledger {top_seq + 1} entries · {open_n} open topics · quorum {q}[/dim]")
        log.write("")
        log.write("[b]member      spk  aye nay abs 2nd | prop ✓rat pass | @out @in | idle  rep  aye%[/b]")

        ranked = sorted(stats.items(), key=lambda kv: -kv[1]["speaks"])
        for name, m in ranked:
            idle = top_seq - m["last_seq"]
            rep = m["repetition"]
            looping = rep >= dials["loop_threshold"]
            rep_s = f"[red]⚠{rep:.0%}[/red]" if looping else f"[dim]{rep:.0%}[/dim]"
            mute_s = " [red]🔇[/red]" if name in dials["muted"] else ""
            # aye-rate: the sycophancy gauge. ⚠ at ≥90% over 5+ votes —
            # a measured yes-machine, visible to the chair and the operator.
            cast = m["aye"] + m["nay"] + m["abstain"]
            if cast:
                rate = m["aye"] / cast
                aye_s = (f"[red]⚠{rate:.0%}[/red]" if cast >= 5 and rate >= 0.9
                         else f"[dim]{rate:.0%}[/dim]")
            else:
                aye_s = "[dim]  –[/dim]"
            log.write(
                f"@{name:<10} {m['speaks']:>4} {m['aye']:>4} {m['nay']:>3} "
                f"{m['abstain']:>3} {m['seconds']:>3} | {m['proposed']:>4} "
                f"{m['ratified']:>4} {m['passes']:>4} | {m['mentions_out']:>4} "
                f"{m['mentions_in']:>3} | {idle:>4}  {rep_s}  {aye_s}{mute_s}"
            )
        log.write("")
        log.write("[dim]rep = max overlap of recent remarks (hashtags/@handles "
                  "excluded). ⚠ rows get a forced 💭 loop-breaker next turn. "
                  "aye% ⚠ at ≥90% over 5+ votes — the sycophancy gauge.[/dim]")


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
    #timer-bar {
        height: 1;
        background: $panel;
        padding: 0 1;
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
        Binding("c",     "control_plane", "Dials",   show=True),
        Binding("o",     "toggle_auto",   "Auto",    show=True),
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
        yield Static(id="timer-bar")
        yield Input(
            placeholder="speak | propose | aye/nay/ratify/close [PID] | dial | auto [s] | kb <term> | digest | mute @m",
            id="command-input",
        )
        yield Footer()

    def _acquire_pid_lock(self) -> None:
        """Exclusive flock on _PID_FILE — auto-released on process death."""
        _PID_FILE.parent.mkdir(parents=True, exist_ok=True)
        try:
            self._pid_fh = open(_PID_FILE, "w")
            fcntl.flock(self._pid_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self._pid_fh.write(str(os.getpid()))
            self._pid_fh.flush()
        except IOError:
            existing = _PID_FILE.read_text().strip() if _PID_FILE.exists() else "unknown"
            print(
                f"\nzsynod is already running (pid {existing}).\n"
                "Attach with:  zsynod ui\n",
                file=sys.stderr,
            )
            sys.exit(1)

    def on_unmount(self) -> None:
        fh = getattr(self, "_pid_fh", None)
        if fh:
            try:
                fcntl.flock(fh, fcntl.LOCK_UN)
                fh.close()
                _PID_FILE.unlink(missing_ok=True)
            except Exception:
                pass

    def on_mount(self) -> None:
        self._acquire_pid_lock()
        self.tracer = setup_otel("zsynod-py-tui")
        self.ledger = LedgerManager(self.args.ledger)
        self.dials_path = self.args.ledger.parent / "dials.json"
        self.dials = load_dials(self.dials_path)
        self.selected_pid = None
        self.last_seen_seq = -1
        self.current_thought = ""
        self.kb = KnowledgeBase()

        # Auto-pilot: multi-tick runs gated on forum silence. Any new ledger
        # entry re-arms the countdown; expiry fires the next tick. The cap
        # forces a deliberate re-engage — unattended cloud seats cost tokens.
        self.auto_on = False
        self.auto_deadline = None
        self.auto_ticks_done = 0
        self._tick_running = False
        self._agent_name = None
        self._agent_started = 0.0
        self._agent_budget = 0.0

        # Seats come from members.json via the member contract — recruiting
        # is a data row, not a code change. Clerks (summarizer, recorder,
        # herald) always run on the local endpoint regardless of seat order.
        self._dormant_members = []
        self._ticks_total = 0
        self.agents = self._seat_members()
        self.breakers = {
            a.actor_id: AgentCircuitBreaker(
                LOCAL_TICK_TIMEOUT if a.backend == "local" else TICK_TIMEOUT
            )
            for a in self.agents
        }

        def _cli(name): return "[green]✓[/green]" if shutil.which(name) else "[dim]–[/dim]"
        log = self.query_one("#discussion-log", RichLog)
        log.write(f"[b][cyan]Zsynod-Py[/cyan][/b]  local:{self.args.endpoint}")
        log.write(
            f"[dim]claude:{_cli('claude')} "
            f"gemini:{_cli('gemini')} "
            f"codex:{_cli('codex')}"
            + (f"  dormant: {' '.join('@' + d for d in self._dormant_members)}"
               if self._dormant_members else "")
            + "[/dim]"
        )
        self.refresh_data()
        self.set_interval(3.0, self.refresh_data)
        self.set_interval(1.0, self._update_timer_bar)
        self._update_timer_bar()

    # ── members / quorum ──────────────────────────────────────────────────────

    def _seat_members(self) -> list:
        """Seat every member from members.json that has a reachable backend.

        Resolution per member: an explicit `"backend": "openai"` block
        (base_url/model/key_env — key read from the environment, never a
        file) → OpenAI-compat seat; tier `local` → llama.cpp at --endpoint;
        a known vendor CLI (id or `command` ∈ claude/gemini/codex) → CLI
        seat. Principal and represented seats are skipped; anything else is
        dormant and announced. Broken members.json → the classic six, because
        the forum always runs."""
        fallback = [
            ZsynodAgent("pi",       endpoint=self.args.endpoint),
            ZsynodAgent("aider",    endpoint=self.args.endpoint),
            ZsynodAgent("opencode", endpoint=self.args.endpoint),
            ZsynodAgent("claude"),
            ZsynodAgent("gemini"),
            ZsynodAgent("codex"),
        ]
        try:
            members = json.loads(_MEMBERS_PATH.read_text())["members"]
        except Exception:
            return fallback
        _CLIS = ("claude", "gemini", "codex")
        seats = []
        for m in members:
            mid = m["id"]
            if m.get("tier") == "principal" or m.get("represented_by"):
                continue
            if m.get("backend") == "openai":
                seats.append(ZsynodAgent(mid, backend="openai",
                                         base_url=m.get("base_url", ""),
                                         model=m.get("model"),
                                         key_env=m.get("key_env"),
                                         key_cmd=m.get("key_cmd")))
            elif m.get("tier") == "local":
                seats.append(ZsynodAgent(mid, endpoint=self.args.endpoint))
            elif mid in _CLIS or m.get("command") in _CLIS:
                cmd = m["command"] if m.get("command") in _CLIS else mid
                if not shutil.which(cmd):
                    self._dormant_members.append(mid)
                    continue
                seats.append(ZsynodAgent(mid, backend="cli", command=cmd))
            else:
                self._dormant_members.append(mid)
        return seats or fallback

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
        words = text.split()
        styled = []
        for w in words:
            safe = _esc(w)
            if w.startswith("#"):
                styled.append(f"[dim]{safe}[/dim]")
            elif w.startswith("@"):
                styled.append(f"[bold]{safe}[/bold]")
            else:
                styled.append(safe)
        est = max(1, int(len(words) / 1.3))
        return " ".join(styled) + f" [dim][{est}t][/dim]"

    def _render_entry(self, log: RichLog, e) -> None:
        ac = "green" if e.actor == "mike" else "cyan"
        actor = f"[{ac}]@{_esc(e.actor)}[/{ac}]"
        if e.type in ["speak", "discuss"]:
            log.write(f"{actor}: {self._style_remark(e.data.get('remark', ''))}")
        elif e.type == "propose":
            pid = _esc(e.data.get('id', '?'))
            title = _esc(e.data.get('title', ''))
            log.write(f"[b][yellow]── {pid}: {title} ──[/yellow][/b]")
            if "body" in e.data:
                log.write(f"   [dim]{_esc(e.data['body'])}[/dim]")
        elif e.type == "vote":
            v = e.data.get("vote", "?")
            vc = "green" if v == "aye" else "red" if v == "nay" else "yellow"
            note = f" — {_esc(e.data['note'])}" if e.data.get("note") else ""
            log.write(f"{actor}: [{vc}]{v}[/{vc}] on {_esc(e.data.get('proposal', '?'))}{note}")
        elif e.type == "second":
            log.write(f"{actor}: seconded {_esc(e.data.get('proposal', '?'))}")
        elif e.type == "commit":
            note = f" — {_esc(e.data.get('note', ''))}" if e.data.get("note") else ""
            log.write(f"[b][green]★ RATIFIED {_esc(e.data.get('proposal', '?'))}[/green][/b]{note}")
        elif e.type == "handoff":
            log.write(
                f"{actor} [magenta]→[/magenta] "
                f"{_esc(e.data.get('to','?'))}: {_esc(e.data.get('task',''))}"
            )
        elif e.type == "pass":
            note = f" — {_esc(e.data['note'])}" if e.data.get("note") else ""
            log.write(f"{actor}: [dim]⏸ pass{note}[/dim]")
        elif e.type == "close":
            reason = f" — {_esc(e.data.get('reason', ''))}" if e.data.get("reason") else ""
            log.write(f"{actor}: [bright_black]✂ CLOSED {_esc(e.data.get('proposal', '?'))}{reason}[/bright_black]")
        elif e.type == "reset":
            arc = _esc(e.data.get('archive', ''))
            log.write(f"[b][red]⚠ FORUM RESET[/red][/b] [dim]archived → {arc}[/dim]")

    def _update_tally(self) -> None:
        box = self.query_one("#tally-box", Static)
        pid = self.selected_pid
        if not pid:
            box.update("[dim](select a proposal)[/dim]")
            return
        t = self.ledger.get_tally(pid)
        q = self._quorum()
        n = len(self._voting_members())
        state = self.ledger.get_lifecycle_state(pid, q)
        sc = _STATE_COLORS.get(state, "white")
        lines = [
            f"[b]{pid}[/b]  [{sc}]{state}[/{sc}]",
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
            state = self.ledger.get_lifecycle_state(pid, q)
            c = _STATE_COLORS.get(state, "white")
            item = ListItem(Label(
                f"[{c}][b]{pid}[/b][/{c}] {p.data['title'][:18]} "
                f"[dim]{state.lower()}[/dim]"
            ))
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
        if self._tick_running:
            self.log_message("[dim]tick already in flight[/dim]")
            return
        self.run_worker(self.perform_tick, thread=True)

    def action_vote_aye(self) -> None:
        self._cast_vote("aye")

    def action_vote_nay(self) -> None:
        self._cast_vote("nay")

    def _commit_passing(self) -> list:
        """Recognize quorum: write commit entries for any open proposal at/over
        quorum. Main-thread variant logs directly; perform_tick has its own
        call_from_thread loop. Returns newly committed pids."""
        newly, held = self.ledger.commit_on_quorum(
            self._quorum(), unanimity_action=int(self.dials.get("unanimity_action", 1)))
        for pid in newly:
            t = self.ledger.get_tally(pid)
            self.log_message(
                f"[b][green]★ {pid} COMMITTED by quorum[/green][/b] [dim](aye={t['aye']})[/dim]"
            )
        for pid in held:
            self.log_message(
                f"[yellow]⚖ {pid} unanimous at quorum — held one round for a second reading[/yellow]"
            )
        self._scribe_async(newly)
        return newly

    # ── scribe (secretary duty) ───────────────────────────────────────────────

    def _scribe_capture_sync(self, pids: list) -> None:
        """Secretary duty: each ratified decision becomes a knowledge-base
        lesson via zdots-ctx add-lesson — the forum's minutes, durable beyond
        the ledger. ADR-shaped: the question, the alternatives that lost, and
        the dissent travel with the verdict, because a future hydrate that
        returns only the answer returns a 42. Blocking; worker thread only."""
        if not pids or not int(self.dials.get("scribe", 1)) or not self.kb.available():
            return
        for pid in pids:
            rec = self.ledger.get_decision_record(pid)
            # QUESTION/ALTERNATIVES extracted by the local model; the
            # deterministic record below still lands if it's unreachable.
            minute = ""
            try:
                recorder = ZsynodAgent("recorder", endpoint=self.args.endpoint)
                minute = recorder.minute(
                    pid, rec["title"],
                    self.ledger.get_proposal_discussion(pid),
                    rec["question"],
                )
            except Exception:
                pass
            content = format_decision_lesson(rec, minute)
            summary = self.ledger.get_latest_summary(pid) or ""
            if summary:
                content += f"\nSTATE: {summary}"
            ok = self.kb.record(content, context="zsynod decision",
                                tags=["zsynod", pid.lower()])
            self.call_from_thread(
                self.log_message,
                f"[dim]🖋 scribe → KB: {pid} recorded with question + dissent[/dim]" if ok
                else f"[yellow]🖋 scribe: KB write failed for {pid}[/yellow]",
            )

    def _scribe_async(self, pids: list) -> None:
        """Main-thread entry: hand the (subprocess-blocking) capture to a worker."""
        if pids:
            self.run_worker(lambda p=list(pids): self._scribe_capture_sync(p),
                            thread=True)

    def _herald_sync(self) -> None:
        """Herald duty (blocking; worker thread only): the deterministic fact
        sheet from the chain, narrated by the local model into a plain-English
        briefing — to the log and appended to zsynod/minutes.md so the
        principal can follow along without reading the ledger."""
        try:
            self.ledger.load()
            facts = self.ledger.get_herald_facts(self._quorum())
            if not facts:
                return
            herald = ZsynodAgent("herald", endpoint=self.args.endpoint)
            text = herald.herald(facts).strip()
            if not text:
                return
            stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
            self.call_from_thread(
                self.log_message,
                f"[b]📜 herald[/b] [dim]{stamp}[/dim]\n{text}",
            )
            minutes = self.args.ledger.parent / "minutes.md"
            with open(minutes, "a") as f:
                f.write(f"\n## {stamp}\n\n{text}\n")
        except Exception as e:
            self.call_from_thread(
                self.log_message, f"[dim]herald skipped: {e}[/dim]")

    def _kb_lookup(self, term: str) -> None:
        """Operator's reading desk: top knowledge-base hits for a term, inline
        in the log. Blocking; runs on a worker."""
        pool = self.kb.hydrate(term)
        items = (pool["methodologies"] + pool["lessons"])[:5]
        if not items:
            self.call_from_thread(
                self.log_message, f"[dim]📚 KB: nothing for “{term}”[/dim]")
            return
        self.call_from_thread(self.log_message, f"[b]📚 KB × “{term}”[/b]")
        for it in items:
            self.call_from_thread(
                self.log_message,
                f"  [dim]{KnowledgeBase._snippet(it, 160)}[/dim]")

    def action_second(self) -> None:
        if self.selected_pid:
            self.ledger.append("mike", "second", {"proposal": self.selected_pid})
            self.log_message(f"[green]mike:[/green] seconded {self.selected_pid}")
            self._commit_passing()
            self.refresh_data()

    def action_ratify(self) -> None:
        if self.selected_pid:
            self.ledger.append("mike", "commit", {
                "proposal": self.selected_pid, "by": "principal",
                "note": "ratified via cockpit",
            })
            self.log_message(f"[green]mike:[/green] [green]★ RATIFIED[/green] {self.selected_pid}")
            self._scribe_async([self.selected_pid])
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

    def action_control_plane(self) -> None:
        self.push_screen(ControlPlaneScreen())

    # ── auto-pilot ────────────────────────────────────────────────────────────

    def action_toggle_auto(self) -> None:
        self.auto_on = not self.auto_on
        if self.auto_on:
            self.auto_ticks_done = 0
            self._arm_auto_timer()
            self.log_message(
                f"[cyan]▶ auto-pilot engaged[/cyan] [dim]— tick after "
                f"{int(self.dials['auto_interval'])}s of silence, cap "
                f"{int(self.dials['auto_max_ticks'])} ticks; o to disengage[/dim]"
            )
        else:
            self.auto_deadline = None
            self.log_message("[cyan]⏸ auto-pilot off[/cyan]")
        self._update_timer_bar()

    def _arm_auto_timer(self) -> None:
        self.auto_deadline = time.monotonic() + float(self.dials["auto_interval"])

    @staticmethod
    def _countdown_bar(frac: float, cells: int = 16) -> str:
        filled = max(0, min(cells, round(frac * cells)))
        return "▰" * filled + "▱" * (cells - filled)

    def _update_timer_bar(self) -> None:
        """1 Hz heartbeat: every timer in the cockpit renders a countdown here —
        the agent's deliberation budget while a tick runs, the silence window
        while auto-pilot waits. Expiry of the silence window fires the tick."""
        bar = self.query_one("#timer-bar", Static)
        if self._tick_running:
            name, budget = self._agent_name, self._agent_budget
            if name and budget:
                remaining = max(0.0, budget - (time.monotonic() - self._agent_started))
                bar.update(
                    f"[yellow]⚙ tick[/yellow] @{name} deliberating "
                    f"{self._countdown_bar(remaining / budget)} "
                    f"[dim]{remaining:>3.0f}s budget[/dim]"
                )
            else:
                bar.update("[yellow]⚙ tick running…[/yellow]")
            return
        if not self.auto_on:
            bar.update("[dim]auto-pilot off — o engages multi-tick runs[/dim]")
            return
        if self.auto_deadline is None:
            self._arm_auto_timer()
        remaining = max(0.0, self.auto_deadline - time.monotonic())
        total = float(self.dials["auto_interval"]) or 1.0
        cap = int(self.dials["auto_max_ticks"])
        bar.update(
            f"[cyan]▶ auto[/cyan] next tick {self._countdown_bar(remaining / total)} "
            f"[b]{remaining:>3.0f}s[/b] [dim]silence · {self.auto_ticks_done}/{cap} ticks[/dim]"
        )
        if remaining <= 0:
            self._fire_auto_tick()

    def _fire_auto_tick(self) -> None:
        cap = int(self.dials["auto_max_ticks"])
        if self.auto_ticks_done >= cap:
            self.auto_on = False
            self.auto_deadline = None
            self.log_message(
                f"[cyan]⏸ auto-pilot paused[/cyan] [dim]— {cap}-tick cap "
                f"reached; o to re-engage[/dim]"
            )
            return
        self.auto_ticks_done += 1
        self.auto_deadline = None  # re-armed once the tick's entries land
        self.log_message(
            f"[cyan]▶ auto-tick {self.auto_ticks_done}/{cap}[/cyan] "
            f"[dim]— {int(self.dials['auto_interval'])}s of silence[/dim]"
        )
        self.action_tick()

    def _cast_vote(self, vote: str) -> None:
        pid = self.selected_pid
        if not pid:
            self.log_message("[yellow]select a proposal first[/yellow]")
            return
        self.ledger.append("mike", "vote", {"proposal": pid, "vote": vote, "note": "via cockpit"})
        vc = "green" if vote == "aye" else "red"
        self.log_message(f"[green]mike:[/green] [{vc}]{vote}[/{vc}] on {pid}")
        self._commit_passing()
        self.refresh_data()

    # ── tick ──────────────────────────────────────────────────────────────────

    def _apply_directives(self, actor: str, directives: list,
                          open_pids: set, members: list,
                          topic_pid: str = None) -> None:
        """Semantic gate for parsed agent directives: a vote/second must target
        an open proposal, a handoff must name a seated member. Accepted
        directives become real ledger entries; rejected ones are logged so the
        bad reference is visible to the operator (and to the agent next tick,
        via its stripped remark having vanished)."""
        for dtype, data in directives:
            if dtype == "pass":
                if topic_pid:
                    data = {**data, "proposal": topic_pid}
                self.ledger.append(actor, "pass", data)
                continue
            err = None
            if dtype in ("vote", "second") and data["proposal"] not in open_pids:
                err = f"no open proposal {data['proposal']}"
            elif dtype == "handoff" and data["to"] not in members:
                err = f"no member @{data['to']}"
            if dtype == "propose":
                # Dedup gate against ALL history: the ledger grew 50+
                # near-identical proposals because agents can't see that a
                # twin already exists (or was just closed). Identical title =
                # identical proposal; a true revision needs a new title.
                norm = re.sub(r"\W+", "", data["title"]).lower()
                dup = next(
                    (e.data["id"] for e in self.ledger.entries
                     if e.type == "propose"
                     and re.sub(r"\W+", "", e.data.get("title", "")).lower() == norm),
                    None,
                )
                if dup:
                    err = f"duplicate of {dup} — vote on it or retitle the revision"
            if err:
                self.call_from_thread(
                    self.log_message,
                    f"[yellow]⚠ {actor} directive dropped:[/yellow] [dim]{dtype} — {err}[/dim]",
                )
                continue
            if dtype == "propose":
                data = {"id": self.ledger.next_proposal_id(), "title": data["title"]}
                open_pids.add(data["id"])
            self.ledger.append(actor, dtype, data)

    def perform_tick(self) -> None:
        self._tick_running = True
        try:
            self._tick_inner()
        finally:
            self._tick_running = False
            self._agent_name = None
            # Quiet tick (all muted/backed off) appends nothing, so
            # refresh_data won't re-arm — do it here or auto-pilot stalls.
            if self.auto_on and self.auto_deadline is None:
                self.call_from_thread(self._arm_auto_timer)

    def _tick_inner(self) -> None:
        with self.tracer.start_as_current_span("deliberation_tick") as span:
            proposals = self.ledger.get_proposals()
            open_pids = {p.data["id"] for p in proposals}
            # Operator focus pins every member to one topic; otherwise each
            # member gets its own event-driven topic from the scheduler.
            forced_pid = self.selected_pid if self.selected_pid in open_pids else None
            span.set_attribute("zsynod.topic", forced_pid or "scheduled")

            glyph = tick_seed()
            trend = self.ledger.get_trend_preamble()
            self.call_from_thread(
                self.log_message,
                f"[dim]── {glyph}  {trend} ──[/dim]" if trend else f"[dim]── {glyph} ──[/dim]",
            )

            members = self._all_members()
            q = self._quorum()
            touched: list = []
            # Re-read every tick so dial turns (TUI screen or hand-edit of
            # dials.json) land without a restart.
            dials = load_dials(self.dials_path)
            self.dials = dials

            import subprocess
            active = 0
            for agent in self.agents:
                actor = agent.actor_id
                breaker = self.breakers[actor]

                if actor in dials["muted"]:
                    self.call_from_thread(
                        self.log_message, f"[dim]🔇 {actor}: muted[/dim]",
                    )
                    continue

                if not breaker.is_ready():
                    self.call_from_thread(
                        self.log_message,
                        f"[dim]⏭ {actor}: {breaker.skip_label()}[/dim]",
                    )
                    continue

                if forced_pid:
                    a_pid = forced_pid
                    event = self.ledger.topic_event(actor, a_pid, q)
                else:
                    event, a_pid = self.ledger.next_event(
                        actor, q,
                        spontaneity=dials["spontaneity"],
                        loop_threshold=dials["loop_threshold"],
                        loop_window=int(dials["loop_window"]),
                    )
                # 📚 KB dispatch: some free thoughts arrive carrying a morsel
                # from the zdots knowledge base — the forum's outside world.
                # The member must weigh it against the platform, not the chat.
                if "free thought" in event and random.random() < dials["kb_dispatch"]:
                    morsel = self.kb.seed()
                    if morsel:
                        event = (f"📚 from the zdots knowledge base: “{morsel}” "
                                 f"— weigh it against zdots as it runs today; "
                                 f"surface one concrete improvement")
                # 💭/📚 turns get a light context anchor — a heavy quote of the
                # recent thread would just re-seed the rut they're escaping.
                free_thought = event.startswith(("💭", "📚"))
                topic = ("Open floor" if free_thought
                         else self.ledger.get_title(a_pid) if a_pid
                         else "General status")
                summary = self.ledger.get_latest_summary(a_pid) if a_pid else ""
                # Topic turns get grounded: the most relevant KB snippet is
                # pinned as a [KB] line so positions cite the platform's own
                # accumulated knowledge, not just each other.
                kb_note = (self.kb.ground(topic) or "") if (a_pid and not free_thought) else ""
                # Honest votes: members who haven't voted yet argue blind
                # (no tally, no others' votes — the [STATE] pin carries the
                # scoreboard, so it is withheld too), and one rotating seat
                # per proposal owes the forum the case against.
                blind = advocate = False
                if a_pid and not free_thought:
                    t_now = self.ledger.get_tally(a_pid)
                    blind = bool(int(dials.get("blind_votes", 1))) and actor not in t_now["votes"]
                    advocate = (bool(int(dials.get("advocate", 1)))
                                and devils_advocate(a_pid, [ag.actor_id for ag in self.agents]) == actor)
                if blind:
                    summary = ""
                if advocate:
                    self.call_from_thread(
                        self.log_message,
                        f"[dim]😈 {actor} holds the advocate seat for {a_pid}[/dim]",
                    )
                context = (self.ledger.get_proposal_discussion(a_pid) if a_pid
                           else self.ledger.get_discussion(
                               limit=12 if free_thought else 200))
                if event:
                    self.call_from_thread(
                        self.log_message, f"[dim]{actor} ⚡ {event}[/dim]",
                    )

                active += 1
                self.current_thought = ""
                self._agent_name = actor
                self._agent_budget = breaker.current_timeout()
                self._agent_started = time.monotonic()

                def token_cb(token, a=actor):
                    self.call_from_thread(self.update_thinking, token, a)

                def suggestion_cb(s, a=actor):
                    self.call_from_thread(
                        self.log_message,
                        f"[dim]nudge ({a}): {s}[/dim]",
                    )

                try:
                    remark = agent.deliberate(
                        topic, context,
                        progress_callback=self.log_message,
                        token_callback=token_cb,
                        suggestion_callback=suggestion_cb,
                        glyph=glyph,
                        timeout=breaker.current_timeout(),
                        members=members,
                        summary=summary,
                        trend=trend,
                        event=event,
                        temperature=dials["temperature"],
                        max_tokens=int(dials["max_tokens"]),
                        context_depth=int(dials["context_depth"]),
                        kb_note=kb_note,
                        blind=blind,
                        advocate=advocate,
                    )
                    breaker.record_success()
                    speech, directives = parse_directives(remark)
                    if speech:
                        data = {"remark": speech}
                        if a_pid:
                            data["proposal"] = a_pid
                        self.ledger.append(actor, "speak", data)
                    self._apply_directives(actor, directives, open_pids, members, a_pid)
                    if a_pid and a_pid not in touched:
                        touched.append(a_pid)
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
                    self._agent_name = None
                    self.call_from_thread(self._clear_thinking)

            if active == 0:
                self.call_from_thread(
                    self.log_message,
                    "[dim]── all agents backed off; wheel rolls on ──[/dim]",
                )

            # ── quorum recognition ────────────────────────────────────────────
            # Votes cast this tick may have pushed a proposal to quorum.
            # Recognize it now or the topic gets re-litigated forever.
            committed, held = self.ledger.commit_on_quorum(
                self._quorum(),
                unanimity_action=int(dials.get("unanimity_action", 1)))
            for cpid in committed:
                t = self.ledger.get_tally(cpid)
                self.call_from_thread(
                    self.log_message,
                    f"[b][green]★ {cpid} COMMITTED by quorum[/green][/b] [dim](aye={t['aye']})[/dim]",
                )
            for hpid in held:
                self.call_from_thread(
                    self.log_message,
                    f"[yellow]⚖ {hpid} unanimous at quorum — held one round "
                    f"for a second reading[/yellow]",
                )
            # Already on a worker thread — the scribe writes minutes inline.
            self._scribe_capture_sync(committed)

            # ── summarizer pass ───────────────────────────────────────────────
            # After all voices have spoken, write a compact state summary for
            # each topic touched this tick (capped — local model, sequential).
            # Next tick reads them as pinned [STATE] context.
            for s_pid in touched[:3]:
                try:
                    self.ledger.load()
                    prop_discussion = self.ledger.get_proposal_discussion(s_pid)
                    tally = self.ledger.get_tally(s_pid)
                    title = self.ledger.get_title(s_pid)
                    summarizer = ZsynodAgent("summarizer", endpoint=self.args.endpoint)
                    text = summarizer.summarize(s_pid, title, prop_discussion, tally)
                    self.ledger.append("summarizer", "summary", {"proposal": s_pid, "text": text})
                    self.call_from_thread(
                        self.log_message,
                        f"[dim]📋 {s_pid} state: {text[:80]}{'…' if len(text) > 80 else ''}[/dim]",
                    )
                except Exception as e:
                    self.call_from_thread(
                        self.log_message,
                        f"[dim]summarizer skipped ({s_pid}): {e}[/dim]",
                    )

            # ── herald pass ───────────────────────────────────────────────────
            # Every digest_every ticks the local model briefs the principal in
            # plain English — the humane view of who is pushing what.
            self._ticks_total += 1
            d_every = int(dials.get("digest_every", 0))
            if d_every and self._ticks_total % d_every == 0:
                self._herald_sync()

    # ── polling refresh ────────────────────────────────────────────────────────

    def refresh_data(self) -> None:
        self.ledger.load()
        # No new entries → nothing to redraw. Without this gate the 3s poll
        # clears and rewrites the sidebar and thread view every cycle (flicker).
        top_seq = self.ledger.entries[-1].seq if self.ledger.entries else -1
        if top_seq == getattr(self, "_last_refresh_seq", None):
            return
        self._last_refresh_seq = top_seq
        # Every message resets the silence window — the forum only auto-ticks
        # once the conversation has genuinely gone quiet.
        if getattr(self, "auto_on", False) and not self._tick_running:
            self._arm_auto_timer()
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
                    self._commit_passing()
                elif action == "ratify":
                    pid = rest.upper() if rest else self.selected_pid
                    if not pid:
                        self.log_message("[yellow]no proposal selected[/yellow]")
                        return
                    self.ledger.append("mike", "commit", {"proposal": pid, "by": "principal", "note": "ratified via cockpit"})
                    self.log_message(f"[green]mike:[/green] [green]★ RATIFIED[/green] {pid}")
                    self._scribe_async([pid])
                elif action == "close":
                    bits = rest.split(maxsplit=1)
                    pid = bits[0].upper() if bits else self.selected_pid
                    if not pid:
                        self.log_message("[yellow]no proposal selected[/yellow]")
                        return
                    reason = bits[1] if len(bits) > 1 else "closed via cockpit"
                    self.ledger.append("mike", "close", {"proposal": pid, "reason": reason, "by": "principal"})
                    self.log_message(f"[green]mike:[/green] [bright_black]✂ CLOSED {pid}[/bright_black] — {reason}")
                elif action == "reset":
                    if rest.strip().lower() != "confirm":
                        self.log_message(
                            "[yellow]⚠ This archives the ledger and clears all proposals.[/yellow]\n"
                            "[yellow]Type [b]reset confirm[/b] to proceed.[/yellow]"
                        )
                        return
                    arc = self.ledger.reset()
                    self.last_seen_seq = -1
                    self.selected_pid = None
                    self.log_message(f"[green]✓ Ledger archived → {_esc(arc.name)}[/green]")
                    self.log_message("[yellow]Forum reset. Start fresh with 'propose <title>'.[/yellow]")
                    self.refresh_data()
                elif action == "dial":
                    bits = rest.split()
                    if not bits:
                        knobs = "  ".join(f"{k}={self.dials[k]}" for k in DIALS)
                        muted = " ".join(self.dials["muted"]) or "(none)"
                        self.log_message(f"[dim]🎛 {knobs}  muted: {muted}[/dim]")
                        return
                    if len(bits) != 2 or bits[0] not in DIALS:
                        self.log_message(
                            f"[yellow]usage: dial <{('|'.join(DIALS))}> <value>[/yellow]")
                        return
                    spec = DIALS[bits[0]]
                    try:
                        v = float(bits[1])
                    except ValueError:
                        self.log_message(f"[red]not a number: {bits[1]}[/red]")
                        return
                    v = min(max(v, spec["min"]), spec["max"])
                    self.dials[bits[0]] = int(v) if isinstance(spec["default"], int) else v
                    save_dials(self.dials_path, self.dials)
                    self.log_message(f"🎛 [cyan]{bits[0]}[/cyan] = {self.dials[bits[0]]}")
                    return
                elif action in ("mute", "unmute"):
                    m = rest.strip().lstrip("@")
                    if not m or m not in self._all_members():
                        self.log_message(f"[yellow]no member @{m or '?'}[/yellow]")
                        return
                    muted = self.dials["muted"]
                    if action == "mute" and m not in muted:
                        muted.append(m)
                    elif action == "unmute" and m in muted:
                        muted.remove(m)
                    save_dials(self.dials_path, self.dials)
                    icon = "🔇" if m in muted else "🔊"
                    self.log_message(f"{icon} @{m} {'muted' if m in muted else 'live'}")
                    return
                elif action == "auto":
                    arg = rest.strip().lower()
                    if arg in ("off", "stop"):
                        if self.auto_on:
                            self.action_toggle_auto()
                        return
                    if arg and arg not in ("on", "start"):
                        try:
                            v = float(arg)
                        except ValueError:
                            self.log_message("[yellow]usage: auto [on|off|<seconds>][/yellow]")
                            return
                        spec = DIALS["auto_interval"]
                        self.dials["auto_interval"] = int(min(max(v, spec["min"]), spec["max"]))
                        save_dials(self.dials_path, self.dials)
                        self.log_message(f"🎛 [cyan]auto_interval[/cyan] = {self.dials['auto_interval']}s")
                    if not self.auto_on:
                        self.action_toggle_auto()
                    else:
                        self._arm_auto_timer()
                    return
                elif action == "kb":
                    if not rest:
                        self.log_message("[yellow]usage: kb <term>[/yellow]")
                        return
                    self.run_worker(lambda term=rest: self._kb_lookup(term), thread=True)
                    return
                elif action == "digest":
                    self.log_message("[dim]📜 herald summoned…[/dim]")
                    self.run_worker(self._herald_sync, thread=True)
                    return
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
    # The pawl: walk the chain before the cockpit opens. A forum must not
    # deliberate on a ledger it cannot trust — die at the door, by name.
    try:
        LedgerManager(args.ledger)
    except LedgerIntegrityError as e:
        print(f"Error: ledger integrity check failed — {e}")
        print("The chain is append-only; restore the ledger from backup or "
              "investigate the altered entry before reconvening.")
        sys.exit(1)
    app = ZsynodApp()
    app.args = args
    app.run()
