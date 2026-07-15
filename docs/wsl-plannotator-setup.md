# Plannotator setup on WSL

Goal: replicate the desktop machine's Plannotator setup (plan annotation UI for Claude Code) on this WSL/Ubuntu machine. The setup has four pieces; two arrive automatically through the dotfiles repo, two need manual steps here.

## Prerequisite (already done on the desktop, verify only)

The dotfiles repo's `modules/ai/files/claude/settings.json` and `CLAUDE.md` must contain the Plannotator entries (plugin enablement, marketplace, ExitPlanMode hook, "Plan review medium" section). These were committed and pushed from the desktop. Verify after pulling:

```bash
cd ~/dotfiles && git pull
grep -c plannotator modules/ai/files/claude/settings.json   # expect >= 3 matches
grep -c -i plannotator modules/ai/files/claude/CLAUDE.md    # expect >= 1 match
```

If either grep returns 0, stop and tell the user: the desktop changes were not pushed yet.

## Step 1: apply the ai module

```bash
cd ~/dotfiles
./bin/quill apply ai    # or: go build -o ./bin/quill ./cmd/quill first if binary is stale
```

This symlinks `~/.claude/settings.json` and `~/.claude/CLAUDE.md` to the dotfiles copies. Confirm:

```bash
readlink ~/.claude/settings.json   # should point into ~/dotfiles/modules/ai/files/claude/
```

That delivers:
- `extraKnownMarketplaces.plannotator` (github `backnotprop/plannotator`)
- `enabledPlugins."plannotator@plannotator": true`
- PostToolUse hook on `ExitPlanMode` that nudges Claude to open complex approved plans in Plannotator
- CLAUDE.md "Plan review medium" rule (open complex plans/design docs with `plannotator-annotate`, treat closed-without-suggestions as approval)

## Step 2: install the Plannotator CLI + skills

The official installer puts the binary in `~/.local/bin/plannotator` and drops three skills (`plannotator-annotate`, `plannotator-last`, `plannotator-review`) into `~/.claude/skills/`:

```bash
curl -fsSL https://plannotator.ai/install.sh | bash
```

Verify:

```bash
plannotator --version                      # desktop has 0.22.0; same or newer is fine
ls ~/.claude/skills/ | grep plannotator    # expect all three skill dirs
```

If `~/.local/bin` is not on PATH in zsh, fix that first (it should already be, via the shell module).

## Step 3: let Claude Code install the plugin

Restart Claude Code. On startup it should install `plannotator@plannotator` from the marketplace entry in settings.json. If it does not, run inside Claude Code:

```
/plugin install plannotator@plannotator
```

then restart again (plugin hooks only take effect after restart). The plugin provides the plan-mode hooks: `plannotator improve-context` on EnterPlanMode and the Plannotator UI on the ExitPlanMode permission request.

Confirm the plugin cache exists:

```bash
ls ~/.claude/plugins/cache/plannotator/plannotator/
```

## Step 4: WSL browser handling

Plannotator opens its UI in a browser. Test the happy path first:

```bash
echo "# test plan" > /tmp/pln-test.md
plannotator annotate /tmp/pln-test.md
```

Expected: Windows-side browser opens the Plannotator UI; closing the session returns a decision to the terminal.

If no browser opens, two options (try in order):

1. Install `wslu` (`sudo apt install wslu`) and point Plannotator at it:
   `export PLANNOTATOR_BROWSER=/usr/bin/wslview` (add to zsh env via the shell module's pattern, not a stray .zshrc edit).
2. Fall back to remote mode: `export PLANNOTATOR_REMOTE=1` (fixed port 19432, prints a URL to open manually; override port with `PLANNOTATOR_PORT` if it collides).

If an env var is needed, ask the user whether to add it to the dotfiles-managed shell config so it persists, rather than editing generated files directly.

## Step 5: end-to-end verification

1. In a Claude Code session, enter plan mode on a toy task and approve a plan: the plugin's ExitPlanMode hook should open the Plannotator UI.
2. Invoke `/plannotator-annotate /tmp/pln-test.md` and confirm annotations round-trip back into the session.
3. Confirm the CLAUDE.md rule loaded: ask Claude how it should present a complex plan; it should mention opening Plannotator automatically.

Clean up `/tmp/pln-test.md` when done.

## Out of scope

- Do not edit `modules/ai/files/claude/settings.json` on this machine; it is shared across machines and owned by the dotfiles repo (change on desktop, or commit here only if the user asks).
- No other plugins/marketplaces from the desktop (caveman etc.) are part of this task.
