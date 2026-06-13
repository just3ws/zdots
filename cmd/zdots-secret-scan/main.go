// Command zdots-secret-scan detects secrets committed to a git repo.
//
// It is the Go successor to bin/secret-scan (bash): patterns move out of an
// inline array into etc/secret-patterns.yaml, matching runs on RE2 via the
// shared registry engine, and the file list comes from `git ls-files` so only
// tracked content is scanned. Exits 1 on any finding, 0 when clean, 2 on setup
// error — drop-in parity with the bash tool's contract.
package main

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"zdots/cmd/zdots-secret-scan/internal/scan"
)

// excludes mirror bin/secret-scan: skip the example secrets, tests, docs, and
// the scanners + registries themselves — they legitimately contain pattern
// strings that would otherwise self-trip the scan.
var excludes = []string{
	":!.zdots.secrets.example",
	":!tests/",
	":!docs/",
	":!bin/secret-scan",
	":!bin/zdots-secret-scan",
	":!cmd/zdots-secret-scan/",
	":!etc/secret-patterns.yaml",
	":!etc/phi-patterns.yaml",
}

func main() {
	reg, err := scan.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-secret-scan: %v\n", err)
		os.Exit(2)
	}

	// Scan from the repo root so git paths and file reads agree.
	if err := chdirRepoRoot(); err != nil {
		fmt.Fprintf(os.Stderr, "zdots-secret-scan: %v\n", err)
		os.Exit(2)
	}

	files, err := gitFiles()
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-secret-scan: %v\n", err)
		os.Exit(2)
	}

	findings := 0
	for _, f := range files {
		data, err := os.ReadFile(f)
		if err != nil {
			continue // unreadable / dangling symlink — skip, don't fail the run
		}
		sc := bufio.NewScanner(bytes.NewReader(data))
		sc.Buffer(make([]byte, 0, 64*1024), 1024*1024) // tolerate long minified lines
		line := 0
		for sc.Scan() {
			line++
			if name, match := reg.Match(sc.Bytes()); name != "" {
				findings++
				fmt.Fprintf(os.Stderr, "%s:%d: [%s] %s\n", f, line, name, match)
			}
		}
	}

	if findings > 0 {
		fmt.Fprintf(os.Stderr, "zdots-secret-scan: FAILURE — %d potential secret(s) detected\n", findings)
		os.Exit(1)
	}
	fmt.Println("zdots-secret-scan: OK")
}

func chdirRepoRoot() error {
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		return fmt.Errorf("not in a git repo: %w", err)
	}
	return os.Chdir(strings.TrimSpace(string(out)))
}

func gitFiles() ([]string, error) {
	args := append([]string{"ls-files", "-z", "--"}, excludes...)
	out, err := exec.Command("git", args...).Output()
	if err != nil {
		return nil, fmt.Errorf("git ls-files failed: %w", err)
	}
	var files []string
	for _, b := range bytes.Split(out, []byte{0}) {
		if len(b) > 0 {
			files = append(files, string(b))
		}
	}
	return files, nil
}
