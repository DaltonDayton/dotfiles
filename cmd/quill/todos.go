package main

import (
	"fmt"
	"io"

	"github.com/DaltonDayton/dotfiles/internal/runner"
)

// printPendingTodos writes the Manual steps block, or nothing when empty.
func printPendingTodos(w io.Writer, todos []runner.PendingTodo) {
	if len(todos) == 0 {
		return
	}
	fmt.Fprintln(w, "\nManual steps:")
	for _, t := range todos {
		fmt.Fprintf(w, "  • [%s] %s\n", t.Module, t.Message)
	}
}
