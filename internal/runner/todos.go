package runner

import "os/exec"

// checkTodo reports whether a todo's check is satisfied (nil = satisfied,
// so the todo is hidden). Overridable for tests.
var checkTodo = func(cmd string) error {
	return exec.Command("sh", "-c", cmd).Run()
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
