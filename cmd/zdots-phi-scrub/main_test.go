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
