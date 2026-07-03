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

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  echo "windows-terminal: downloading CascadiaCode nerd font v$NERD_FONTS_VERSION..."
  curl -fL -o "$tmp/CascadiaCode.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v$NERD_FONTS_VERSION/CascadiaCode.zip"
  unzip -o -q "$tmp/CascadiaCode.zip" -d "$tmp/extract"

  mkdir -p "$fonts_dir"
  local have_reg=0
  command -v reg.exe >/dev/null 2>&1 && have_reg=1
  for w in "${FONT_WEIGHTS[@]}"; do
    file="CaskaydiaCoveNerdFont-$w.ttf"
    cp -f "$tmp/extract/$file" "$fonts_dir/$file"
    if [ "$have_reg" -eq 1 ]; then
      reg.exe add "HKCU\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" \
        /v "CaskaydiaCove NF $w (TrueType)" /t REG_SZ \
        /d "C:\\Users\\$win_user_name\\AppData\\Local\\Microsoft\\Windows\\Fonts\\$file" \
        /f >/dev/null
    fi
  done
  if [ "$have_reg" -eq 0 ]; then
    echo "windows-terminal: reg.exe not found (WSL interop disabled); fonts copied, will register on next Windows login." >&2
  fi
  echo "windows-terminal: font installed."
}

main() {
  local settings
  settings="$(locate_settings)" || true
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
