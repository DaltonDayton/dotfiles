-- Machine: laptop (xps16, Dell XPS 16 DA16260)
-- Linked to ~/.config/hypr/monitors.lua by install.sh --machine=laptop
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- Built-in eDP-1 is 3200x2000 HiDPI; scale 2 / "auto" is what keeps UI legible.
-- NOTE: scale must reference omarchy_monitor_scale, not a literal. The bar's
-- scaling widget (omarchy-hyprland-monitor-scaling) persists by rewriting that
-- variable, so a hardcoded value here silently overrides the widget.
local omarchy_gdk_scale = 2
local omarchy_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Fallback for any monitor not configured explicitly below.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
