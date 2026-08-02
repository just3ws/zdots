package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
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

// TestBinaryServeMode exercises the resident protocol (Z-283): NUL-framed
// requests over stdin, status-byte + payload + NUL responses, multiple
// round-trips through one process, clean exit on stdin EOF.
func TestBinaryServeMode(t *testing.T) {
	binaryPath := buildTestBinary(t)
	defer os.Remove(binaryPath)

	if _, err := os.Stat(filepath.Join(os.Getenv("HOME"), ".config", "zsh", "etc", "phi-patterns.yaml")); err != nil {
		t.Skipf("registry not found")
	}

	cmd := exec.Command(binaryPath, "--serve")
	stdin, err := cmd.StdinPipe()
	if err != nil {
		t.Fatalf("stdin pipe: %v", err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatalf("stdout pipe: %v", err)
	}
	if err := cmd.Start(); err != nil {
		t.Fatalf("start: %v", err)
	}

	readResp := func() (byte, string) {
		t.Helper()
		buf := make([]byte, 0, 256)
		one := make([]byte, 1)
		for {
			if _, err := stdout.Read(one); err != nil {
				t.Fatalf("read response: %v", err)
			}
			if one[0] == 0 {
				break
			}
			buf = append(buf, one[0])
		}
		if len(buf) == 0 {
			t.Fatal("empty response frame")
		}
		return buf[0], string(buf[1:])
	}

	// Round-trip 1: clean input passes through unchanged, status '0'.
	if _, err := stdin.Write([]byte("echo hello world\x00")); err != nil {
		t.Fatalf("write: %v", err)
	}
	status, payload := readResp()
	if status != '0' || payload != "echo hello world" {
		t.Errorf("clean: status=%c payload=%q", status, payload)
	}

	// Round-trip 2 (same process): multiline input survives NUL framing.
	if _, err := stdin.Write([]byte("line one\nline two\x00")); err != nil {
		t.Fatalf("write: %v", err)
	}
	status, payload = readResp()
	if status != '0' || payload != "line one\nline two" {
		t.Errorf("multiline: status=%c payload=%q", status, payload)
	}

	// Round-trip 3: suppress-flagged input answers '2' with empty payload.
	if _, err := stdin.Write([]byte("postgresql://user:secret@db.internal/mydb\x00")); err != nil {
		t.Fatalf("write: %v", err)
	}
	status, payload = readResp()
	if status != '2' || payload != "" {
		t.Errorf("suppress: status=%c payload=%q", status, payload)
	}

	// EOF: server exits 0 without noise.
	stdin.Close()
	if err := cmd.Wait(); err != nil {
		t.Errorf("serve exit on EOF: %v", err)
	}
}

// TestBinaryServeIdleTimeout verifies the server exits on its own when idle.
func TestBinaryServeIdleTimeout(t *testing.T) {
	binaryPath := buildTestBinary(t)
	defer os.Remove(binaryPath)

	if _, err := os.Stat(filepath.Join(os.Getenv("HOME"), ".config", "zsh", "etc", "phi-patterns.yaml")); err != nil {
		t.Skipf("registry not found")
	}

	cmd := exec.Command(binaryPath, "--serve")
	cmd.Env = append(os.Environ(), "ZDOTS_PHI_SERVE_IDLE=1")
	stdin, err := cmd.StdinPipe()
	if err != nil {
		t.Fatalf("stdin pipe: %v", err)
	}
	defer stdin.Close()
	if err := cmd.Start(); err != nil {
		t.Fatalf("start: %v", err)
	}

	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case err := <-done:
		if err != nil {
			t.Errorf("idle exit: %v", err)
		}
	case <-time.After(5 * time.Second):
		cmd.Process.Kill()
		t.Fatal("server did not exit after idle timeout")
	}
}
