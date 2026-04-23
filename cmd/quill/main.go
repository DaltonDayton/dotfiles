package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var flagRepoRoot string

func main() {
	root := &cobra.Command{
		Use:   "quill",
		Short: "Manage dotfiles and machine setup declaratively",
		// We print errors ourselves in main(); cobra otherwise dumps the
		// error a second time plus the command's full usage text.
		SilenceErrors: true,
		SilenceUsage:  true,
	}
	root.PersistentFlags().StringVar(&flagRepoRoot, "repo", "", "path to the dotfiles repo (default: containing dir of binary, else ~/.dotfiles)")
	root.AddCommand(newListCmd(), newStatusCmd(), newApplyCmd(), newInstallCmd(), newPathCmd())
	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
