package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

// ensureAURHelper makes sure host.AURHelper is installed and on PATH,
// bootstrapping it from source when missing. It's a pre-flight step —
// runs before any module action so declarative AUR packages can trust
// the helper exists. Idempotent: no output when the helper is already
// present.
func ensureAURHelper(host *manifest.Host) error {
	helper := host.AURHelper
	if _, err := exec.LookPath(helper); err == nil {
		return nil
	}
	fmt.Printf("Bootstrapping AUR helper: %s\n", helper)
	switch helper {
	case "paru":
		return bootstrapAURHelper("paru", "https://aur.archlinux.org/paru.git")
	case "yay":
		return bootstrapAURHelper("yay", "https://aur.archlinux.org/yay.git")
	default:
		return fmt.Errorf("unsupported aur_helper %q (expected paru or yay)", helper)
	}
}

// bootstrapAURHelper installs an AUR helper from source: ensures base-devel,
// then uses the other helper as a fast path if available, otherwise clones
// from AUR and builds via makepkg. Commands inherit stdio so the user can
// watch makepkg progress — this runs before the TUI takes over.
func bootstrapAURHelper(name, gitURL string) error {
	if err := runInherit("sudo", "pacman", "-S", "--needed", "--noconfirm", "base-devel", "git"); err != nil {
		return fmt.Errorf("install base-devel: %w", err)
	}

	// Fast path: if the other helper is installed, use it to pull this one
	// from the AUR (avoids a manual makepkg build).
	other := otherHelper(name)
	if _, err := exec.LookPath(other); err == nil {
		return runInherit(other, "-S", "--needed", "--noconfirm",
			"--answerdiff=None", "--answerclean=None", "--mflags=--noconfirm", name)
	}

	tmp, err := os.MkdirTemp("", "quill-"+name+"-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)
	repo := filepath.Join(tmp, name)
	if err := runInherit("git", "clone", gitURL, repo); err != nil {
		return fmt.Errorf("clone %s: %w", gitURL, err)
	}
	cmd := exec.Command("makepkg", "-si", "--noconfirm")
	cmd.Dir = repo
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("makepkg -si: %w", err)
	}
	return nil
}

func otherHelper(name string) string {
	if name == "paru" {
		return "yay"
	}
	return "paru"
}

func runInherit(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
