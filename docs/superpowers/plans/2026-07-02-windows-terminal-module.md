# Windows Terminal Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional `windows-terminal` quill module that, under WSL, installs the CaskaydiaCove Nerd Font per-user on Windows and merges the quill terminal aesthetic (Catppuccin Mocha, font 11, padding 25, opacity 90, focus mode) into the user's existing Windows Terminal `settings.json` non-destructively and idempotently.

**Architecture:** A declarative `module.toml` (apt `curl`/`unzip` only) plus an `install.sh` escape hatch. install.sh locates the Windows Terminal settings file on `/mnt/c`, installs the font via `reg.exe` interop, then delegates the JSON merge to a small, independently testable `wt-merge.py`. Idempotency is a self-check: recompute the target file in memory and skip the write when unchanged.

**Tech Stack:** Bash (install.sh), python3 (JSON merge, already a quill dependency), Windows interop (`reg.exe`), curl/unzip.

## Global Constraints

- Module gates to `os = ["ubuntu"]`; install.sh additionally self-skips (`exit 0`) when Windows Terminal is not found under `/mnt/c`.
- install.sh: `#!/usr/bin/env bash`, `set -euo pipefail`, must be `chmod +x` (quill does not chmod it).
- install.sh runs with cwd = module dir; locate siblings via `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`.
- Never overwrite an existing `settings.json` we cannot parse — fail loud (`exit 1`).
- Backup file name: `settings.json.quill-backup`, written once, only when a change is actually made, only if it does not already exist.
- Pinned font release: `NERD_FONTS_VERSION=3.2.1`, asset `CascadiaCode.zip`.
- Font is per-user: files in `<winuser>/AppData/Local/Microsoft/Windows/Fonts`, registry under `HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts`.
- Catppuccin Mocha colors are transcribed verbatim from `modules/hyprland/files/themes/catppuccin/kitty.conf`.
- Writing style: no emojis, no em-dashes (project convention).

---

## File Structure

- `modules/windows-terminal/module.toml` — module metadata, os gate, apt `curl`/`unzip`.
- `modules/windows-terminal/files/wt-fragment.json` — the settings we merge in (scheme + defaults + launchMode). Pure data.
- `modules/windows-terminal/files/wt-merge.py` — structural JSON merge (deep-merge defaults, upsert scheme, set launchMode). The one piece with real logic, so the one piece with a test.
- `modules/windows-terminal/test_merge.sh` — shell test harness for `wt-merge.py` using tmpdir fixtures. Not read by quill; run by hand / in the task.
- `modules/windows-terminal/install.sh` — orchestration: locate, font install, merge, backup.
- `profiles/wsl.toml` — add `windows-terminal` to the modules list.

---

## Task 1: Module scaffold and profile wiring

**Files:**
- Create: `modules/windows-terminal/module.toml`
- Create: `modules/windows-terminal/files/wt-fragment.json`
- Modify: `profiles/wsl.toml` (add module to list)

**Interfaces:**
- Produces: `files/wt-fragment.json` with top-level keys `launchMode` (string), `profiles.defaults` (object), `schemes` (array of scheme objects). Consumed by `wt-merge.py` in Task 2 and `install.sh` in Task 4.

- [ ] **Step 1: Write `module.toml`**

```toml
name = "windows-terminal"
description = "Catppuccin + quill aesthetic for Windows Terminal (WSL)"
os = ["ubuntu"]

[[packages]]
manager = "apt"
names = ["curl", "unzip"]
```

- [ ] **Step 2: Write `files/wt-fragment.json`**

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

- [ ] **Step 3: Verify the fragment is valid JSON**

Run: `python3 -m json.tool modules/windows-terminal/files/wt-fragment.json > /dev/null && echo OK`
Expected: `OK`

- [ ] **Step 4: Add the module to the WSL profile**

In `profiles/wsl.toml`, change the modules line to include `windows-terminal`:

```toml
modules = ["git", "shell", "tmux", "neovim", "ai", "python", "asdf", "windows-terminal"]
```

- [ ] **Step 5: Verify quill parses and lists the module**

Run: `go build -o ./bin/quill ./cmd/quill && ./bin/quill list`
Expected: build succeeds; output includes a `windows-terminal` module line with no parse error.

- [ ] **Step 6: Commit**

```bash
git add modules/windows-terminal/module.toml modules/windows-terminal/files/wt-fragment.json profiles/wsl.toml
git commit -m "feat(windows-terminal): module scaffold and profile wiring"
```

---

## Task 2: JSON merge script with tests

**Files:**
- Create: `modules/windows-terminal/files/wt-merge.py`
- Create: `modules/windows-terminal/test_merge.sh`

**Interfaces:**
- Consumes: `files/wt-fragment.json` shape from Task 1.
- Produces: CLI `python3 wt-merge.py <fragment.json> <settings.json>`. Behavior: prints the merged settings JSON (4-space indent) to stdout; exits 0. On unparseable `<settings.json>`: prints an error to stderr, exits 1. Merge rules: deep-merge `profiles.defaults` (fragment keys win, siblings preserved), upsert each `schemes[]` entry by `name`, set top-level `launchMode`. install.sh (Task 4) captures stdout and compares it to the current file to decide whether to write.

- [ ] **Step 1: Write the failing test harness `test_merge.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERGE="$SCRIPT_DIR/files/wt-merge.py"
FRAGMENT="$SCRIPT_DIR/files/wt-fragment.json"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Fixture: an existing settings.json with user content that must survive.
cat > "$tmp/settings.json" <<'JSON'
{
    "copyOnSelect": true,
    "keybindings": [ { "id": "User.find", "keys": "ctrl+shift+f" } ],
    "profiles": {
        "defaults": { "font": { "face": "Consolas" }, "cursorShape": "vintage" },
        "list": [ { "name": "PowerShell" } ]
    },
    "schemes": [ { "name": "Campbell", "background": "#0C0C0C" } ]
}
JSON

out="$(python3 "$MERGE" "$FRAGMENT" "$tmp/settings.json")"

# 1. User keys preserved.
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["copyOnSelect"] is True; assert d["keybindings"][0]["keys"]=="ctrl+shift+f"; assert any(p.get("name")=="PowerShell" for p in d["profiles"]["list"])'
# 2. defaults deep-merged: our keys win, unrelated user default preserved is NOT required (cursorShape is one of ours -> overridden to "bar"), but list survives.
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); dd=d["profiles"]["defaults"]; assert dd["font"]["face"]=="CaskaydiaCove Nerd Font"; assert dd["font"]["size"]==11; assert dd["colorScheme"]=="Catppuccin Mocha"; assert dd["cursorShape"]=="bar"'
# 3. launchMode set.
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["launchMode"]=="focus"'
# 4. scheme upserted, existing Campbell untouched, no duplicate Catppuccin.
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); names=[s["name"] for s in d["schemes"]]; assert names.count("Catppuccin Mocha")==1; assert "Campbell" in names; m=[s for s in d["schemes"] if s["name"]=="Catppuccin Mocha"][0]; assert m["background"]=="#1E1E2E"'

# 5. Re-running on the merged output is a no-op (idempotent).
echo "$out" > "$tmp/merged.json"
out2="$(python3 "$MERGE" "$FRAGMENT" "$tmp/merged.json")"
[ "$out" = "$out2" ] || { echo "FAIL: merge not idempotent"; exit 1; }

# 6. Unparseable settings.json fails loud.
echo "{ not json" > "$tmp/bad.json"
if python3 "$MERGE" "$FRAGMENT" "$tmp/bad.json" 2>/dev/null; then echo "FAIL: bad json did not error"; exit 1; fi

echo "ALL MERGE TESTS PASSED"
```

- [ ] **Step 2: Make the test executable and run it to verify it fails**

Run: `chmod +x modules/windows-terminal/test_merge.sh && ./modules/windows-terminal/test_merge.sh`
Expected: FAIL — `wt-merge.py` does not exist yet (python error "can't open file ... wt-merge.py").

- [ ] **Step 3: Write `files/wt-merge.py`**

```python
#!/usr/bin/env python3
"""Merge a Windows Terminal settings fragment into an existing settings.json.

Deep-merges profiles.defaults (fragment keys win), upserts schemes[] by name,
and sets top-level launchMode. Prints the merged JSON to stdout. Never mutates
the input file; install.sh decides whether to write the result.
"""
import json
import sys


def deep_merge(base, overlay):
    for key, val in overlay.items():
        if isinstance(val, dict) and isinstance(base.get(key), dict):
            deep_merge(base[key], val)
        else:
            base[key] = val
    return base


def upsert_schemes(settings, schemes):
    existing = settings.setdefault("schemes", [])
    by_name = {s.get("name"): i for i, s in enumerate(existing) if isinstance(s, dict)}
    for scheme in schemes:
        name = scheme.get("name")
        if name in by_name:
            existing[by_name[name]] = scheme
        else:
            existing.append(scheme)


def main():
    fragment_path, settings_path = sys.argv[1], sys.argv[2]
    with open(fragment_path) as f:
        fragment = json.load(f)
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except (json.JSONDecodeError, ValueError) as err:
        print(f"wt-merge: {settings_path} is not valid JSON: {err}", file=sys.stderr)
        sys.exit(1)

    if "profiles" in fragment:
        deep_merge(settings.setdefault("profiles", {}), fragment["profiles"])
    if "launchMode" in fragment:
        settings["launchMode"] = fragment["launchMode"]
    if "schemes" in fragment:
        upsert_schemes(settings, fragment["schemes"])

    print(json.dumps(settings, indent=4))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./modules/windows-terminal/test_merge.sh`
Expected: `ALL MERGE TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add modules/windows-terminal/files/wt-merge.py modules/windows-terminal/test_merge.sh
git commit -m "feat(windows-terminal): JSON merge script with tests"
```

---

## Task 3: Font install helper

**Files:**
- Create: `modules/windows-terminal/install.sh` (partial — font logic + locate; merge wired in Task 4)

**Interfaces:**
- Produces: within install.sh, a `locate_settings()` that echoes the settings.json path (empty if none) and an `install_font()` that takes the Windows user dir. Task 4 adds the merge + backup tail to the same file.

- [ ] **Step 1: Write `install.sh` with the locate + font-install logic**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NERD_FONTS_VERSION="3.2.1"
FONT_WEIGHTS=(Regular Bold Italic BoldItalic)

# Echo the packaged Windows Terminal settings.json path, preferring a
# non-Preview install. Empty output = not found.
locate_settings() {
  local match preview=""
  for match in /mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState/settings.json; do
    [ -e "$match" ] || continue
    if [[ "$match" == *Preview* ]]; then
      preview="$match"
    else
      echo "$match"
      return 0
    fi
  done
  [ -n "$preview" ] && echo "$preview"
}

# $1 = Windows user dir (/mnt/c/Users/<user>). Installs the four CaskaydiaCove
# weights per-user and registers them via reg.exe. Idempotent.
install_font() {
  local winuser_dir="$1"
  local fonts_dir="$winuser_dir/AppData/Local/Microsoft/Windows/Fonts"
  local win_user_name w file
  win_user_name="$(basename "$winuser_dir")"

  local all_present=1
  for w in "${FONT_WEIGHTS[@]}"; do
    [ -f "$fonts_dir/CaskaydiaCoveNerdFont-$w.ttf" ] || all_present=0
  done
  if [ "$all_present" -eq 1 ]; then
    echo "windows-terminal: font already installed."
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  echo "windows-terminal: downloading CascadiaCode nerd font v$NERD_FONTS_VERSION..."
  curl -fL -o "$tmp/CascadiaCode.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v$NERD_FONTS_VERSION/CascadiaCode.zip"
  unzip -o -q "$tmp/CascadiaCode.zip" -d "$tmp/extract"

  mkdir -p "$fonts_dir"
  for w in "${FONT_WEIGHTS[@]}"; do
    file="CaskaydiaCoveNerdFont-$w.ttf"
    cp -f "$tmp/extract/$file" "$fonts_dir/$file"
    if command -v reg.exe >/dev/null 2>&1; then
      reg.exe add "HKCU\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" \
        /v "CaskaydiaCove NF $w (TrueType)" /t REG_SZ \
        /d "C:\\Users\\$win_user_name\\AppData\\Local\\Microsoft\\Windows\\Fonts\\$file" \
        /f >/dev/null
    fi
  done
  if ! command -v reg.exe >/dev/null 2>&1; then
    echo "windows-terminal: reg.exe not found (WSL interop disabled); fonts copied, will register on next Windows login." >&2
  fi
  echo "windows-terminal: font installed."
}

main() {
  local settings
  settings="$(locate_settings)"
  if [ -z "$settings" ]; then
    echo "windows-terminal: Windows Terminal not found, skipping."
    exit 0
  fi

  # /mnt/c/Users/<user> is the 5th path component: /, mnt, c, Users, <user>.
  local winuser_dir
  winuser_dir="$(echo "$settings" | cut -d/ -f1-5)"

  install_font "$winuser_dir"
}

main "$@"
```

- [ ] **Step 2: Make it executable and shellcheck it**

Run: `chmod +x modules/windows-terminal/install.sh && shellcheck modules/windows-terminal/install.sh`
Expected: no errors. (If `shellcheck` is not installed, skip with `command -v shellcheck` and note it; the bash `-n` syntax check below is the fallback.)

- [ ] **Step 3: Syntax-check the script**

Run: `bash -n modules/windows-terminal/install.sh && echo OK`
Expected: `OK`

- [ ] **Step 4: Verify the skip path on a machine without Windows Terminal**

Run: `modules/windows-terminal/install.sh`
Expected (when `/mnt/c` has no WT, e.g. this dev box): `windows-terminal: Windows Terminal not found, skipping.` and exit 0.

- [ ] **Step 5: Commit**

```bash
git add modules/windows-terminal/install.sh
git commit -m "feat(windows-terminal): locate settings and per-user font install"
```

---

## Task 4: Wire the merge, backup, and idempotency into install.sh

**Files:**
- Modify: `modules/windows-terminal/install.sh` (extend `main` with the merge tail)

**Interfaces:**
- Consumes: `wt-merge.py` (Task 2), `wt-fragment.json` (Task 1), `install_font`/`locate_settings` (Task 3).
- Produces: the complete install.sh. Running it applies font + settings and is a no-op on rerun.

- [ ] **Step 1: Extend `main()` with the merge, compare, backup, and write**

Replace the `install_font "$winuser_dir"` line at the end of `main` with:

```bash
  install_font "$winuser_dir"

  # Merge our fragment into the existing settings.json. wt-merge.py fails
  # loud (exit 1) if the existing file is not valid JSON, so set -e aborts
  # before we touch anything.
  local merged
  merged="$(python3 "$SCRIPT_DIR/files/wt-merge.py" "$SCRIPT_DIR/files/wt-fragment.json" "$settings")"

  if [ "$merged" = "$(cat "$settings")" ]; then
    echo "windows-terminal: already up to date."
    exit 0
  fi

  local backup="$settings.quill-backup"
  [ -f "$backup" ] || cp "$settings" "$backup"
  printf '%s\n' "$merged" > "$settings"
  echo "windows-terminal: settings.json updated (backup at $backup)."
```

- [ ] **Step 2: Syntax-check**

Run: `bash -n modules/windows-terminal/install.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Integration test the merge tail against a fake settings tree**

This exercises locate + merge + backup + idempotency without needing real Windows Terminal, by faking the `/mnt/c` path under a tmpdir and pointing the glob at it. Run:

```bash
tmp="$(mktemp -d)"
fake="$tmp/mnt/c/Users/tester/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
mkdir -p "$fake"
cat > "$fake/settings.json" <<'JSON'
{ "copyOnSelect": true, "profiles": { "defaults": { "font": { "face": "Consolas" } } }, "schemes": [] }
JSON
# Drive the merge tail directly (bypass locate/font, which need real /mnt/c):
merged="$(python3 modules/windows-terminal/files/wt-merge.py modules/windows-terminal/files/wt-fragment.json "$fake/settings.json")"
[ -f "$fake/settings.json.quill-backup" ] || cp "$fake/settings.json" "$fake/settings.json.quill-backup"
printf '%s\n' "$merged" > "$fake/settings.json"
# Assert: user key survived, scheme added, backup exists.
python3 -c 'import json;d=json.load(open("'"$fake"'/settings.json"));assert d["copyOnSelect"] is True;assert any(s["name"]=="Catppuccin Mocha" for s in d["schemes"]);assert d["launchMode"]=="focus";print("INTEGRATION OK")'
test -f "$fake/settings.json.quill-backup" && echo "BACKUP OK"
# Rerun merge -> identical (idempotent).
m2="$(python3 modules/windows-terminal/files/wt-merge.py modules/windows-terminal/files/wt-fragment.json "$fake/settings.json")"
[ "$m2" = "$(cat "$fake/settings.json")" ] && echo "IDEMPOTENT OK"
rm -rf "$tmp"
```

Expected: `INTEGRATION OK`, `BACKUP OK`, `IDEMPOTENT OK`.

- [ ] **Step 4: Re-run the merge unit tests to confirm nothing regressed**

Run: `./modules/windows-terminal/test_merge.sh`
Expected: `ALL MERGE TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add modules/windows-terminal/install.sh
git commit -m "feat(windows-terminal): merge settings with backup and idempotency"
```

---

## Task 5: End-to-end smoke on WSL

**Files:** none (verification only).

This task must run on the actual WSL box with Windows Terminal installed. It is the real acceptance check; the earlier tasks used fakes.

- [ ] **Step 1: Build and apply**

Run: `go build -o ./bin/quill ./cmd/quill && ./bin/quill apply windows-terminal`
Expected: curl/unzip present (declarative), font downloads and installs, settings.json updated with a backup reported.

- [ ] **Step 2: Verify the look in Windows Terminal**

Open a new Windows Terminal tab. Confirm: Catppuccin Mocha colors, CaskaydiaCove Nerd Font, 25px padding, ~90% opacity, focus mode (no tab bar / title bar).

- [ ] **Step 3: Verify idempotent rerun**

Run: `./bin/quill apply windows-terminal`
Expected: `windows-terminal: font already installed.` and `windows-terminal: already up to date.` No re-download, `settings.json` unchanged.

- [ ] **Step 4: Verify user content survived**

Inspect `settings.json`: pre-existing keybindings, actions, and profiles from before the run are still present; a `settings.json.quill-backup` sits beside it.

- [ ] **Step 5: (No commit)** Verification only. If any step failed, file the fix against the relevant earlier task.
