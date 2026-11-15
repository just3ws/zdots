package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/agentguide"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/capabilities"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/ctl"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/doctor"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/llamacaps"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/logs"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/o2query"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/status"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/statusd"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/storage"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/zsvc"
)

func usage() {
	fmt.Print(`Usage: zdots-core <applet> [args...]

Multicall Go binary for performance-critical zdots platform commands.
Invoke via symlink (e.g. capabilities) or directly as: zdots-core <applet>.

Applets:
  agent-guide     Live service status and usage guidance for AI agents
  capabilities    Environment health and service contract validator
  llama-caps      Capability report for local llama.cpp inference service
  zdots-ctl       Zdots platform orchestrator and health checker
  zdots-doctor    System health check ("brew doctor" for zdots)
  zdots-logs      Centralized log operations for all zdots-managed services
  zdots-o2-query  Read-only OpenObserve log and trace query tool
  zdots-status    Live TUI dashboard for Zdots platform health
  zdots-statusd   Loopback HTTP control-plane console (127.0.0.1:11600)
  zdots-storage   Multi-bucket system storage monitoring & budget attestation
  zsvc            Unified service control for zdots-managed services

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
	case "llama-caps":
		os.Exit(llamacaps.Run(os.Args[1:]))
	case "zdots-ctl":
		os.Exit(ctl.Run(os.Args[1:]))
	case "zdots-doctor":
		os.Exit(doctor.Run(os.Args[1:]))
	case "zdots-logs":
		os.Exit(logs.Run(os.Args[1:]))
	case "zdots-o2-query":
		os.Exit(o2query.Run(os.Args[1:]))
	case "zdots-status":
		os.Exit(status.Run(os.Args[1:]))
	case "zdots-statusd":
		os.Exit(statusd.Run(os.Args[1:]))
	case "zdots-storage":
		os.Exit(storage.Run(os.Args[1:]))
	case "zsvc":
		os.Exit(zsvc.Run(os.Args[1:]))
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
		case "llama-caps":
			os.Exit(llamacaps.Run(os.Args[2:]))
		case "zdots-ctl":
			os.Exit(ctl.Run(os.Args[2:]))
		case "zdots-doctor":
			os.Exit(doctor.Run(os.Args[2:]))
		case "zdots-logs":
			os.Exit(logs.Run(os.Args[2:]))
		case "zdots-o2-query":
			os.Exit(o2query.Run(os.Args[2:]))
		case "zdots-status":
			os.Exit(status.Run(os.Args[2:]))
		case "zdots-statusd":
			os.Exit(statusd.Run(os.Args[2:]))
		case "zdots-storage":
			os.Exit(storage.Run(os.Args[2:]))
		case "zsvc":
			os.Exit(zsvc.Run(os.Args[2:]))
		default:
			fmt.Fprintf(os.Stderr, "zdots-core: unknown applet %q\n", os.Args[1])
			usage()
			os.Exit(1)
		}
	}
}
