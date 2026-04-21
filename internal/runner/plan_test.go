package runner

import (
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/action"
)

type fakeSudoAction struct {
	needs bool
}

func (f *fakeSudoAction) Describe() string     { return "fake" }
func (f *fakeSudoAction) Check() (bool, error) { return true, nil }
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
		{"sudo false", []action.Action{&fakeSudoAction{needs: false}}, false},
		{"sudo true", []action.Action{plainAction{}, &fakeSudoAction{needs: true}}, true},
	}
	for _, c := range cases {
		plan := []ModulePlan{{Actions: c.acts}}
		if got := PlanNeedsSudo(plan); got != c.want {
			t.Errorf("%s: got %v, want %v", c.name, got, c.want)
		}
	}
}
