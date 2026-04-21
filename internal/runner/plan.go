package runner

import (
	"github.com/DaltonDayton/dotfiles/internal/action"
	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

// ModulePlan pairs a module with its pre-built action list so the caller
// can scan the full set (e.g., for sudo priming) before starting execution.
type ModulePlan struct {
	Module   *module.Module
	Actions  []action.Action
	BuildErr error
}

// BuildPlan resolves every module's actions up front. A per-module BuildErr
// is stored on the plan entry rather than short-circuiting — callers surface
// it during apply so the user sees which module failed to plan.
func BuildPlan(mods []*module.Module, host *manifest.Host) []ModulePlan {
	out := make([]ModulePlan, len(mods))
	for i, m := range mods {
		acts, err := BuildActions(m, host)
		out[i] = ModulePlan{Module: m, Actions: acts, BuildErr: err}
	}
	return out
}

// PlanNeedsSudo reports whether any action in the plan will actually invoke
// a privileged command. An action qualifies when it (a) opts in via a
// NeedsSudo() method and (b) its Check returns (false, nil) — i.e., Apply
// will run. Check errors mean Apply is skipped, so no sudo is needed.
//
// This runs Check once per sudo-capable action before the main apply loop.
// Check is required to be cheap and side-effect-free, so the pre-pass is
// the right cost to pay to avoid prompting the user when every action is
// already satisfied.
func PlanNeedsSudo(plan []ModulePlan) bool {
	for _, p := range plan {
		for _, a := range p.Actions {
			s, ok := a.(interface{ NeedsSudo() bool })
			if !ok || !s.NeedsSudo() {
				continue
			}
			done, err := a.Check()
			if err != nil {
				continue
			}
			if !done {
				return true
			}
		}
	}
	return false
}
