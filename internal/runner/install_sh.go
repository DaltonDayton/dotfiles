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
func RunInstallSh(m *module.Module) error {
	script := filepath.Join(m.Dir, "install.sh")
	if _, err := os.Stat(script); err != nil {
		return nil
	}
	cmd := exec.Command("sh", script)
	cmd.Dir = m.Dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("install.sh for %s failed: %w (output: %s)", m.Name, err, string(out))
	}
	return nil
}
