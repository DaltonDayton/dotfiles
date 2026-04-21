package main

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newApplyCmd() *cobra.Command {
	return &cobra.Command{Use: "apply [modules...]", Short: "non-interactive apply (TBD)", RunE: func(_ *cobra.Command, _ []string) error {
		return fmt.Errorf("apply: not yet implemented (see Task 20)")
	}}
}

func newPathCmd() *cobra.Command {
	return &cobra.Command{Use: "path", Short: "install binary to ~/.local/bin (TBD)", RunE: func(_ *cobra.Command, _ []string) error {
		return fmt.Errorf("path: not yet implemented (see Task 21)")
	}}
}
