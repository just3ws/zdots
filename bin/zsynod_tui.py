import json
import os
import random
import shutil
import sys
import argparse
from pathlib import Path
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, RichLog, Input, ListView, ListItem, Label
from textual.containers import Container, Horizontal, Vertical
from textual.binding import Binding
from textual.reactive import reactive

sys.path.append(str(Path(__file__).parent.parent / "lib"))
from zsynod_core import LedgerManager, ZsynodAgent, tick_seed
from zsynod_otel import setup_otel

_MEMBERS_PATH = Path(__file__).parent.parent / "zsynod" / "members.json"


class ZsynodApp(App):
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
        Binding("q",     "quit",        "Quit",    show=True),
        Binding("t",     "tick",        "Tick",    show=True),
        Binding("a",     "vote_aye",    "Aye",     show=True),
        Binding("n",     "vote_nay",    "Nay",     show=True),
        Binding("s",     "second",      "Second",  show=True),
        Binding("r",     "ratify",      "Ratify",  show=True),
        Binding("slash", "toggle_view", "All/Prop",show=True),
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

    def _render_entry(self, log: RichLog, e) -> None:
        ac = "green" if e.actor == "mike" else "cyan"
        actor = f"[{ac}]{e.actor}[/{ac}]"
        if e.type in ["speak", "discuss"]:
            log.write(f"{actor}: {e.data.get('remark', '')}")
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

            for agent in self.agents:
                self.current_thought = ""
                actor = agent.actor_id

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
                    )
                    self.ledger.append(actor, "speak", {"remark": remark})
                    discussion = self.ledger.get_discussion(limit=200)
                except Exception as e:
                    self.call_from_thread(
                        self.log_message,
                        f"[yellow]⚠ {actor} skipped:[/yellow] [dim]{e}[/dim]",
                    )
                finally:
                    self.call_from_thread(self._clear_thinking)

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
