package status

import (
	"testing"
)

func TestParseBacklogCounts(t *testing.T) {
	raw := `
In Progress:
  Z-101  First task
  Z-102  Second task
To Do:
  Z-103  Third task
Done:
  Z-100  Old task
`
	wip, todo := parseBacklogCounts(raw)
	if wip != 2 || todo != 1 {
		t.Fatalf("got (wip=%d, todo=%d), want (2, 1)", wip, todo)
	}
}

func TestParseTraceTime(t *testing.T) {
	if _, err := parseTraceTime("2026-11-15T10:00:00-0600"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, err := parseTraceTime("2026-11-15T16:00:00Z"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestRunHelpAndBadOption(t *testing.T) {
	if code := Run([]string{"--help"}); code != 0 {
		t.Fatalf("--help exited %d, want 0", code)
	}
	if code := Run([]string{"--bogus"}); code != 1 {
		t.Fatalf("--bogus exited %d, want 1", code)
	}
	if code := Run([]string{"--interval", "0"}); code != 1 {
		t.Fatalf("--interval 0 exited %d, want 1", code)
	}
}
