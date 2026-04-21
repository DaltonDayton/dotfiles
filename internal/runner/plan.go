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

// PlanNeedsSudo reports whether any action in the plan will invoke a
// privileged command. Actions opt in by implementing a NeedsSudo() method;
// the structural interface here avoids adding it to the core Action
// contract since most action types never need root.
func PlanNeedsSudo(plan []ModulePlan) bool {
	for _, p := range plan {
		for _, a := range p.Actions {
			if s, ok := a.(interface{ NeedsSudo() bool }); ok && s.NeedsSudo() {
				return true
			}
		}
	}
	return false
}
