package main

import (
	"fmt"
	"os"
	"os/exec"
)

// primeSudo runs an interactive `sudo -v` so later `sudo -n` calls inside
// the pacman driver (and AUR helpers that shell out to sudo themselves)
// succeed without mangling the TUI with a password prompt.
func primeSudo() error {
	fmt.Fprintln(os.Stderr, "Some actions require root; priming sudo…")
	cmd := exec.Command("sudo", "-v")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("sudo -v failed: %w", err)
	}
	return nil
}
