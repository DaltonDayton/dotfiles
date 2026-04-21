# dotfiles

Arch Linux machine setup managed by [`quill`](./cmd/quill), a Go CLI that declaratively
installs packages, links configs, enables services, and applies host-specific tweaks
via a Charm-powered TUI.

See `docs/superpowers/specs/2026-04-21-quill-design.md` for the design
and `docs/superpowers/plans/2026-04-21-quill-implementation.md` for the implementation plan.

## Bootstrap (on a fresh Arch install)

```sh
curl -fsSL https://raw.githubusercontent.com/DaltonDayton/dotfiles/main/bootstrap.sh | bash
```

(Not yet published — see the plan for current status.)
