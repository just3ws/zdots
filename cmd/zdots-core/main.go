package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/agentguide"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/capabilities"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/status"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/storage"
)

func usage() {
	fmt.Print(`Usage: zdots-core <applet> [args...]

Multicall Go binary for performance-critical zdots platform commands.
Invoke via symlink (e.g. capabilities) or directly as: zdots-core <applet>.

Applets:
  agent-guide     Live service status and usage guidance for AI agents
  capabilities    Environment health and service contract validator
  zdots-status    Live TUI dashboard for Zdots platform health
  zdots-storage   Multi-bucket system storage monitoring & budget attestation

Options:
  -h, --help      Show this help
`)
}

func main() {
	invoked := filepath.Base(os.Args[0])
	switch invoked {
	case "agent-guide":
		os.Exit(agentguide.Run(os.Args[1:]))
	case "capabilities":
		os.Exit(capabilities.Run(os.Args[1:]))
	case "zdots-status":
		os.Exit(status.Run(os.Args[1:]))
	case "zdots-storage":
		os.Exit(storage.Run(os.Args[1:]))
	default:
		if len(os.Args) < 2 {
			usage()
			os.Exit(0)
		}
		switch os.Args[1] {
		case "-h", "--help":
			usage()
			os.Exit(0)
		case "agent-guide":
			os.Exit(agentguide.Run(os.Args[2:]))
		case "capabilities":
			os.Exit(capabilities.Run(os.Args[2:]))
		case "zdots-status":
			os.Exit(status.Run(os.Args[2:]))
		case "zdots-storage":
			os.Exit(storage.Run(os.Args[2:]))
		default:
			fmt.Fprintf(os.Stderr, "zdots-core: unknown applet %q\n", os.Args[1])
			usage()
			os.Exit(1)
		}
	}
}
