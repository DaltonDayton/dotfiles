package runner

import (
	"io"
	"os/exec"
)

// checkTodo reports whether a todo's check is satisfied (nil = satisfied,
// so the todo is hidden). Overridable for tests. Output is discarded — the
// check is a pass/fail probe, not a diagnostic, so its chatter (e.g. gh's
// "not logged in" message) must not leak before the Manual steps block.
var checkTodo = func(cmd string) error {
	c := exec.Command("sh", "-c", cmd)
	c.Stdout = io.Discard
	c.Stderr = io.Discard
	return c.Run()
}

// PendingTodo is a manual step that still needs the user's attention.
type PendingTodo struct {
	Module  string
	Message string
}

// PendingTodos returns the manual steps whose check is unsatisfied, in module
// order. An empty check is always pending. Modules that failed to build are
// skipped.
func PendingTodos(plan []ModulePlan) []PendingTodo {
	var out []PendingTodo
	for _, p := range plan {
		if p.BuildErr != nil {
			continue
		}
		for _, todo := range p.Module.Todos {
			if todo.Check != "" && checkTodo(todo.Check) == nil {
				continue
			}
			out = append(out, PendingTodo{Module: p.Module.Name, Message: todo.Message})
		}
	}
	return out
}
