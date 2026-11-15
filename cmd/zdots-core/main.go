package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/capabilities"
)

func usage() {
	fmt.Print(`Usage: zdots-core <applet> [args...]

Multicall Go binary for performance-critical zdots platform commands.
Invoke via symlink (e.g. capabilities) or directly as: zdots-core <applet>.

Applets:
  capabilities    Environment health and service contract validator

Options:
  -h, --help      Show this help
`)
}

func main() {
	invoked := filepath.Base(os.Args[0])
	switch invoked {
	case "capabilities":
		os.Exit(capabilities.Run(os.Args[1:]))
	default:
		if len(os.Args) < 2 {
			usage()
			os.Exit(0)
		}
		switch os.Args[1] {
		case "-h", "--help":
			usage()
			os.Exit(0)
		case "capabilities":
			os.Exit(capabilities.Run(os.Args[2:]))
		default:
			fmt.Fprintf(os.Stderr, "zdots-core: unknown applet %q\n", os.Args[1])
			usage()
			os.Exit(1)
		}
	}
}
