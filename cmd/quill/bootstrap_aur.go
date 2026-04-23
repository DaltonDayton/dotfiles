package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// ensureAURHelpers installs paru and yay from source if missing. Runs as
// a pre-flight step before any module action so declarative AUR packages
// can trust a helper is on PATH. Idempotent: skipped silently when both
// helpers are already installed. Paru is built first via makepkg, then
// yay is pulled via paru (fast path).
func ensureAURHelpers() error {
	for _, h := range []string{"paru", "yay"} {
		if _, err := exec.LookPath(h); err == nil {
			continue
		}
		fmt.Printf("Bootstrapping AUR helper: %s\n", h)
		if err := bootstrapAURHelper(h, "https://aur.archlinux.org/"+h+".git"); err != nil {
			return err
		}
	}
	return nil
}

// bootstrapAURHelper installs a single AUR helper from source: ensures
// base-devel, then uses the other helper as a fast path if available,
// otherwise clones from AUR and builds via makepkg. Inherits stdio so
// the user can watch makepkg progress — this runs before the TUI takes
// over.
func bootstrapAURHelper(name, gitURL string) error {
	if err := runInherit("sudo", "pacman", "-S", "--needed", "--noconfirm", "base-devel", "git"); err != nil {
		return fmt.Errorf("install base-devel: %w", err)
	}

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
