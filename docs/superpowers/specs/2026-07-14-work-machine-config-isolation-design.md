# Work-machine config isolation + generic WSL/CLI items

Date: 2026-07-14

## Problem

This machine is a work WSL/Ubuntu box. It accumulates Claude Code settings that
differ from the personal defaults on `main` (model pin, enabled plugins, feature
flags). Because `modules/ai` symlinks `~/.claude/settings.json` wholesale into the
tracked repo file, Claude Code's runtime writes go straight through the symlink and
show up as a dirty diff on `main`. Committing them would push per-machine
preferences to the personal (public) repo; not committing leaves the tree
permanently dirty.

A companion audit (handoff from the work-setup session) established that **no
sensitive work information belongs in dotfiles** — registry names, subscription
IDs, internal hosts, and credential-store tweaks all live in Claude project
memory instead. Everything actionable that touched dotfiles is generic. That
finding removes the justification for a work branch/fork: the branch would carry
only preference drift, at the cost of a permanent cherry-pick chore and a real
risk of accidentally pushing per-machine settings upstream.

## Goals

- Per-machine Claude settings that never dirty `main` and never push upstream,
  while generic edits to the shared defaults still flow to `main` normally.
- Land the generic WSL portability items from the handoff (wslview shim, WSL-only
  `BROWSER`, confirmed `~/.local/bin` on PATH, `jq`) on `main`, guarded so the
  config stays portable to non-WSL machines.
- No secrets in the repo. No branch/fork.

## Non-goals

- No branch/fork. Nothing sensitive lands in dotfiles, so a fork earns nothing.
- No secrets management. Sensitive work data stays in Claude memory.
- No separate work profile. The existing `wsl` profile plus a new `wsl` module
  cover it.
- Azure CLI (`az`) is explicitly out: the user does not want it saved to dotfiles.

## Design

### 1. Claude settings overlay (core change)

Split the monolithic settings file into a tracked base plus a per-machine local
overlay, deep-merged at apply time.

- **Base**: `modules/ai/files/claude/settings.json` (tracked) holds personal
  defaults and stays on `main`. It is no longer symlinked to `~/.claude`.
- **Local**: `~/.claude/settings.local.json` (per-machine, lives outside the
  repo) holds this machine's overrides. Nothing to `.gitignore` because the file
  never exists inside the repo tree.
- **Merge**: a new `modules/ai/install.sh` runs

  ```sh
  jq -s '.[0] * (.[1] // {})' "$base" "$local" > "$out"
  ```

  where the right operand defaults to `{}` when the local file is absent. `jq`'s
  `*` operator deep-merges objects and lets the local operand win on scalar
  conflicts, so `enabledPlugins`, `env`, and nested maps merge key-by-key while a
  local `model` overrides the base `model`.
- **Idempotency**: build the merged result into a temp file, compare against the
  existing `~/.claude/settings.json`, and replace only when they differ. Exit 0
  when already in the desired state. No sudo.
- Ship `modules/ai/files/claude/settings.local.json.example` documenting the
  overlay pattern for future machines.
- `CLAUDE.md`, `rules`, and `stacks` remain symlinks. Only `settings.json`
  becomes a generated file.

**Removing a plugin via overlay**: `jq` merge is additive for object keys, so the
local file cannot delete a base `enabledPlugins` entry. To disable a base plugin
on one machine, set it to `false` in the local overlay (Claude Code treats
`false` as disabled). Documented in the `.example`.

**Migration of the current dirty diff**: the uncommitted drift on this machine
(model `opus`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env, `alwaysThinkingEnabled`,
`skipWorkflowUsageWarning`, and the `atlassian` + `pr-review-toolkit` plugin
enables) moves into `~/.claude/settings.local.json`. The base file is restored to
`HEAD` (`git checkout -- modules/ai/files/claude/settings.json`), keeping personal
defaults (model `fable`, personal plugin set) untouched on `main`.

**Known trade-off**: Claude Code writes `~/.claude/settings.json` at runtime (UI,
`/config`). That is how the drift arose, through the symlink. Once the file is
generated rather than symlinked, `quill apply` reclobbers runtime UI edits from
`base * local`. Any keep-worthy runtime tweak must be copied into
`settings.local.json` by hand. This is the declarative-first contract quill
already applies to every other managed file.

### 2. New `wsl` module

A generic module (on `main`) selected only by the `wsl` profile. Carries the
WSL-only browser shim.

- `modules/wsl/module.toml`: `os = ["ubuntu"]`, no packages.
- `modules/wsl/install.sh` (WSL-guarded): when running under WSL
  (`grep -qiE microsoft /proc/version`) **and** no real `wslview` is on PATH,
  write the shim to `~/.local/bin/wslview` and `chmod +x`:

  ```sh
  #!/bin/sh
  # Minimal wslview: open URL/path in Windows default browser (wslu
  # unavailable on Ubuntu 26.04)
  exec powershell.exe -NoProfile -Command "Start-Process '$*'" </dev/null >/dev/null 2>&1
  ```

  Idempotent: skip when a real `wslview` exists (Ubuntu could restore `wslu`) or
  when the shim is already in place with matching content. Off WSL the script is a
  clean no-op.
- Add `"wsl"` to the `modules` list in `profiles/wsl.toml`.

Rationale for the WSL runtime guard on top of `os = ["ubuntu"]`: the module is
portable to any Ubuntu profile, and a bare-Ubuntu (non-WSL) machine must not get a
`powershell.exe` shim. The guard makes the module safe to keep on `main`.

### 3. `BROWSER` in the shared `.zshrc`

Add a WSL-guarded block to `modules/shell/files/.zshrc` (a single symlink shared
across all machines):

```zsh
if grep -qiE microsoft /proc/version 2>/dev/null; then
  export BROWSER=wslview
fi
```

Portable: a no-op off WSL. This supersedes the manual `~/.zshenv` line currently
set on this machine; that line is removed by the user after apply. No
dotfiles-owned `.zshenv` is introduced.

### 4. PATH

Already satisfied: `modules/shell/files/.zshrc:4` exports `~/.local/bin` onto
PATH, which the wslview shim depends on. No change; confirmed as a design
precondition.

### 5. `jq` dependency

Add `jq` to the `ai` module package lists (`pacman` and `apt`). Declarative
packages install before any `install.sh`, so the settings merge always has `jq`
available. `jq` is a generic tool, useful on every profile.

## Testing (TDD)

- `modules/ai/test_install.sh`:
  - local overlay overrides a base scalar (`model`);
  - deep-merge of a nested object (`enabledPlugins`, `env`) keeps base keys and
    adds/overrides local keys;
  - absent local file yields base verbatim;
  - second run is a no-op (idempotency: output unchanged, no rewrite).
- `modules/wsl/test_install.sh`:
  - shim written when the WSL guard matches and no `wslview` on PATH;
  - shim skipped when a real `wslview` is present;
  - script is a no-op when the WSL guard does not match.

Both follow the existing `modules/windows-terminal/test_install.sh` pattern
(fake `$HOME`/PATH/`/proc/version` via a temp root, run the script, assert on
files).

## Files touched

- `modules/ai/module.toml` — drop `settings.json` symlink; add `jq` to `pacman`
  and `apt` package lists.
- `modules/ai/install.sh` — new; jq overlay merge, idempotent.
- `modules/ai/files/claude/settings.local.json.example` — new; documents overlay.
- `modules/ai/files/claude/settings.json` — restored to `HEAD` (drift removed).
- `modules/ai/test_install.sh` — new.
- `modules/wsl/module.toml` — new.
- `modules/wsl/install.sh` — new.
- `modules/wsl/test_install.sh` — new.
- `modules/shell/files/.zshrc` — WSL-guarded `BROWSER` block.
- `profiles/wsl.toml` — add `"wsl"` module.
- `~/.claude/settings.local.json` — created on this machine (outside repo) with
  the migrated drift.

## Out of scope / follow-ups

- Promoting any of this machine's plugin enables (`atlassian`,
  `pr-review-toolkit`) into the personal base is a separate decision, left to the
  user.
