package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
)

func newPathCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "path",
		Short: "Symlink quill to ~/.local/bin and ensure PATH in .zshrc",
		RunE: func(cmd *cobra.Command, args []string) error {
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			exe, err := os.Executable()
			if err != nil {
				return err
			}
			localBin := filepath.Join(home, ".local", "bin")
			if err := os.MkdirAll(localBin, 0o755); err != nil {
				return err
			}
			link := filepath.Join(localBin, "quill")
			_ = os.Remove(link)
			if err := os.Symlink(exe, link); err != nil {
				return err
			}
			rc := filepath.Join(home, ".zshrc")
			modified, err := ensurePathLine(rc)
			if err != nil {
				return err
			}
			fmt.Printf("Symlinked %s → %s\n", link, exe)
			if modified {
				fmt.Println("Added ~/.local/bin to PATH in ~/.zshrc (open a new shell to pick it up)")
			} else {
				fmt.Println("~/.local/bin already on PATH in ~/.zshrc")
			}
			return nil
		},
	}
}
