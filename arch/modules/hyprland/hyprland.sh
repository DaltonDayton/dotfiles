#!/usr/bin/bash

# Function to install the module
function install_hyprland() {
  # Define the list of packages required for this module
  local packages=(
    # Authentication Agent
    hyprpolkitagent

    # Qt Wayland Support
    qt5-wayland qt6-wayland

    # Fonts
    ttf-font-awesome
    otf-font-awesome
    noto-fonts
    noto-fonts-emoji

    # Utilities
    cliphist
    waybar
    hyprpaper
    hyprlauncher
    hypridle
    hyprlock
    pavucontrol
    pipewire-pulse
    jq # JSON processor for scripts
    btop
    spotify

    # File Extension Discovery
    xdg-utils
    desktop-file-utils
    shared-mime-info
    archlinux-xdg-menu
    # Also ran this, but idk if it's needed: `sudo update-mime-database /usr/share/mime`

    # Display manager
    sddm

    # Bluetooth utilities
    bluez       # Bluetooth protocol stack
    bluez-utils # Bluetooth utilities
    blueman     # Bluetooth manager GUI

    # Screenshot Utilities
    grim
    grimblast-git
    hyprpicker
    slurp
    satty
    wl-clipboard

    # gifs / mp4
    wf-recorder

    # OCR
    tesseract
    tesseract-data-eng

    # Voice Dictation
    voxtype # Push-to-talk voice-to-text (whisper.cpp based)
    wtype   # Wayland virtual keyboard (typing backend for voxtype)

    # Application Launcher / dmenu
    rofi # Window switcher, run dialog, dmenu replacement (Wayland native since 2.0)

    # # Essential utilities
    # "network-manager-applet"

    # # Enhanced tools and utilities
    # "rofi-wayland" # Application launcher (better than wofi)
    swaync # Notification center
    # "cliphist"     # Clipboard manager
    # "hyprshade"    # Blue light filter and screen effects
    # "hypridle"     # Idle daemon
    # "hyprlock"     # Screen locker
    # "hyprpicker"   # Color picker
    #
    # # Screenshot and media tools
    # "grim"  # Screenshot utility
    # "slurp" # Region selector for screenshots
    # "satty" # Screenshot annotation tool
    # "swww"  # Wallpaper daemon
    #
    # # System utilities
    # "playerctl"     # Media player control
    # "brightnessctl" # Brightness control
    # "pamixer"       # Audio control
    # "pavucontrol"   # Audio control GUI
    # "btop"          # Enhanced system monitor

    # # Themes and appearance
    # "catppuccin-gtk-theme-mocha" # GTK theme
    # "nwg-look"                   # Run nwg-look to configure themes
    "bibata-cursor-theme-bin"
    #
    # # "swayidle"
    # # "sway-audio-idle-inhibit-git"
  )

  # Install the packages using the install_packages function
  install_packages "${packages[@]}"

  # Proceed to configuration
  configure_hyprland
}

# Function to configure the module
function configure_hyprland() {
  # set -euo pipefail

  # Load device identity (sets DEVICE_NAME from ~/.config/device.env)
  load_device_env

  # hypr
  local config_source="$MODULES_DIR/hyprland/hypr"
  local config_dest="$HOME/.config/"
  symlink_config "$config_source" "$config_dest"

  # Deploy device-specific monitors config as a relative symlink within the repo,
  # falling back to default. Relative so the symlink is portable across machines.
  local hypr_dir="$MODULES_DIR/hyprland/hypr"
  local monitors_target
  if [ -f "$hypr_dir/monitors/${DEVICE_NAME}.conf" ]; then
    monitors_target="monitors/${DEVICE_NAME}.conf"
    log_info "Using monitors config for device: $DEVICE_NAME"
  else
    monitors_target="monitors/default.conf"
    log_warn "No monitors config found for '$DEVICE_NAME', falling back to default"
  fi
  ln -sfn "$monitors_target" "$hypr_dir/monitors.conf"
  log_success "Set monitors.conf -> $monitors_target"

  # Hyprpaper config is managed by the theme switcher (modules/theme/switch.py)

  # waybar
  config_source="$MODULES_DIR/hyprland/waybar"
  config_dest="$HOME/.config/"
  symlink_config "$config_source" "$config_dest"

  # wallpapers
  config_source="$MODULES_DIR/hyprland/wallpapers"
  config_dest="$HOME/.config/wallpapers"
  symlink_config "$config_source" "$config_dest"

  # Enable and start bluetooth service if not already enabled/running
  if ! systemctl is-enabled bluetooth.service >/dev/null 2>&1; then
    log_info "Enabling bluetooth service..."
    sudo systemctl enable bluetooth.service
  fi

  if ! systemctl is-active bluetooth.service >/dev/null 2>&1; then
    log_info "Starting bluetooth service..."
    sudo systemctl start bluetooth.service
  fi

  # SDDM (display manager) setup
  configure_sddm

  # Voxtype (voice dictation) setup
  configure_voxtype

  # Swaync (notification center) setup
  configure_swaync

  # Cliphist (clipboard manager) setup
  configure_cliphist

  # Additional configuration steps can be added here
  # For example, setting environment variables, running setup scripts, etc.

  # May not be needed with hyprland.conf update and bibata-cursor-theme-bin
  # NOTE: rofi-wayland is now replaced by rofi 2.0+ which has native Wayland support
  # # Copy Bibata cursor themes from local dotfiles
  # local bibata_source="$MODULES_DIR/hyprland/Bibata-Cursors"
  # local icons_dest="$HOME/.local/share/icons"
  #
  # # Ensure icons directory exists
  # mkdir -p "$icons_dest"
  #
  # # Copy each Bibata theme
  # for theme in "Bibata-Modern-Amber" "Bibata-Modern-Classic" "Bibata-Modern-Ice"; do
  #   if [ -d "$bibata_source/$theme" ]; then
  #     if [ ! -d "$icons_dest/$theme" ]; then
  #       echo "Installing $theme cursor theme..."
  #       cp -r "$bibata_source/$theme" "$icons_dest/"
  #     else
  #       echo "$theme cursor theme is already installed."
  #     fi
  #   else
  #     echo "Warning: $theme not found in $bibata_source"
  #   fi
  # done

}

# Function to configure SDDM display manager
function configure_sddm() {
  local theme_dir="/usr/share/sddm/themes/catppuccin-mocha-pink"

  # Symlink sddm.conf — requires sudo as /etc is root-owned
  local config_source="$MODULES_DIR/hyprland/config/sddm.conf"
  local config_dest="/etc/sddm.conf"
  if [ "$(readlink "$config_dest" 2>/dev/null)" != "$config_source" ]; then
    log_info "Symlinking /etc/sddm.conf..."
    sudo ln -sfn "$config_source" "$config_dest"
    log_success "Symlinked /etc/sddm.conf -> $config_source"
  else
    log_info "/etc/sddm.conf already up to date"
  fi

  # Install catppuccin SDDM theme from dotfiles
  if [ ! -d "$theme_dir" ]; then
    log_info "Installing catppuccin-mocha-pink SDDM theme..."
    sudo mkdir -p "$theme_dir"
    sudo cp -r "$MODULES_DIR/hyprland/sddm-theme/." "$theme_dir/"
    log_success "catppuccin-mocha-pink SDDM theme installed"
  else
    log_info "catppuccin-mocha-pink SDDM theme already installed"
  fi

  # Deploy device-specific theme.conf if one exists (e.g. theme.laptop.conf)
  local theme_conf_source="$MODULES_DIR/hyprland/sddm-theme/theme.${DEVICE_NAME}.conf"
  if [ -f "$theme_conf_source" ]; then
    log_info "Deploying $DEVICE_NAME SDDM theme.conf..."
    sudo cp "$theme_conf_source" "$theme_dir/theme.conf"
    log_success "Deployed $DEVICE_NAME SDDM theme.conf"
  fi

  # Enable and start sddm service
  if ! systemctl is-enabled sddm.service >/dev/null 2>&1; then
    log_info "Enabling sddm service..."
    sudo systemctl enable sddm.service
  fi

  if ! systemctl is-active sddm.service >/dev/null 2>&1; then
    log_info "Starting sddm service..."
    sudo systemctl start sddm.service
  fi
}

# Function to configure voxtype voice dictation
function configure_voxtype() {
  local voxtype_dir="$MODULES_DIR/hyprland/voxtype"
  local config_dest="$HOME/.config/voxtype"
  local hypr_conf_source="$MODULES_DIR/hyprland/hypr/conf.d/voxtype-submap.conf"
  local hypr_conf_dest="$HOME/.config/hypr/conf.d/voxtype-submap.conf"

  # Deploy device-specific voxtype config as a relative symlink within the repo,
  # falling back to default.
  local config_target
  if [ -f "$voxtype_dir/configs/${DEVICE_NAME}.toml" ]; then
    config_target="configs/${DEVICE_NAME}.toml"
    log_info "Using voxtype config for device: $DEVICE_NAME"
  else
    config_target="configs/default.toml"
    log_warn "No voxtype config found for '$DEVICE_NAME', falling back to default"
  fi
  ln -sfn "$config_target" "$voxtype_dir/config.toml"
  log_success "Set voxtype config.toml -> $config_target"

  # Symlink voxtype config directory
  symlink_config "$voxtype_dir" "$config_dest"

  # Symlink voxtype submap config for compositor integration
  # Note: hyprland.conf already sources this file via the dotfiles repo config
  if [ -f "$hypr_conf_source" ]; then
    symlink_config "$hypr_conf_source" "$hypr_conf_dest"
  fi

  # Download the whisper model configured for this device
  if command -v voxtype >/dev/null 2>&1; then
    log_info "Downloading voxtype whisper model (if not already present)..."
    voxtype setup --download

    # Enable GPU (Vulkan) backend for faster transcription
    log_info "Enabling voxtype GPU backend..."
    sudo voxtype setup gpu --enable
  else
    log_warn "voxtype not found in PATH. Run manually after install: voxtype setup --download"
  fi

  # Install systemd user service if not already installed
  local service_file="$HOME/.config/systemd/user/voxtype.service"
  if [ -f "$service_file" ]; then
    log_info "Voxtype systemd service already installed"
  elif command -v voxtype >/dev/null 2>&1; then
    log_info "Installing voxtype systemd user service..."
    voxtype setup systemd
    voxtype setup compositor hyprland
  else
    log_warn "voxtype not found in PATH. Run manually after install:"
    log_warn "  voxtype setup systemd"
    log_warn "  voxtype setup compositor hyprland"
  fi
}

# Function to configure swaync notification center
function configure_swaync() {
  # Remove dunst if installed (conflicts with swaync)
  if pacman -Qi dunst &>/dev/null; then
    log_info "Removing dunst (replaced by swaync)"
    sudo pacman -Rns --noconfirm dunst
  fi

  local config_source="$MODULES_DIR/hyprland/swaync"
  local config_dest="$HOME/.config/swaync"
  symlink_config "$config_source" "$config_dest"
}

# Function to configure cliphist clipboard manager
# Note: cliphist is started via exec-once in hyprland.conf rather than systemd,
# because the upstream service has Requisite=graphical-session.target which
# cannot be cleared via drop-in override (systemd 260), and Hyprland does not
# activate graphical-session.target.
function configure_cliphist() {
  local config_dir="$HOME/.config/cliphist"
  local config_file="$config_dir/config"

  # Desired config content (max history to 100 items for security)
  local desired_config="max-items=100"

  # Write cliphist config if missing or content has changed
  mkdir -p "$config_dir"
  if [ ! -f "$config_file" ] || [ "$(cat "$config_file")" != "$desired_config" ]; then
    log_info "Writing cliphist config (max-items=100)..."
    printf '%s\n' "$desired_config" >"$config_file"
  else
    log_info "Cliphist config already up to date"
  fi

}
