// zdots-phi-scrub — canonical PHI/credential scrubber for zdots.
//
// Loads the single registry (etc/phi-patterns.yaml) and provides:
//
//	zdots-phi-scrub          stdin → redacted stdout (exit 0 on success)
//	                         exit 2 if input matches a suppress-flagged pattern (fail hard, no output)
//	                         exit 1 on operational error (registry load / stdin read failure)
//
//	zdots-phi-scrub --check  take argument on command line
//	                         exit 0 if input matches a suppress pattern
//	                         exit 1 if not
//
//	zdots-phi-scrub --init   preload and validate the registry
//	                         exit 0 if successful, exit 1 if registry is missing or invalid
//
// OTEL observability:
//   - Emit spans for suppress-match events (audit-critical)
//   - Emit metrics for redact operations (counters only, no per-call spans)
//   - Gracefully degrade if collector is unreachable
package main

import (
	"bufio"
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"strconv"
	"sync/atomic"
	"time"
	"zdots/cmd/zdots-phi-scrub/internal/otel"
	"zdots/cmd/zdots-phi-scrub/internal/phi"
)

func main() {
	// Parse flags
	checkFlag := flag.Bool("check", false, "suppress pattern check mode: exit 0 if stdin matches a suppress pattern")
	initFlag := flag.Bool("init", false, "preload and validate the registry")
	serveFlag := flag.Bool("serve", false, "resident mode (Z-283): NUL-framed request/response loop on stdio; one registry load per process")
	flag.Parse()

	// Initialize observability (gracefully degrades if collector is unreachable)
	ctx := context.Background()
	tp, err := otel.InitTracer(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to initialize OTEL tracer: %v\n", err)
		// Continue without observability
	}
	defer func() {
		if tp != nil {
			_ = tp.Shutdown(ctx)
		}
	}()

	// Load and compile the pattern registry
	registry, err := phi.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-phi-scrub: %v\n", err)
		os.Exit(1)
	}

	// Handle --init flag: just validate and report
	if *initFlag {
		redactCount, suppressCount := registry.PatternCount()
		fmt.Fprintf(os.Stderr, "zdots-phi-scrub: OK — %d redact + %d suppress pattern(s) compile in RE2\n",
			redactCount, suppressCount)
		os.Exit(0)
	}

	// Resident server mode (Z-283): the shell hook keeps one process per shell
	// instead of one spawn per command (measured 7-29ms/command). Protocol:
	// request = <raw bytes>NUL; response = <status byte '0'|'2'><payload>NUL,
	// where '0' payload is the redacted line and '2' payload is empty
	// (suppress-match). Operational errors are impossible per-request once the
	// registry is loaded; a dead/unresponsive server is the shell's cue to
	// fall back to one-shot spawn. Exits quietly on EOF or idle timeout so
	// abandoned shells do not hold memory.
	if *serveFlag {
		serve(ctx, registry, tp)
		return
	}

	// Read input from stdin
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-phi-scrub: failed to read stdin: %v\n", err)
		os.Exit(1)
	}

	// Handle --check flag: suppress pattern predicate
	if *checkFlag {
		if registry.IsSuppressed(input) {
			os.Exit(0)
		}
		os.Exit(1)
	}

	// Default mode: redact (stdin → stdout)
	// Check for suppress-flagged patterns first; fail hard if found.
	// Exit 2 (distinct from the exit-1 operational errors above) lets callers
	// distinguish a deliberate suppress-match from a binary failure in a single
	// invocation — no separate --check pre-pass needed.
	if registry.IsSuppressed(input) {
		fmt.Fprintf(os.Stderr, "zdots-phi-scrub: suppress-flagged pattern in input — refusing to process\n")
		// Emit OTEL span for audit trail
		if tp != nil && !tp.Disabled() {
			tp.EmitSuppressMatch(ctx, "suppress_match")
		}
		os.Exit(2)
	}

	// Apply redaction patterns
	redacted := registry.Scrub(input)
	os.Stdout.Write(redacted)
	os.Exit(0)
}

// serve implements the resident request loop. Idle timeout (default 300s,
// ZDOTS_PHI_SERVE_IDLE seconds) is enforced by an activity timer — a read
// deadline on fd 0 is not poller-backed for inherited pipes, so a watchdog
// goroutine exits the process when no request has arrived for a full idle
// window. An idle shell's scrubber exits and is lazily respawned on the next
// command.
func serve(ctx context.Context, registry *phi.Compiled, tp *otel.TracerProvider) {
	idle := 300 * time.Second
	if v := os.Getenv("ZDOTS_PHI_SERVE_IDLE"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			idle = time.Duration(n) * time.Second
		}
	}

	var lastActivity atomic.Int64
	lastActivity.Store(time.Now().UnixNano())
	go func() {
		tick := time.NewTicker(idle / 4)
		defer tick.Stop()
		for range tick.C {
			if time.Since(time.Unix(0, lastActivity.Load())) >= idle {
				os.Exit(0) // idle: shell hook respawns on next command
			}
		}
	}()

	r := bufio.NewReader(os.Stdin)
	w := bufio.NewWriter(os.Stdout)
	for {
		req, err := r.ReadBytes(0)
		if err != nil {
			// EOF (shell closed) or hard error — exit quietly; the shell hook
			// detects death and falls back to one-shot spawn.
			if !errors.Is(err, io.EOF) {
				fmt.Fprintf(os.Stderr, "zdots-phi-scrub: serve: %v\n", err)
			}
			return
		}
		lastActivity.Store(time.Now().UnixNano())
		req = req[:len(req)-1] // strip framing NUL

		if registry.IsSuppressed(req) {
			w.WriteByte('2')
			w.WriteByte(0)
			_ = w.Flush()
			if tp != nil && !tp.Disabled() {
				tp.EmitSuppressMatch(ctx, "suppress_match")
			}
			continue
		}

		w.WriteByte('0')
		w.Write(registry.Scrub(req))
		w.WriteByte(0)
		if err := w.Flush(); err != nil {
			return // reader gone — shell will respawn or fall back
		}
	}
}
