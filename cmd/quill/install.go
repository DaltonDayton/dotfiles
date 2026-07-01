package main

import (
	"fmt"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/module"
	"github.com/DaltonDayton/dotfiles/internal/profile"
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

			osName, machine, err := tui.PickProfile(ctx.OS)
			if err != nil {
				return err
			}
			prof, err := profile.Load(filepath.Join(ctx.RepoRoot, "profiles"), osName, machine)
			if err != nil {
				return err
			}
			ctx.OS = osName // the pick drives gating

			statePath, _ := state.DefaultPath()
			saved, _ := state.LoadState(statePath)
			candidates := prof.Modules
			if saved != nil && len(saved.Modules) > 0 {
				candidates = saved.Modules
			}
			valid := module.FilterValid(ctx.Modules, osName, machine)
			preselected := module.Preselect(valid, candidates)

			selected, err := tui.SelectModules(valid, preselected)
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
			ordered = runner.FilterByHost(ordered, prof.Name)

			var proceed bool
			summary := fmt.Sprintf("Will apply %d modules on profile %s. Proceed?", len(ordered), prof.Name)
			if err := huh.NewConfirm().Title(summary).Value(&proceed).Run(); err != nil {
				return err
			}
			if !proceed {
				fmt.Println("Aborted.")
				return nil
			}

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
			names := make([]string, 0, len(ordered))
			for _, m := range ordered {
				names = append(names, m.Name)
			}
			counts := make(map[string]int, len(plan))
			for _, p := range plan {
				counts[p.Module.Name] = len(p.Actions)
			}
			prog := tea.NewProgram(tui.NewProgress(names, counts, events))

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
				if err := runner.RunInstallSh(p.Module, ctx.OS, prof.Name); err != nil {
					fmt.Fprintln(cmd.ErrOrStderr(), err)
					scriptErrs++
				}
			}

			_ = state.SaveState(statePath, &state.Selection{OS: osName, Machine: machine, Modules: selected})
			printPendingTodos(cmd.OutOrStdout(), runner.PendingTodos(plan))
			if scriptErrs > 0 {
				return fmt.Errorf("%d install.sh scripts failed", scriptErrs)
			}
			return nil
		},
	}
}
