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
			names := args
			if len(names) == 0 {
				names = ctx.Host.Modules
			}
			ordered, err := runner.ResolveDeps(ctx.Modules, names)
			if err != nil {
				return err
			}
			ordered = runner.FilterByHost(ordered, ctx.Host.Name)

			events := make(chan runner.Event, 64)
			go func() {
				defer close(events)
				for _, m := range ordered {
					acts, err := runner.BuildActions(m, ctx.Host)
					if err != nil {
						events <- runner.Event{Kind: runner.EventError, Module: m.Name, Err: err}
						continue
					}
					runner.ApplyActions(m.Name, acts, events)
					if err := runner.RunInstallSh(m); err != nil {
						events <- runner.Event{Kind: runner.EventError, Module: m.Name, Err: err}
					}
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
			fmt.Printf("\nApplied: %d  Skipped: %d  Failed: %d\n", applied, skipped, failed)
			if failed > 0 {
				return fmt.Errorf("%d actions failed", failed)
			}
			return nil
		},
	}
}
