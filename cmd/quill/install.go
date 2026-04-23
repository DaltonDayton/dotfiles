package main

import (
	"fmt"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/runner"
	"github.com/DaltonDayton/dotfiles/internal/state"
	"github.com/DaltonDayton/dotfiles/internal/tui"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"
)

func newInstallCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "install",
		Short: "Interactive installer",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, err := loadCtx()
			if err != nil {
				return err
			}

			profilePath := filepath.Join(ctx.RepoRoot, "hosts", ctx.Host.Name+".toml")
			fmt.Println(tui.Banner(ctx.Host.Name, profilePath))

			statePath, _ := state.DefaultPath()
			preselectedNames, _ := state.LoadSelection(statePath)
			if len(preselectedNames) == 0 {
				preselectedNames = ctx.Host.Modules
			}
			preselected := map[string]bool{}
			for _, n := range preselectedNames {
				preselected[n] = true
			}

			selected, err := tui.SelectModules(ctx.Modules, preselected)
			if err != nil {
				return err
			}
			if len(selected) == 0 {
				fmt.Println("Nothing selected.")
				return nil
			}

			ordered, err := runner.ResolveDeps(ctx.Modules, selected)
			if err != nil {
				return err
			}
			ordered = runner.FilterByHost(ordered, ctx.Host.Name)

			var proceed bool
			summary := fmt.Sprintf("Will apply %d modules on host %s. Proceed?", len(ordered), ctx.Host.Name)
			if err := huh.NewConfirm().Title(summary).Value(&proceed).Run(); err != nil {
				return err
			}
			if !proceed {
				fmt.Println("Aborted.")
				return nil
			}

			plan := runner.BuildPlan(ordered, ctx.Host)
			if runner.PlanNeedsSudo(plan) {
				if err := primeSudo(); err != nil {
					return err
				}
			}
			if err := ensureAURHelper(ctx.Host); err != nil {
				return err
			}

			events := make(chan runner.Event, 64)
			names := make([]string, 0, len(ordered))
			for _, m := range ordered {
				names = append(names, m.Name)
			}
			prog := tea.NewProgram(tui.NewProgress(names, events))

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

			if _, err := prog.Run(); err != nil {
				return err
			}

			// install.sh runs after the TUI releases the terminal so scripts
			// that shell out to sudo can use the real TTY.
			var scriptErrs int
			for _, p := range plan {
				if p.BuildErr != nil {
					continue
				}
				if err := runner.RunInstallSh(p.Module); err != nil {
					fmt.Fprintln(cmd.ErrOrStderr(), err)
					scriptErrs++
				}
			}

			_ = state.SaveSelection(statePath, selected)
			if scriptErrs > 0 {
				return fmt.Errorf("%d install.sh scripts failed", scriptErrs)
			}
			return nil
		},
	}
}
