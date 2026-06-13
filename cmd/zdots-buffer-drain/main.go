// zdots-buffer-drain — drain Redis command buffer to SQLite.
//
// Bridges Redis and SQLite for cmd-analytics: polls Redis for session buffers
// (zdots:cmds:*), parses JSON entries, inserts into SQLite with deduplication,
// and deletes the Redis key after confirmed writes.
//
// Usage:
//   zdots-buffer-drain [--db-path <path>] [--redis-host <h>] [--redis-port <p>] [--dry-run]
//
// Exit codes:
//   0 = success (rows drained, or nothing to drain)
//   1 = error (Redis unavailable, SQLite write failed, etc.)
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"zdots/cmd/zdots-buffer-drain/internal/drain"
)

func main() {
	dbPath := flag.String("db-path", "", "path to history.sqlite3 (default: $XDG_STATE_HOME/zdots/history.sqlite3)")
	redisHost := flag.String("redis-host", "127.0.0.1", "Redis host")
	redisPort := flag.String("redis-port", "6379", "Redis port")
	dryRun := flag.Bool("dry-run", false, "report what would be drained, write nothing")
	flag.Parse()

	ctx := context.Background()

	// Determine database path
	if *dbPath == "" {
		xdgState := os.Getenv("XDG_STATE_HOME")
		if xdgState == "" {
			home, err := os.UserHomeDir()
			if err != nil {
				fmt.Fprintf(os.Stderr, "zdots-buffer-drain: failed to determine home directory: %v\n", err)
				os.Exit(1)
			}
			xdgState = filepath.Join(home, ".local", "state")
		}
		*dbPath = filepath.Join(xdgState, "zdots", "history.sqlite3")
	}

	// Create drainer
	drainer := drain.New(
		drain.WithDBPath(*dbPath),
		drain.WithRedisAddr(*redisHost + ":" + *redisPort),
		drain.WithDryRun(*dryRun),
	)

	// Execute drain
	result, err := drainer.Drain(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-buffer-drain: %v\n", err)
		os.Exit(1)
	}

	// Output result as JSON for shell integration
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		fmt.Fprintf(os.Stderr, "zdots-buffer-drain: failed to write output: %v\n", err)
		os.Exit(1)
	}

	if result.Errors > 0 {
		os.Exit(1)
	}
	os.Exit(0)
}
