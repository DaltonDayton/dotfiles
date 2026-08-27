-- Machine: desktop (dual 3440x1440 ultrawides, vertically stacked)
-- Linked to ~/.config/hypr/monitors.lua by install.sh --machine=desktop
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Fallback for any monitor not configured explicitly below.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Vertical stack: AOC on top, Samsung below.
-- NOTE: scale must reference omarchy_monitor_scale, not a literal. The bar's
-- scaling widget (omarchy-hyprland-monitor-scaling) persists by rewriting that
-- variable, so a hardcoded value here silently overrides the widget.
-- AOC U34G2G4R3 (top)
hl.monitor({ output = "DP-2", mode = "3440x1440@144", position = "0x0", scale = omarchy_monitor_scale })
-- Samsung LC34G55T (bottom)
hl.monitor({ output = "DP-3", mode = "3440x1440@165", position = "0x1440", scale = omarchy_monitor_scale })

-- Pin workspaces to monitors. persistent = true keeps them alive even when
-- they hold no windows, so the slots are always there.
hl.workspace_rule({ workspace = "1", monitor = "DP-3", persistent = true }) -- Samsung (bottom)
hl.workspace_rule({ workspace = "2", monitor = "DP-2", persistent = true }) -- AOC (top)
