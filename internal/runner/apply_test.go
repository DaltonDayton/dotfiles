package runner

import (
	"errors"
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/action"
)

type fakeAction struct {
	desc    string
	checked bool
	applied bool
	err     error
}

func (f *fakeAction) Describe() string     { return f.desc }
func (f *fakeAction) Check() (bool, error) { return f.checked, nil }
func (f *fakeAction) Apply() error {
	f.applied = true
	return f.err
}

func TestApplyActions_skipsAlreadyApplied(t *testing.T) {
	a := &fakeAction{desc: "a", checked: true}
	b := &fakeAction{desc: "b", checked: false}
	events := make(chan Event, 16)
	results := ApplyActions("mod", []action.Action{a, b}, events)
	close(events)

	if a.applied {
		t.Error("a should have been skipped")
	}
	if !b.applied {
		t.Error("b should have been applied")
	}
	if results[0].Status != action.StatusSkipped {
		t.Errorf("results[0] = %+v", results[0])
	}
	if results[1].Status != action.StatusApplied {
		t.Errorf("results[1] = %+v", results[1])
	}
}

func TestApplyActions_reportsFailure(t *testing.T) {
	a := &fakeAction{desc: "a", err: errors.New("nope")}
	events := make(chan Event, 8)
	results := ApplyActions("mod", []action.Action{a}, events)
	close(events)
	if results[0].Status != action.StatusFailed {
		t.Errorf("got %+v", results[0])
	}
}

func TestApplyActions_eventsTaggedWithModule(t *testing.T) {
	a := &fakeAction{desc: "a", checked: true}
	events := make(chan Event, 4)
	ApplyActions("mymod", []action.Action{a}, events)
	close(events)
	found := false
	for e := range events {
		if e.Module != "mymod" {
			t.Errorf("event %+v not tagged with module", e)
		}
		found = true
	}
	if !found {
		t.Error("no events received")
	}
}
