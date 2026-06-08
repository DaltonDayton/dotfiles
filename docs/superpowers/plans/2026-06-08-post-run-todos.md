# Post-run Manual Steps (todos) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a quill run, print the manual follow-up steps whose `check` command currently fails, so a fresh install surfaces things quill won't automate (e.g. `gh auth login`).

**Architecture:** A new `[[todos]]` table array in `module.toml` (`message` + optional `check`). `runner.PendingTodos(plan)` evaluates each check via an injectable shell runner and returns the unsatisfied ones; `cmd/quill` prints them after the run summary. Stateless and self-clearing — no run history.

**Tech Stack:** Go, `github.com/BurntSushi/toml` (existing), standard `os/exec`.

**Signing caveat:** `commit.gpgsign = true` points at `~/.ssh/id_ed25519`. Every commit in this plan happens while that key still exists. The key is deleted only in the final task, which performs no commits afterward.

---

### Task 1: Revert the auto-key-generation commit

**Files:**
- Delete (via revert): `modules/git/install.sh`

- [ ] **Step 1: Revert the install.sh commit**

```bash
cd /home/dalton/.dotfiles
git revert --no-edit "$(git log --grep='generate SSH signing key' --format=%H -1)"
```

- [ ] **Step 2: Verify install.sh is gone**

Run: `test ! -e modules/git/install.sh && echo GONE`
Expected: `GONE`

---

### Task 2: Add the `Todo` schema type

**Files:**
- Modify: `internal/manifest/schema.go` (Module struct + new type)
- Test: `internal/manifest/parse_test.go`

- [ ] **Step 1: Write the failing parse test**

Add to `internal/manifest/parse_test.go`:

```go
func TestParseModule_todos(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "module.toml")
	content := `
name = "git"

[[todos]]
message = "Run gh auth login"
check = "gh auth status"

[[todos]]
message = "Always shown"
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	m, err := ParseModule(path)
	if err != nil {
		t.Fatalf("ParseModule: %v", err)
	}
	if len(m.Todos) != 2 {
		t.Fatalf("Todos = %+v, want 2", m.Todos)
	}
	if m.Todos[0].Message != "Run gh auth login" || m.Todos[0].Check != "gh auth status" {
		t.Errorf("Todos[0] = %+v", m.Todos[0])
	}
	if m.Todos[1].Check != "" {
		t.Errorf("Todos[1].Check = %q, want empty", m.Todos[1].Check)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/manifest/ -run TestParseModule_todos`
Expected: FAIL (compile error: `m.Todos` undefined)

- [ ] **Step 3: Add the type and field**

In `internal/manifest/schema.go`, add `Todos []Todo` to the `Module` struct (after `Directories`):

```go
	Directories []Directory `toml:"directories"`
	Todos       []Todo      `toml:"todos"`
```

And add the new type near the other action structs:

```go
// Todo is a manual follow-up step printed after a run when its Check fails.
// It does not mutate the system — actions and install.sh do that.
type Todo struct {
	Message string `toml:"message"`
	Check   string `toml:"check"` // shell cmd; exit 0 = done. Empty = always shown.
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/manifest/ -run TestParseModule_todos`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /home/dalton/.dotfiles
gofmt -w internal/manifest/schema.go internal/manifest/parse_test.go
git add internal/manifest/schema.go internal/manifest/parse_test.go
git commit -m "manifest: add [[todos]] schema type"
```

---

### Task 3: Evaluate pending todos in the runner

**Files:**
- Create: `internal/runner/todos.go`
- Test: `internal/runner/todos_test.go`

- [ ] **Step 1: Write the failing test**

Create `internal/runner/todos_test.go`:

```go
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/runner/ -run TestPendingTodos`
Expected: FAIL (compile error: `checkTodo` / `PendingTodos` undefined)

- [ ] **Step 3: Implement the runner**

Create `internal/runner/todos.go`:

```go
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/runner/ -run TestPendingTodos`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /home/dalton/.dotfiles
gofmt -w internal/runner/todos.go internal/runner/todos_test.go
git add internal/runner/todos.go internal/runner/todos_test.go
git commit -m "runner: evaluate pending todos from the plan"
```

---

### Task 4: Print the Manual steps block

**Files:**
- Create: `cmd/quill/todos.go`
- Modify: `cmd/quill/apply.go` (after the summary line, ~line 77)
- Modify: `cmd/quill/install.go` (after the install.sh loop, ~line 110)

- [ ] **Step 1: Add the shared printer**

Create `cmd/quill/todos.go`:

```go
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
```

- [ ] **Step 2: Wire into apply.go**

In `cmd/quill/apply.go`, immediately after the summary line:

```go
				fmt.Printf("\nApplied: %d  Skipped: %d  Failed: %d\n", applied, skipped, failed)
```

add:

```go
				printPendingTodos(cmd.OutOrStdout(), runner.PendingTodos(plan))
```

(so it prints after the summary, before the `if failed > 0` return).

- [ ] **Step 3: Wire into install.go**

In `cmd/quill/install.go`, after the `install.sh` loop and `_ = state.SaveSelection(...)`, before the `if scriptErrs > 0` check, add:

```go
				printPendingTodos(cmd.OutOrStdout(), runner.PendingTodos(plan))
```

- [ ] **Step 4: Build to verify it compiles**

Run: `go build -o ./bin/quill ./cmd/quill`
Expected: no output, exit 0

- [ ] **Step 5: Run full test suite**

Run: `go test ./...`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
cd /home/dalton/.dotfiles
gofmt -w cmd/quill/todos.go cmd/quill/apply.go cmd/quill/install.go
git add cmd/quill/todos.go cmd/quill/apply.go cmd/quill/install.go
git commit -m "cmd: print Manual steps after run"
```

---

### Task 5: Seed git and shell module todos

**Files:**
- Modify: `modules/git/module.toml`
- Modify: `modules/shell/module.toml`

- [ ] **Step 1: Add the git todo**

Append to `modules/git/module.toml`:

```toml
[[todos]]
message = "Run `gh auth login` (choose SSH) to create and upload your signing key to GitHub."
check = "gh auth status"
```

- [ ] **Step 2: Add the shell todo**

Append to `modules/shell/module.toml`:

```toml
[[todos]]
message = "Log out and back in so your login shell change to zsh takes effect."
check = '[ "$SHELL" = "$(command -v zsh)" ]'
```

- [ ] **Step 3: Build and confirm both modules still parse**

Run: `go build -o ./bin/quill ./cmd/quill && ./bin/quill status`
Expected: status lists all modules with no parse error (git, shell still `OK`)

- [ ] **Step 4: Commit**

```bash
cd /home/dalton/.dotfiles
git add modules/git/module.toml modules/shell/module.toml
git commit -m "git,shell: add post-run todos for gh auth and relogin"
```

---

### Task 6: Make the machine fresh and verify end-to-end (no commits after this point)

**Files:** none (runtime verification only)

- [ ] **Step 1: Final format + test gate**

Run: `gofmt -l . && go test ./...`
Expected: `gofmt -l .` prints nothing; tests PASS.

- [ ] **Step 2: Delete the local signing key (LAST commit-affecting-free step)**

```bash
rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
```

- [ ] **Step 3: Observe the todos appear**

Run: `./bin/quill apply git`
Expected: ends with a `Manual steps:` block containing the `[git] Run gh auth login ...` line (because `gh auth status` is non-zero on a fresh machine).

- [ ] **Step 4: Report to the user**

Tell the user the feature is done, the machine is fresh, and the next manual step is theirs: run `gh auth login` (choose SSH) to create + upload the signing key. After that, `quill apply git` will stop showing the gh todo.

---

## Notes for the executor

- `module.Module` embeds `*manifest.Module`, so `p.Module.Todos` and `p.Module.Name` resolve through the embedded pointer.
- Do not add any `git commit` after Task 6 Step 2 — signing will fail until the user runs `gh auth login`.
