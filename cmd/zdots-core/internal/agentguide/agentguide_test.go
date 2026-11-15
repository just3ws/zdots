package agentguide

import (
	"testing"
)

func TestRunHelpAndBadFlag(t *testing.T) {
	if code := Run([]string{"--help"}); code != 0 {
		t.Fatalf("--help exited %d, want 0", code)
	}
	if code := Run([]string{"--bogus"}); code != 1 {
		t.Fatalf("--bogus exited %d, want 1", code)
	}
}
