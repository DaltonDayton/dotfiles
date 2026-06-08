package runner

import (
	"errors"
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

func TestPendingTodos(t *testing.T) {
	orig := checkTodo
	defer func() { checkTodo = orig }()
	checkTodo = func(cmd string) error {
		if cmd == "pass" {
			return nil
		}
		return errors.New("fail")
	}

	plan := []ModulePlan{
		{Module: &module.Module{Module: &manifest.Module{
			Name: "git",
			Todos: []manifest.Todo{
				{Message: "satisfied", Check: "pass"},
				{Message: "pending", Check: "fail"},
				{Message: "always", Check: ""},
			},
		}}},
		{Module: &module.Module{Module: &manifest.Module{Name: "broken"}},
			BuildErr: errors.New("boom")},
	}

	got := PendingTodos(plan)
	if len(got) != 2 {
		t.Fatalf("PendingTodos = %+v, want 2", got)
	}
	if got[0].Module != "git" || got[0].Message != "pending" {
		t.Errorf("got[0] = %+v", got[0])
	}
	if got[1].Message != "always" {
		t.Errorf("got[1] = %+v", got[1])
	}
}

func TestPendingTodos_allSatisfied(t *testing.T) {
	orig := checkTodo
	defer func() { checkTodo = orig }()
	checkTodo = func(cmd string) error { return nil }

	plan := []ModulePlan{
		{Module: &module.Module{Module: &manifest.Module{
			Name:  "git",
			Todos: []manifest.Todo{{Message: "done", Check: "whatever"}},
		}}},
	}

	if got := PendingTodos(plan); len(got) != 0 {
		t.Errorf("all satisfied: got %+v, want empty", got)
	}
}
