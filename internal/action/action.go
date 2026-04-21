// Package action holds idempotent executors for each declarative action
// type defined in a module.toml (directories, packages, symlinks, files,
// commands, services).
//
// Every action implements the same three-method contract:
//
//	Describe() string        — short human-readable label for logs/TUI
//	Check() (bool, error)    — true  ⇒ already applied; Apply will no-op
//	Apply() error            — bring the system to the desired state
//
// The runner calls Check before Apply so idempotency is uniform across
// all action types.
package action

// Status reports the outcome of applying one action.
type Status string

const (
	StatusApplied Status = "applied"
	StatusSkipped Status = "skipped"
	StatusFailed  Status = "failed"
)

// Action is the interface every executor satisfies.
type Action interface {
	Describe() string
	Check() (bool, error)
	Apply() error
}
