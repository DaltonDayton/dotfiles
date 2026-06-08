# Spec: Post-run manual steps (`[[todos]]`)

**Date:** 2026-06-08
**Status:** Approved

## Problem

A fresh quill install leaves some setup that quill deliberately does *not*
automate — notably authenticating to GitHub and creating/uploading an SSH
signing key. The `git` module sets `commit.gpgsign = true` with
`gpg.format = ssh` pointing at `~/.ssh/id_ed25519`, but no key exists on a
fresh machine, so commits fail until the user acts. There is currently no
place to surface "here's what you still need to do by hand."

An earlier attempt added `modules/git/install.sh` to auto-generate the key.
That is being reverted: `gh auth login` (SSH option) creates *and* uploads the
key to GitHub in one step, which is more convenient and keeps quill out of the
business of minting identity material. Instead, quill should *remind* the user.

## Solution

Modules declare manual follow-up steps in `module.toml`. Each step carries a
`check` command. After a run completes, quill evaluates the checks and prints
only the steps whose check currently fails. This is stateless and self-clearing
— the same idea as `Action.Check()`, but it *reports* rather than *acts*. No
"first run" bookkeeping; a step disappears once its check passes.

### Schema

New `Todo` struct and `Todos []Todo` field on `Module`
(`internal/manifest/schema.go`), decoded by the existing TOML loader:

```toml
[[todos]]
message = "Run `gh auth login` (choose SSH) to create and upload your signing key to GitHub."
check = "gh auth status"
```

- `message` (required): the human-facing instruction.
- `check` (optional): shell command run via `sh -c`. Exit 0 = done (hidden);
  non-zero = pending (shown). An empty/omitted `check` means always shown.

### Evaluation

New `internal/runner/todos.go`:

```go
type PendingTodo struct {
    Module  string
    Message string
}

func PendingTodos(plan []ModulePlan) []PendingTodo
```

Iterates the plan's modules in order, runs each todo's `check` with output
suppressed, and collects the ones that fail (plus empty-check ones) tagged with
their module name. Check execution goes through an injectable package var
(mirroring `internal/action/services.go`'s `var systemctl`) so tests inject a
fake instead of shelling out. Library code returns data — it does not print.

### Presentation

`cmd/quill/install.go` and `cmd/quill/apply.go` call `PendingTodos(plan)` after
the `install.sh` loop and print a `Manual steps:` block **after** the final
`Applied/Skipped/Failed` summary. A small shared helper formats the block so the
two commands don't duplicate it. When there are no pending todos, nothing prints.

Format:

```
Manual steps:
  • [git] Run `gh auth login` (choose SSH) to create and upload your signing key to GitHub.
  • [shell] Log out and back in so your login shell change to zsh takes effect.
```

### Seed content

- **git module:** the `gh auth login` todo above, `check = "gh auth status"`.
  `github-cli` is installed by the same module, so `gh` exists by the time the
  check runs post-run.
- **shell module:** a relogin reminder,
  `check = '[ "$SHELL" = "$(command -v zsh)" ]'` — `$SHELL` only updates after a
  fresh login, so it self-clears once the user logs back in.

## Cleanup (prerequisite work)

- Revert the `modules/git/install.sh` commit (drop auto key generation).
- Delete `~/.ssh/id_ed25519{,.pub}` on this machine so it is genuinely fresh and
  exercises the new git todo end-to-end.

**Ordering caveat:** deleting the key must be the *last* action, because
`commit.gpgsign = true` means every commit after deletion fails until the user
runs `gh auth login`. All spec/plan/implementation commits happen while the key
still exists; key deletion is the final step.

## Testing

- `internal/manifest/parse_test.go`: a case parsing `[[todos]]` with `message`
  and `check`.
- `internal/runner/todos_test.go`: check-passes → hidden; check-fails → shown;
  empty-check → shown; module name is attached. Uses the injected fake check
  runner.

## Out of scope

- Persisted "seen"/dismissal state for todos.
- Todos that mutate the system (that is what actions and `install.sh` are for).
- Interactive prompting to run the steps; quill only reports them.
