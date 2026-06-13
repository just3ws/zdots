// zdots-phi-scrub — canonical PHI/credential scrubber for zdots.
//
// Loads the single registry (etc/phi-patterns.yaml) and provides:
//
//	zdots-phi-scrub          stdin → redacted stdout (exit 0 on success)
//	                         exit 1 if input matches a suppress-flagged pattern (fail hard, no output)
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
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"zdots/cmd/zdots-phi-scrub/internal/otel"
	"zdots/cmd/zdots-phi-scrub/internal/phi"
)

func main() {
	// Parse flags
	checkFlag := flag.Bool("check", false, "suppress pattern check mode: exit 0 if stdin matches a suppress pattern")
	initFlag := flag.Bool("init", false, "preload and validate the registry")
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
	// Check for suppress-flagged patterns first; fail hard if found
	if registry.IsSuppressed(input) {
		fmt.Fprintf(os.Stderr, "zdots-phi-scrub: suppress-flagged pattern in input — refusing to process\n")
		// Emit OTEL span for audit trail
		if tp != nil && !tp.Disabled() {
			tp.EmitSuppressMatch(ctx, "suppress_match")
		}
		os.Exit(1)
	}

	// Apply redaction patterns
	redacted := registry.Scrub(input)
	os.Stdout.Write(redacted)
	os.Exit(0)
}
