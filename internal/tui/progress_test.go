package tui

import (
	"errors"
	"strings"
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/runner"
)

func newTestModel(order []string, counts map[string]int) *Model {
	ch := make(chan runner.Event)
	close(ch)
	return NewProgress(order, counts, ch)
}

func feed(m *Model, evs ...runner.Event) {
	for _, e := range evs {
		m.Update(eventMsg(e))
	}
}

func TestProgress_PendingThenRunning(t *testing.T) {
	m := newTestModel([]string{"git"}, map[string]int{"git": 3})
	if got := m.byName["git"].status(); got != "pending" {
		t.Fatalf("initial status = %q, want pending", got)
	}
	if !strings.Contains(m.View(), "pending (3 actions)") {
		t.Errorf("pending view missing action count, got: %s", m.View())
	}

	feed(m, runner.Event{Kind: runner.EventStart, Module: "git", Action: "symlink ~/.gitconfig"})
	if got := m.byName["git"].status(); got != "running" {
		t.Fatalf("after start status = %q, want running", got)
	}
	if !strings.Contains(m.View(), "[1/3] symlink ~/.gitconfig") {
		t.Errorf("running view missing counter+action, got: %s", m.View())
	}
}

func TestProgress_AppliedSkippedTotals(t *testing.T) {
	m := newTestModel([]string{"git"}, map[string]int{"git": 3})
	feed(m,
		runner.Event{Kind: runner.EventStart, Module: "git", Action: "a1"},
		runner.Event{Kind: runner.EventDone, Module: "git", Action: "a1"},
		runner.Event{Kind: runner.EventStart, Module: "git", Action: "a2"},
		runner.Event{Kind: runner.EventSkipped, Module: "git", Action: "a2"},
		runner.Event{Kind: runner.EventStart, Module: "git", Action: "a3"},
		runner.Event{Kind: runner.EventSkipped, Module: "git", Action: "a3"},
	)
	l := m.byName["git"]
	if l.status() != "done" {
		t.Fatalf("status = %q, want done", l.status())
	}
	if l.applied != 1 || l.skipped != 2 || l.failed != 0 {
		t.Errorf("counts: applied=%d skipped=%d failed=%d", l.applied, l.skipped, l.failed)
	}
	if !strings.Contains(m.View(), "1 applied · 2 skipped") {
		t.Errorf("done summary missing, got: %s", m.View())
	}
}

func TestProgress_FailedSurfacesError(t *testing.T) {
	m := newTestModel([]string{"ai"}, map[string]int{"ai": 2})
	boom := errors.New("aur install: exit 1")
	feed(m,
		runner.Event{Kind: runner.EventStart, Module: "ai", Action: "install claude-code"},
		runner.Event{Kind: runner.EventError, Module: "ai", Action: "install claude-code", Err: boom},
		runner.Event{Kind: runner.EventStart, Module: "ai", Action: "symlink settings.json"},
		runner.Event{Kind: runner.EventDone, Module: "ai", Action: "symlink settings.json"},
	)
	l := m.byName["ai"]
	if l.status() != "failed" {
		t.Fatalf("status = %q, want failed", l.status())
	}
	v := m.View()
	if !strings.Contains(v, "1 applied · 0 skipped · 1 failed") {
		t.Errorf("failed summary missing, got: %s", v)
	}
	if !strings.Contains(v, boom.Error()) {
		t.Errorf("error message missing, got: %s", v)
	}
}

func TestProgress_UnknownModuleEventIgnored(t *testing.T) {
	m := newTestModel([]string{"git"}, map[string]int{"git": 1})
	feed(m, runner.Event{Kind: runner.EventStart, Module: "ghost", Action: "x"})
	if got := m.byName["git"].status(); got != "pending" {
		t.Fatalf("git was disturbed by ghost event: %q", got)
	}
}
