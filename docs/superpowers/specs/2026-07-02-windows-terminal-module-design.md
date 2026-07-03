# Windows Terminal module design

Date: 2026-07-02

## Goal

Give quill an optional `windows-terminal` module that reproduces the quill
terminal aesthetic (Catppuccin Mocha colors, CaskaydiaCove Nerd Font at 11pt,
25px padding, 90% opacity, focus mode / no tab bar) inside the user's Windows
Terminal, when quill runs under WSL. The module mirrors the look currently set
in kitty on the Arch profiles (`modules/hyprland/files/kitty/kitty.conf` +
`modules/hyprland/files/themes/catppuccin/kitty.conf`).

## Scope

**In:** a single self-contained module that idempotently merges a fixed set of
Windows Terminal settings into the user's existing `settings.json`, preserving
everything else in that file. Catppuccin Mocha only (no theme switcher, no
porting of the other kitty themes).

**Out:** live theme switching, multiple selectable schemes, unpackaged/portable
Windows Terminal installs, and any Windows-side font installation (quill runs in
WSL and cannot reach the Windows font store; a todo reminds the user).

## Why an `install.sh`, not declarative actions

Windows Terminal's `settings.json` cannot be managed by quill's symlink or file
actions for three reasons:

1. **Dynamic path.** It lives at
   `/mnt/c/Users/<user>/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json`
   — the username and the package identity are not known ahead of time.
2. **User-owned content.** The file already holds the user's keybindings,
   profiles, and actions. We must merge into it, never own or overwrite it.
3. **Structural merge.** `schemes` is a JSON array keyed by scheme `name`
   (upsert semantics) and `profiles.defaults` is an object (key-override
   semantics). Neither is expressible in TOML.

This is exactly the "declarative doesn't fit, drop into `install.sh`" escape
hatch described in the project conventions. The script self-checks for
idempotency and exits 0 when already applied.

## Components

### `modules/windows-terminal/module.toml`

```toml
name = "windows-terminal"
description = "Catppuccin + quill aesthetic for Windows Terminal (WSL)"
os = ["ubuntu"]

[[todos]]
message = "Install 'CaskaydiaCove Nerd Font' on the Windows host (not WSL) so Windows Terminal can render it. Download: https://github.com/ryanoasis/nerd-fonts/releases (CascadiaCode)."
```

The module declares no packages/symlinks/files/commands — all work happens in
`install.sh`. `os = ["ubuntu"]` gates it out of the Arch profiles in the install
picker; the script additionally self-skips when Windows Terminal is not present,
covering bare (non-WSL) Ubuntu.

The `[[todos]]` has no `check` (there is no reliable way to query the Windows
font store from WSL), so it always prints as a reminder after a run.

### `modules/windows-terminal/files/wt-fragment.json`

The data merged into `settings.json`, shaped to mirror its structure so the
merge is a plain structural combine:

```json
{
  "launchMode": "focus",
  "profiles": {
    "defaults": {
      "font": { "face": "CaskaydiaCove Nerd Font", "size": 11 },
      "colorScheme": "Catppuccin Mocha",
      "padding": "25",
      "opacity": 90,
      "useAcrylic": false,
      "cursorShape": "bar",
      "antialiasingMode": "grayscale"
    }
  },
  "schemes": [
    {
      "name": "Catppuccin Mocha",
      "background": "#1E1E2E",
      "foreground": "#CDD6F4",
      "cursorColor": "#F5E0DC",
      "selectionBackground": "#F5E0DC",
      "black": "#45475A",
      "red": "#F38BA8",
      "green": "#A6E3A1",
      "yellow": "#F9E2AF",
      "blue": "#89B4FA",
      "purple": "#F5C2E7",
      "cyan": "#94E2D5",
      "white": "#BAC2DE",
      "brightBlack": "#585B70",
      "brightRed": "#F38BA8",
      "brightGreen": "#A6E3A1",
      "brightYellow": "#F9E2AF",
      "brightBlue": "#89B4FA",
      "brightPurple": "#F5C2E7",
      "brightCyan": "#94E2D5",
      "brightWhite": "#A6ADC8"
    }
  ]
}
```

Colors are transcribed from `modules/hyprland/files/themes/catppuccin/kitty.conf`.
The `color0..color15` -> WT `black/red/.../brightWhite` mapping:

| kitty | WT | hex |
|---|---|---|
| color0  | black        | #45475A |
| color1  | red          | #F38BA8 |
| color2  | green        | #A6E3A1 |
| color3  | yellow       | #F9E2AF |
| color4  | blue         | #89B4FA |
| color5  | purple       | #F5C2E7 |
| color6  | cyan         | #94E2D5 |
| color7  | white        | #BAC2DE |
| color8  | brightBlack  | #585B70 |
| color9  | brightRed    | #F38BA8 |
| color10 | brightGreen  | #A6E3A1 |
| color11 | brightYellow | #F9E2AF |
| color12 | brightBlue   | #89B4FA |
| color13 | brightPurple | #F5C2E7 |
| color14 | brightCyan   | #94E2D5 |
| color15 | brightWhite  | #A6ADC8 |

Keeping the fragment as data (not inline in the script) makes the values easy to
read and edit without touching merge logic.

### `modules/windows-terminal/install.sh`

Executable, `set -euo pipefail`. Flow:

1. **Locate.** Glob
   `/mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState/settings.json`.
   Prefer a path without `Preview` in the package name; take the first match.
   No match -> print `windows-terminal: Windows Terminal not found, skipping.`
   and `exit 0`.
2. **Merge (python3).** Invoke `python3` with the merge logic, passing the
   fragment path and the settings path. python3 is already a quill dependency
   (used elsewhere), so no new package. The merge:
   - Loads both files. If the existing `settings.json` is not valid JSON, print
     an error to stderr and `exit 1` (fail loud, never clobber a file we cannot
     parse).
   - Deep-merges `profiles.defaults`: fragment keys override, sibling keys in
     the user's `defaults` are preserved.
   - Sets top-level `launchMode` from the fragment.
   - Upserts each fragment scheme into `schemes[]` by `name` (replace an
     existing entry with the same name, else append). Other schemes are left
     untouched.
   - Serializes the result with 4-space indent.
3. **Idempotency + backup.** Compare the serialized result to the current file
   contents. If identical, print `windows-terminal: already up to date.` and
   `exit 0` with no write. If different, write `settings.json.quill-backup`
   once (only if it does not already exist), then overwrite `settings.json`.

The in-memory compare is what makes reruns a genuine no-op, satisfying quill's
idempotency contract for `install.sh` scripts.

## Data flow

```
module.toml (os gate, todo)
      |
   install.sh
      |  glob -> settings.json path      (skip if none)
      v
   python3 merge(fragment, settings.json)
      |  parse both, deep-merge defaults, upsert scheme, set launchMode
      |  compare result vs current
      +--> identical  -> exit 0 (no write)
      +--> different   -> backup once, write settings.json
```

## Error handling

- **WT absent** (glob empty): informational skip, `exit 0`. Not an error — a bare
  Ubuntu box legitimately has no Windows Terminal.
- **Unparseable existing settings.json**: `exit 1` with a stderr message. We do
  not overwrite a file we could not read, to avoid destroying hand edits.
- **Missing fragment file**: `exit 1` (packaging bug, should fail loud).
- Everything else (write errors, permission issues on `/mnt/c`) propagates as a
  non-zero exit from `set -e`.

## Testing

Consistent with the project: `install.sh` scripts are not covered by Go unit
tests; their contract is self-checked idempotency. Verification is manual:

1. `./bin/quill apply windows-terminal` on the WSL box — confirm the Catppuccin
   scheme, font, padding, opacity, and focus mode apply in a fresh Windows
   Terminal tab.
2. Rerun `./bin/quill apply windows-terminal` — confirm it prints
   "already up to date" and writes nothing (`settings.json` mtime unchanged).
3. Confirm the user's existing keybindings/profiles survive the merge.
4. On a non-WSL Ubuntu (or by hiding `/mnt/c`), confirm the clean skip path.

## Wiring

Add `windows-terminal` to the `modules` list in `profiles/wsl.toml`.

## Caveats

- The CaskaydiaCove Nerd Font must be installed on the Windows host; quill cannot
  do this from WSL. Surfaced via the module todo.
- Only packaged (Store/winget) Windows Terminal is handled. Portable/unpackaged
  installs store settings elsewhere and are out of scope; they hit the clean
  skip path.
- Windows Terminal focus mode hides the tab bar and the title bar together; there
  is no WT option to hide only the tabs. This is a WT limitation, not a module
  choice.
