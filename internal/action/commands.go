package action

import (
	"fmt"
	"os/exec"
)

// Command runs a shell command (via `sh -c`), optionally gated by a CheckCmd
// whose exit-zero status is treated as "already applied; skip Run".
//
// The struct field is CheckCmd (not Check) to avoid colliding with the
// Action interface's Check() method name — both would be valid Go, but the
// method needs the bare name Check() to satisfy the interface.
type Command struct {
	Run      string
	CheckCmd string
}

func (c *Command) Describe() string {
	return fmt.Sprintf("run %q", c.Run)
}

// Check returns true when CheckCmd exits 0 (system is already in the
// desired state). Empty CheckCmd means "no gate" — always run.
func (c *Command) Check() (bool, error) {
	if c.CheckCmd == "" {
		return false, nil
	}
	err := exec.Command("sh", "-c", c.CheckCmd).Run()
	if err == nil {
		return true, nil
	}
	// why: a non-zero exit is a normal "not applied" signal, not a tool error.
	// Only *ExitError* means the process ran and exited non-zero; other error
	// types (e.g. "sh not found") are real failures we propagate.
	if _, ok := err.(*exec.ExitError); ok {
		return false, nil
	}
	return false, fmt.Errorf("check command failed to execute: %w", err)
}

func (c *Command) Apply() error {
	out, err := exec.Command("sh", "-c", c.Run).CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s: %w (output: %s)", c.Run, err, string(out))
	}
	return nil
}
