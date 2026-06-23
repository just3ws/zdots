package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// TestBinaryRedactMode tests the default redact mode (stdin → stdout).
func TestBinaryRedactMode(t *testing.T) {
	// Build the binary first
	binaryPath := buildTestBinary(t)
	defer os.Remove(binaryPath)

	// Skip if the registry doesn't exist (expected in full zdots environment)
	if _, err := os.Stat(filepath.Join(os.Getenv("HOME"), ".config", "zsh", "etc", "phi-patterns.yaml")); err != nil {
		t.Skipf("registry not found")
	}

	// Test normal input (no patterns match)
	input := "this is a normal message"
	cmd := exec.Command(binaryPath)
	cmd.Stdin = strings.NewReader(input)
	output, err := cmd.Output()
	if err != nil {
		t.Fatalf("binary failed: %v", err)
	}
	if string(output) != input {
		t.Errorf("redact mode: input=%q, output=%q, expected no change", input, output)
	}
}

// TestBinarySuppressMode tests the --check flag (suppress pattern predicate).
func TestBinarySuppressMode(t *testing.T) {
	binaryPath := buildTestBinary(t)
	defer os.Remove(binaryPath)

	if _, err := os.Stat(filepath.Join(os.Getenv("HOME"), ".config", "zsh", "etc", "phi-patterns.yaml")); err != nil {
		t.Skipf("registry not found")
	}

	// Test input that does NOT match a suppress pattern (should exit 1)
	input := "normal message"
	cmd := exec.Command(binaryPath, "--check")
	cmd.Stdin = strings.NewReader(input)
	err := cmd.Run()
	if err == nil {
		t.Errorf("--check on non-matching input should exit 1")
	}
}

// TestBinaryDefaultModeSuppressExitsTwo verifies that a suppress-flagged input
// in default (redact) mode exits with code 2 — distinct from the exit-1
// operational errors — so callers can tell a deliberate suppress-match from a
// binary failure in a single invocation (the phi-history hook relies on this).
func TestBinaryDefaultModeSuppressExitsTwo(t *testing.T) {
	binaryPath := buildTestBinary(t)
	defer os.Remove(binaryPath)

	if _, err := os.Stat(filepath.Join(os.Getenv("HOME"), ".config", "zsh", "etc", "phi-patterns.yaml")); err != nil {
		t.Skipf("registry not found")
	}

	// Connection string is suppress-flagged in the registry.
	cmd := exec.Command(binaryPath)
	cmd.Stdin = strings.NewReader("postgresql://user:secret@db.internal/mydb")
	err := cmd.Run()
	exitErr, ok := err.(*exec.ExitError)
	if !ok {
		t.Fatalf("default mode on suppress input should exit non-zero, got err=%v", err)
	}
	if got := exitErr.ExitCode(); got != 2 {
		t.Errorf("default mode suppress: exit code = %d, want 2", got)
	}
}

// TestBinaryInitFlag tests the --init flag (preload and validate).
func TestBinaryInitFlag(t *testing.T) {
	binaryPath := buildTestBinary(t)
	defer os.Remove(binaryPath)

	if _, err := os.Stat(filepath.Join(os.Getenv("HOME"), ".config", "zsh", "etc", "phi-patterns.yaml")); err != nil {
		t.Skipf("registry not found")
	}

	cmd := exec.Command(binaryPath, "--init")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Logf("--init output: %s", output)
		t.Fatalf("--init failed: %v", err)
	}
	// Output should mention pattern counts
	if len(output) == 0 {
		t.Fatal("--init produced no output")
	}
}

// buildTestBinary compiles the binary for testing.
func buildTestBinary(t *testing.T) string {
	// Use the current package directory as the build path
	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("failed to get working directory: %v", err)
	}

	binaryPath := filepath.Join(t.TempDir(), "zdots-phi-scrub")
	cmd := exec.Command("go", "build", "-o", binaryPath, wd)
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("failed to build binary: %v\n%s", err, output)
	}

	return binaryPath
}
