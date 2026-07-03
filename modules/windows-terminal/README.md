# windows-terminal module

Catppuccin + quill aesthetic for **Windows Terminal**, applied from WSL. `os = ["ubuntu"]`.

Unlike other modules, this one reaches across the WSL boundary and mutates a file
**Windows owns**: your Windows Terminal `settings.json`. Behavior is idempotent and
non-destructive, but worth knowing since it edits state outside the Linux side.

## What `install.sh` does

1. **Locates** the packaged settings.json under `/mnt/c/Users/*/.../WindowsTerminal*/LocalState/`.
   Prefers a non-Preview install. Not found (no mount / not installed) → skips cleanly, exit 0.
2. **Installs the font**: downloads CaskaydiaCove Nerd Font (Cascadia Code, v3.2.1), copies the
   four weights into the Windows user font dir, and registers them via `reg.exe`. Skips if all
   four are already present. If `reg.exe` is missing (WSL interop off), fonts are copied and
   register on next Windows login.
3. **Merges** `files/wt-fragment.json` into your settings via `files/wt-merge.py`:
   deep-merges `profiles.defaults` (fragment wins), upserts `schemes[]` by name, sets
   `launchMode`. Your other profiles, keybinds, and settings are untouched.

## Safety

- **Backup:** first write copies the original to `settings.json.quill-backup` (only once, never overwritten).
- **Idempotent:** if the merged result equals the current file, it writes nothing.
- **Fails loud:** if your existing settings.json is not valid JSON, the merge aborts (exit 1)
  before anything is touched. Windows Terminal permits `//` comments (JSONC); the merger uses
  strict JSON, so a comment-laden settings.json will abort. Strip comments, or let Windows
  Terminal rewrite the file once, then rerun.

## Restore

```sh
cp "$SETTINGS.quill-backup" "$SETTINGS"   # $SETTINGS = the located settings.json
```
