import sys
import argparse
from pathlib import Path
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, RichLog, Input
from textual.containers import Container, Horizontal, Vertical
from textual.binding import Binding
from rich.text import Text

# Ensure lib/ is in the path
sys.path.append(str(Path(__file__).parent.parent / "lib"))
from zsynod_core import LedgerManager, ZsynodAgent
from zsynod_otel import setup_otel

class ZsynodApp(App):
    """A Textual TUI for zsynod deliberation and facilitation."""

    CSS = """
    Screen { layers: base; }
    #main-container { height: 1fr; }
    #sidebar {
        width: 35;
        background: $panel;
        border-left: solid $primary;
        padding: 1;
    }
    #log-container { height: 1fr; border: solid $accent; }
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
    .status-item { margin-bottom: 1; padding: 0 1; }
    .blocking { color: $warning; }
    """

    BINDINGS = [
        Binding("q", "quit", "Quit", show=True),
        Binding("r", "refresh", "Refresh", show=True),
        Binding("t", "tick", "Tick (Deliberate)", show=True),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        with Container(id="main-container"):
            with Horizontal():
                with Vertical(id="log-container"):
                    yield RichLog(id="discussion-log", highlight=True, markup=True)
                    yield Static(id="thinking-box")
                with Vertical(id="sidebar"):
                    yield Static("[b]OPEN PROPOSALS[/b]", classes="status-item")
                    yield Static(id="proposal-list", classes="status-item")
                    yield Static("\n[b]AWAITING YOU[/b]", classes="status-item")
                    yield Static(id="blocking-list", classes="status-item")
        yield Input(placeholder="Enter command (aye/nay/ratify/tick)...", id="command-input")
        yield Footer()

    def on_mount(self) -> None:
        self.tracer = setup_otel("zsynod-py-tui")
        self.ledger = LedgerManager(self.args.ledger)
        self.agent = ZsynodAgent("pi", endpoint=self.args.endpoint)
        self.last_seen_seq = -1
        self.current_thought = ""

        self.log_message(f"Welcome to [b][cyan]Zsynod-Py[/cyan][/b] Cockpit.")
        self.log_message(f"[dim]Endpoint: {self.agent.endpoint}[/dim]")
        self.refresh_data()
        self.set_interval(3.0, self.refresh_data) # Faster polling for live feel

    def log_message(self, message: str) -> None:
        self.query_one("#discussion-log", RichLog).write(message)

    def action_tick(self) -> None:
        self.run_worker(self.perform_tick, thread=True)

    def update_thinking(self, token: str) -> None:
        self.current_thought += token
        box = self.query_one("#thinking-box", Static)
        box.display = True
        box.update(f"[i]pi thinking:[/i] {self.current_thought}█")

    def perform_tick(self) -> None:
        with self.tracer.start_as_current_span("deliberation_tick") as span:
            self.current_thought = ""
            discussion = self.ledger.get_discussion(limit=200)
            proposals = self.ledger.get_proposals()
            topic = proposals[0].data["title"] if proposals else "General status"
            
            span.set_attribute("zsynod.topic", topic)
            
            # Use call_from_thread to safely update the UI from the background worker
            def token_cb(token):
                self.call_from_thread(self.update_thinking, token)

            remark = self.agent.deliberate(
                topic, 
                discussion, 
                progress_callback=self.log_message,
                token_callback=token_cb
            )
            
            # Clear thinking box
            def finalize():
                box = self.query_one("#thinking-box", Static)
                box.display = False
                box.update("")
            
            self.call_from_thread(finalize)
            self.ledger.append("pi", "speak", {"remark": remark})

    def refresh_data(self) -> None:
        self.ledger.load()
        
        # Update Discussion Log (only new entries)
        discussion = self.ledger.get_discussion(limit=200)
        for entry in discussion:
            if entry.seq > self.last_seen_seq:
                actor_color = "green" if entry.actor == "mike" else "cyan"
                actor = f"[{actor_color}]{entry.actor}[/{actor_color}]"
                
                if entry.type in ["speak", "discuss"]:
                    self.log_message(f"{actor}: {entry.data['remark']}")
                
                elif entry.type == "propose":
                    self.log_message(f"--- [b][yellow]PROPOSAL {entry.data['id']}[/yellow][/b] ---")
                    self.log_message(f"{actor}: [b]{entry.data['title']}[/b]")
                    if "body" in entry.data:
                        self.log_message(f"    [dim]{entry.data['body']}[/dim]")
                
                elif entry.type == "vote":
                    v = entry.data['vote']
                    v_color = "green" if v == "aye" else "red" if v == "nay" else "yellow"
                    self.log_message(f"{actor}: voted [{v_color}]{v}[/{v_color}] on {entry.data['proposal']}")
                
                elif entry.type == "commit":
                    self.log_message(f"*** [b][red]RATIFIED {entry.data['proposal']}[/red][/b] ***")
                    if "note" in entry.data:
                        self.log_message(f"    [dim]{entry.data['note']}[/dim]")
                
                elif entry.type == "handoff":
                    self.log_message(f"{actor} [magenta]HANDOFF[/magenta] -> {entry.data['to']}: {entry.data['task']}")

                self.last_seen_seq = entry.seq
        proposals = self.ledger.get_proposals()
        prop_text = "\n".join([f"• [b]{p.data['id']}[/b]: {p.data['title']}" for p in proposals]) or "[dim]None[/dim]"
        self.query_one("#proposal-list", Static).update(prop_text)

        blocking = self.ledger.get_blocking_items()
        block_text = "\n".join([f"⚠ [yellow]{b['id']}[/yellow]: {b['label']}" for b in blocking]) or "[dim]Nothing[/dim]"
        self.query_one("#blocking-list", Static).update(block_text)

    def on_input_submitted(self, event: Input.Submitted) -> None:
        cmd_text = event.value.strip()
        if not cmd_text:
            return

        parts = cmd_text.split()
        action = parts[0].lower()
        args = parts[1:]

        try:
            with self.tracer.start_as_current_span(f"cmd_{action}"):
                if action in ["aye", "nay"]:
                    proposals = self.ledger.get_proposals()
                    pid = args[0].upper() if args else (proposals[0].data["id"] if proposals else None)
                    if not pid:
                        self.log_message("[red]Error:[/red] No open proposals to vote on.")
                    else:
                        self.ledger.append("mike", "vote", {"proposal": pid, "vote": action, "note": "via cockpit"})
                        self.log_message(f"[b][green]mike:[/green][/b] voted {action} on {pid}")

                elif action == "ratify":
                    if not args:
                        self.log_message("[red]Error:[/red] ratify requires a proposal ID")
                    else:
                        pid = args[0].upper()
                        self.ledger.append("mike", "commit", {"proposal": pid, "by": "principal", "note": "ratified via cockpit"})
                        self.log_message(f"[b][green]mike:[/green][/b] [red]RATIFIED[/red] {pid}")

                elif action == "tick":
                    self.action_tick()

                else:
                    self.ledger.append("mike", "speak", {"remark": cmd_text})

            self.query_one("#command-input").value = ""
            self.refresh_data()

        except Exception as e:
            self.log_message(f"[red]Error:[/red] {str(e)}")

def parse_args():
    parser = argparse.ArgumentParser(
        description="Zsynod Facilitator Cockpit - A real-time TUI for AI-human deliberation.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        "--ledger", 
        type=Path, 
        default=Path.home() / ".config" / "zsh" / "zsynod" / "ledger.py.jsonl",
        help="Path to the Pydantic-native ledger file"
    )
    parser.add_argument(
        "--endpoint",
        type=str,
        default=None,
        help="llama.cpp endpoint base URL (default: $ZDOTS_AI_ENDPOINT or http://127.0.0.1:11500)"
    )
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_args()
    if not args.ledger.exists():
        print(f"Error: Ledger not found at {args.ledger}. Run 'zsynod-migrate' first.")
        sys.exit(1)
        
    app = ZsynodApp()
    app.args = args # Pass args to the app
    app.run()
