package runner

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

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

// InstallShNeedsSudo reports whether the module's install.sh exists and
// contains a sudo invocation outside of comments. Used to decide whether
// to prime sudo before the TUI runs so install.sh doesn't surprise the
// user with a password prompt at the end. Errors reading the script are
// treated as "no sudo" — the script will simply prompt at runtime if it
// turns out to need it.
func InstallShNeedsSudo(m *module.Module) bool {
	script := filepath.Join(m.Dir, "install.sh")
	data, err := os.ReadFile(script)
	if err != nil {
		return false
	}
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimLeft(line, " \t")
		if strings.HasPrefix(trimmed, "#") {
			continue
		}
		if strings.Contains(trimmed, "sudo ") {
			return true
		}
	}
	return false
}

// PlanInstallShNeedsSudo reports whether any module in the plan has an
// install.sh that invokes sudo. Mirrors PlanNeedsSudo for the post-TUI
// script phase so callers can prime sudo once for both phases.
func PlanInstallShNeedsSudo(plan []ModulePlan) bool {
	for _, p := range plan {
		if p.BuildErr != nil {
			continue
		}
		if InstallShNeedsSudo(p.Module) {
			return true
		}
	}
	return false
}
