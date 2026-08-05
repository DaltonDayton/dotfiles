-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/

-- Theme colors: colors/colors.lua is runtime-written by apply-theme.sh and
-- absent until the first theme switch; fall back to a neutral palette so a
-- fresh install still boots with sane borders.
local ok, colors = pcall(require, "colors/colors")
if not ok or type(colors) ~= "table" then
    colors = { blue = "rgb(458588)", bg4 = "rgb(665c54)" }
end

-- Environment variables
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XDG_MENU_PREFIX", "arch-") -- File Extension Discovery (Requires: kbuildsycoca6 autostart)

-- NEEDED FOR NVIDIA
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Autostart
hl.on("hyprland.start", function()
    -- Activate the systemd graphical session so xdg-desktop-portal
    -- (Requisite=graphical-session.target) can start.
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("waybar")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("swaync")
    hl.exec_cmd("solaar --window=hide")
    hl.exec_cmd("kbuildsycoca6") -- File Extension Discovery (Requires XDG_MENU_PREFIX env)
    hl.exec_cmd("systemctl --user start voxtype") -- Voice dictation daemon
    hl.exec_cmd("wl-paste --watch cliphist store") -- Clipboard history
    hl.exec_cmd("nm-applet --indicator")
end)

-- Look and feel
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        ["col.active_border"] = colors.blue,
        ["col.inactive_border"] = colors.bg4,
        resize_on_border = false,
        allow_tearing = false, -- see https://wiki.hypr.land/Configuring/Tearing/
        layout = "dwindle",
        no_focus_fallback = true,
    },
    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },
    animations = { enabled = true },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification
        touchpad = {
            natural_scroll = true,
        },
    },
    cursor = {
        hide_on_key_press = true,
        inactive_timeout = 2,
    },
})

-- Animation curves, see https://wiki.hypr.land/Configuring/Animations/#curves
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, curve = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, curve = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, curve = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, curve = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, curve = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, curve = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, curve = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, curve = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, curve = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, curve = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, curve = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, curve = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, curve = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, curve = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, curve = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, curve = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, curve = "quick" })

-- Gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Per-device input, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
hl.device({ name = "logitech-usb-receiver-mouse", sensitivity = 0.0 })
hl.device({ name = "razer-razer-naga-v2-hyperspeed", sensitivity = 0.3 })

-- Split config modules
require("monitors") -- symlink -> monitors/<host>.lua
require("windowrules")
require("keybindings")
require("conf.d/voxtype-submap")
