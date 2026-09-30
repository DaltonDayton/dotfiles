-- Dual 3440x1440 ultrawides, stacked. Keep scale on omarchy_monitor_scale:
-- the bar's scaling widget persists by rewriting that variable.
local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

hl.monitor({ output = "DP-2", mode = "3440x1440@144", position = "0x0", scale = omarchy_monitor_scale })    -- AOC (top)
hl.monitor({ output = "DP-3", mode = "3440x1440@165", position = "0x1440", scale = omarchy_monitor_scale }) -- Samsung (bottom)

hl.workspace_rule({ workspace = "1", monitor = "DP-3", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-2", persistent = true })
