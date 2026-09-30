-- Dell XPS 16, 3200x2000 built-in. Keep scale on omarchy_monitor_scale:
-- the bar's scaling widget persists by rewriting that variable.
local omarchy_gdk_scale = 2
local omarchy_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
