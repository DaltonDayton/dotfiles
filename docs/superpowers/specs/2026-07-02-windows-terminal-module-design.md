# Windows Terminal module design

Date: 2026-07-02

## Goal

Give quill an optional `windows-terminal` module that reproduces the quill
terminal aesthetic (Catppuccin Mocha colors, CaskaydiaCove Nerd Font at 11pt,
25px padding, 90% opacity, focus mode / no tab bar) inside the user's Windows
Terminal, when quill runs under WSL. Focus mode is a deliberate feature: it
hides the tab bar *and* the title bar, giving a bare, chrome-free window that is
the closest Windows Terminal gets to a stripped kitty window. The module also
installs the CaskaydiaCove Nerd Font on the Windows host (per-user, no admin) so
the configured font actually renders. The module mirrors the look currently set
in kitty on the Arch profiles (`modules/hyprland/files/kitty/kitty.conf` +
`modules/hyprland/files/themes/catppuccin/kitty.conf`).

## Scope

**In:** a single self-contained module that idempotently merges a fixed set of
Windows Terminal settings into the user's existing `settings.json`, preserving
everything else in that file. Catppuccin Mocha only (no theme switcher, no
porting of the other kitty themes).

**Out:** live theme switching, multiple selectable schemes, unpackaged/portable
Windows Terminal installs, and system-wide (all-users) font installation. The
font is installed per-user only, which needs no admin.

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

[[packages]]
manager = "apt"
names = ["curl", "unzip"]
```

The `curl`/`unzip` packages are the only declarative work; they are the tools
the font-download step needs. Everything else happens in `install.sh`.
`os = ["ubuntu"]` gates the module out of the Arch profiles in the install
picker; the script additionally self-skips when Windows Terminal is not present,
covering bare (non-WSL) Ubuntu. Because declarative actions run before any
`install.sh`, `curl` and `unzip` are guaranteed present when the script runs.

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
   and `exit 0`. Derive the Windows user directory (`/mnt/c/Users/<user>`) from
   the matched path; both the font install and the settings merge reuse it.
2. **Install font (per-user, no admin).** Target dir
   `<winuser>/AppData/Local/Microsoft/Windows/Fonts`. Weights installed:
   `CaskaydiaCoveNerdFont-Regular.ttf`, `-Bold.ttf`, `-Italic.ttf`,
   `-BoldItalic.ttf`.
   - **Idempotency:** if all four `.ttf` already exist in the target dir, skip
     the whole step (print `windows-terminal: font already installed.`).
   - **Download:** `curl -fL` the pinned release
     `https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/CascadiaCode.zip`
     into a `mktemp -d` working dir; `unzip` it there. `NERD_FONTS_VERSION` is a
     shell constant at the top of the script (initially `3.2.1`) so bumping the
     font is a one-line edit.
   - **Copy:** copy the four weights into the target dir (create it if missing).
   - **Register:** for each weight, run Windows interop
     `reg.exe add "HKCU\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts"
     /v "CaskaydiaCove NF <Weight> (TrueType)" /t REG_SZ /d
     "C:\\Users\\<user>\\AppData\\Local\\Microsoft\\Windows\\Fonts\\<file>.ttf"
     /f`. `reg.exe add /f` is itself idempotent. If `reg.exe` is not on `PATH`
     (interop disabled), print a warning telling the user to enable WSL interop
     or install the font manually, but do not fail the run — the fonts are
     already copied and will register on next login.
   - Clean up the temp dir.
3. **Merge (python3).** Invoke `python3` with the merge logic, passing the
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
4. **Idempotency + backup.** Compare the serialized result to the current file
   contents. If identical, print `windows-terminal: already up to date.` and
   `exit 0` with no write. If different, write `settings.json.quill-backup`
   once (only if it does not already exist), then overwrite `settings.json`.

The in-memory compare is what makes reruns a genuine no-op, satisfying quill's
idempotency contract for `install.sh` scripts.

## Data flow

```
module.toml (os gate, curl+unzip)
      |
   install.sh
      |  glob -> settings.json path + winuser dir   (skip if none)
      |
      |  font: 4 ttf present? --yes--> skip
      |         --no--> curl CascadiaCode.zip, unzip, copy, reg.exe register
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
- **Font download fails** (network, 404 on a bumped version): `curl -f` returns
  non-zero -> `set -e` fails the run loud, so a broken `NERD_FONTS_VERSION` is
  caught immediately rather than silently skipping the font.
- **`reg.exe` absent** (interop disabled): warn, continue. Fonts are copied and
  will register on next Windows login; the settings merge still proceeds.
- Everything else (write errors, permission issues on `/mnt/c`) propagates as a
  non-zero exit from `set -e`.

## Testing

Consistent with the project: `install.sh` scripts are not covered by Go unit
tests; their contract is self-checked idempotency. Verification is manual:

1. `./bin/quill apply windows-terminal` on the WSL box — confirm the Catppuccin
   scheme, font, padding, opacity, and focus mode apply in a fresh Windows
   Terminal tab.
2. Confirm the four CaskaydiaCove weights land in the Windows per-user Fonts
   dir and the font appears in Windows Terminal's font dropdown.
3. Rerun `./bin/quill apply windows-terminal` — confirm it prints "font already
   installed" and "already up to date" and writes nothing (`settings.json` mtime
   unchanged, no re-download).
4. Confirm the user's existing keybindings/profiles survive the merge.
5. On a non-WSL Ubuntu (or by hiding `/mnt/c`), confirm the clean skip path.

## Wiring

Add `windows-terminal` to the `modules` list in `profiles/wsl.toml`.

## Caveats

- The font install is per-user (`HKCU` + LOCALAPPDATA Fonts), so it needs no
  admin but only affects the current Windows user. System-wide install is out of
  scope.
- `NERD_FONTS_VERSION` is pinned in the script. Bumping it re-downloads on the
  next run only if the four weights are missing; changing the version alone does
  not force a refresh of already-installed files. To force a re-pull, delete the
  weights from the Fonts dir.
- Only packaged (Store/winget) Windows Terminal is handled. Portable/unpackaged
  installs store settings elsewhere and are out of scope; they hit the clean
  skip path.
- Font registration relies on WSL interop (`reg.exe`). With interop disabled the
  fonts still copy but register only on next Windows login.
