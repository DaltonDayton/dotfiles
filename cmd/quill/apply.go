package main

import (
	"fmt"

	"github.com/DaltonDayton/dotfiles/internal/runner"
	"github.com/spf13/cobra"
)

func newApplyCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "apply [modules...]",
		Short: "Apply host profile (or listed modules) without prompts",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, err := loadCtx()
			if err != nil {
				return err
			}

			prof, err := loadProfileByOS(ctx.RepoRoot, ctx.OS)
			if err != nil {
				return err
			}

			names := args
			if len(names) == 0 {
				names = prof.Modules
			}
			ordered, err := runner.ResolveDeps(ctx.Modules, names)
			if err != nil {
				return err
			}
			ordered = runner.FilterByHost(ordered, prof.Name)

			plan := runner.BuildPlan(ordered, prof, ctx.OS)
			if runner.PlanNeedsSudo(plan) || runner.PlanInstallShNeedsSudo(plan) {
				if err := primeSudo(); err != nil {
					return err
				}
			}
			if err := ensureAURHelper(ctx.OS); err != nil {
				return err
			}

			events := make(chan runner.Event, 64)
			go func() {
				defer close(events)
				for _, p := range plan {
					if p.BuildErr != nil {
						events <- runner.Event{Kind: runner.EventError, Module: p.Module.Name, Err: p.BuildErr}
						continue
					}
					runner.ApplyActions(p.Module.Name, p.Actions, events)
				}
			}()

			applied, skipped, failed := 0, 0, 0
			for e := range events {
				switch e.Kind {
				case runner.EventDone:
					applied++
					fmt.Printf("  ✓ %s: %s\n", e.Module, e.Action)
				case runner.EventSkipped:
					skipped++
				case runner.EventError:
					failed++
					fmt.Printf("  ✗ %s: %s (%v)\n", e.Module, e.Action, e.Err)
				}
			}

			// Run install.sh scripts after streaming completes so they can own
			// the terminal (for sudo prompts, interactive bootstraps, etc.).
			for _, p := range plan {
				if p.BuildErr != nil {
					continue
				}
				if err := runner.RunInstallSh(p.Module, ctx.OS, prof.Name); err != nil {
					fmt.Printf("  ✗ %s: install.sh failed (%v)\n", p.Module.Name, err)
					failed++
				}
			}

			fmt.Printf("\nApplied: %d  Skipped: %d  Failed: %d\n", applied, skipped, failed)
			printPendingTodos(cmd.OutOrStdout(), runner.PendingTodos(plan))
			if failed > 0 {
				return fmt.Errorf("%d actions failed", failed)
			}
			return nil
		},
	}
}
