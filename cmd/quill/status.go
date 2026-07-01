package main

import (
	"fmt"

	"github.com/DaltonDayton/dotfiles/internal/runner"
	"github.com/DaltonDayton/dotfiles/internal/state"
	"github.com/spf13/cobra"
)

func newStatusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show applied / pending status for every module in this host's profile",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, err := loadCtx()
			if err != nil {
				return err
			}

			sp, _ := state.DefaultPath()
			saved, _ := state.LoadState(sp)
			prof, osName, _, err := resolveProfileNonInteractive(ctx.RepoRoot, saved)
			if err != nil {
				return err
			}
			ctx.OS = osName

			ordered, err := runner.ResolveDeps(ctx.Modules, prof.Modules)
			if err != nil {
				return err
			}
			ordered = runner.FilterByHost(ordered, prof.Name)
			for _, m := range ordered {
				acts, err := runner.BuildActions(m, prof, ctx.OS)
				if err != nil {
					fmt.Printf("%-20s ERROR: %v\n", m.Name, err)
					continue
				}
				var pending, total int
				for _, a := range acts {
					total++
					ok, err := a.Check()
					if err != nil || !ok {
						pending++
					}
				}
				marker := "OK"
				if pending > 0 {
					marker = fmt.Sprintf("PENDING (%d/%d)", pending, total)
				}
				fmt.Printf("%-20s %s\n", m.Name, marker)
			}
			return nil
		},
	}
}
