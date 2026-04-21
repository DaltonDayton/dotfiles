package runner

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/module"
)

// RunInstallSh runs <moduleDir>/install.sh if present. Absence is not an error.
// The script is responsible for its own idempotency (self-check inside).
//
// Stdio is inherited from the parent: scripts may need a real TTY for things
// like `sudo` inside yay/makepkg (Arch's default sudoers ties cached creds to
// the calling TTY). Callers must ensure they aren't competing for the
// terminal — e.g., run install.sh only after any TUI has exited.
func RunInstallSh(m *module.Module) error {
	script := filepath.Join(m.Dir, "install.sh")
	if _, err := os.Stat(script); err != nil {
		return nil
	}
	cmd := exec.Command("sh", script)
	cmd.Dir = m.Dir
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("install.sh for %s failed: %w", m.Name, err)
	}
	return nil
}
