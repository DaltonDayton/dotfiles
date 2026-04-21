package runner

import (
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/action"
)

type fakeSudoAction struct {
	needs    bool
	checked  bool
	checkErr error
}

func (f *fakeSudoAction) Describe() string     { return "fake" }
func (f *fakeSudoAction) Check() (bool, error) { return f.checked, f.checkErr }
func (f *fakeSudoAction) Apply() error         { return nil }
func (f *fakeSudoAction) NeedsSudo() bool      { return f.needs }

type plainAction struct{}

func (plainAction) Describe() string     { return "plain" }
func (plainAction) Check() (bool, error) { return true, nil }
func (plainAction) Apply() error         { return nil }

func TestPlanNeedsSudo(t *testing.T) {
	cases := []struct {
		name string
		acts []action.Action
		want bool
	}{
		{"empty", nil, false},
		{"plain only", []action.Action{plainAction{}}, false},
		{"sudo opt-out", []action.Action{&fakeSudoAction{needs: false, checked: false}}, false},
		{"sudo needed but already applied", []action.Action{&fakeSudoAction{needs: true, checked: true}}, false},
		{"sudo needed and work to do", []action.Action{plainAction{}, &fakeSudoAction{needs: true, checked: false}}, true},
		{"sudo needed but check errored", []action.Action{&fakeSudoAction{needs: true, checkErr: errSentinel}}, false},
	}
	for _, c := range cases {
		plan := []ModulePlan{{Actions: c.acts}}
		if got := PlanNeedsSudo(plan); got != c.want {
			t.Errorf("%s: got %v, want %v", c.name, got, c.want)
		}
	}
}

var errSentinel = fakeErr("boom")

type fakeErr string

func (e fakeErr) Error() string { return string(e) }
