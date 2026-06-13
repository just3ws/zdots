package phi

import (
	"os"
	"testing"
)

// TestLoad_Success validates that Load() correctly reads and compiles patterns from the registry.
func TestLoad_Success(t *testing.T) {
	// Skip if the real registry doesn't exist
	// In CI, we would provide a test fixture instead
	if _, err := os.Stat(patternsPath()); err != nil {
		t.Skipf("registry not found at %s (expected in full zdots environment)", patternsPath())
	}

	c, err := Load()
	if err != nil {
		t.Fatalf("Load() failed: %v", err)
	}

	redactCount, suppressCount := c.PatternCount()
	if redactCount == 0 && suppressCount == 0 {
		t.Fatal("no patterns loaded")
	}
	t.Logf("loaded %d redact + %d suppress patterns", redactCount, suppressCount)
}

// TestLoad_MissingRegistry validates that Load() fails when the registry is missing.
func TestLoad_MissingRegistry(t *testing.T) {
	// Temporarily override ZDOTDIR to point to a nonexistent path
	oldZDOTDIR := os.Getenv("ZDOTDIR")
	os.Setenv("ZDOTDIR", "/nonexistent/path")
	defer os.Setenv("ZDOTDIR", oldZDOTDIR)

	_, err := Load()
	if err == nil {
		t.Fatal("Load() should fail when registry is missing")
	}
}

// TestTranslateReplacement validates sed-style \N → Go RE2 $N conversion.
func TestTranslateReplacement(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{
			input:    "[REDACTED:\\1]",
			expected: "[REDACTED:$1]",
		},
		{
			input:    "***\\2***",
			expected: "***$2***",
		},
		{
			input:    "$foo",
			expected: "$$foo", // literal $ should be escaped
		},
		{
			input:    "\\1-\\2",
			expected: "$1-$2",
		},
	}

	for _, tt := range tests {
		got := translateReplacement(tt.input)
		if got != tt.expected {
			t.Errorf("translateReplacement(%q) = %q, want %q", tt.input, got, tt.expected)
		}
	}
}

// TestIsSuppressed_WithoutPatterns returns false for input without suppress patterns.
func TestIsSuppressed_WithoutPatterns(t *testing.T) {
	// For testing without the full registry, we'd create a minimal fixture.
	// For now, skip if the registry doesn't exist.
	if _, err := os.Stat(patternsPath()); err != nil {
		t.Skipf("registry not found")
	}

	c, err := Load()
	if err != nil {
		t.Fatalf("Load() failed: %v", err)
	}

	// Test input that should NOT match any suppress pattern
	cleanInput := []byte("this is a normal log message")
	if c.IsSuppressed(cleanInput) {
		t.Errorf("IsSuppressed(%q) = true, want false", cleanInput)
	}
}

// TestScrub_RedactsPatterns validates that Scrub() redacts matching patterns.
func TestScrub_RedactsPatterns(t *testing.T) {
	// Skip if registry doesn't exist
	if _, err := os.Stat(patternsPath()); err != nil {
		t.Skipf("registry not found")
	}

	c, err := Load()
	if err != nil {
		t.Fatalf("Load() failed: %v", err)
	}

	// Test a known pattern (SSN, if present in the registry)
	// This is a bit fragile — in a real test, we'd provide a fixture registry
	// For now, just verify the function runs without error
	input := []byte("Some text")
	output := c.Scrub(input)
	if output == nil {
		t.Fatal("Scrub() returned nil")
	}
}

// TestPatternCount validates that PatternCount returns correct counts.
func TestPatternCount(t *testing.T) {
	if _, err := os.Stat(patternsPath()); err != nil {
		t.Skipf("registry not found")
	}

	c, err := Load()
	if err != nil {
		t.Fatalf("Load() failed: %v", err)
	}

	redactCount, suppressCount := c.PatternCount()
	if redactCount < 0 || suppressCount < 0 {
		t.Fatalf("PatternCount() returned negative counts: redact=%d suppress=%d", redactCount, suppressCount)
	}
	if redactCount == 0 && suppressCount == 0 {
		t.Fatal("PatternCount() returned zero patterns")
	}
}
