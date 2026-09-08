-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Tile Steam's main window. Omarchy floats it in
-- default/hypr/apps/steam.lua; this runs later and wins.
-- Matched on class AND title so Steam's dialogs (Friends List, game
-- properties) keep Omarchy's floating treatment. The class is anchored
-- because an unanchored "steam" also matches steam_app_battlenet, which
-- would drag the Battle.net launcher out of its float.
o.window({ class = "^steam$", title = "^Steam$" }, { tile = true })

-- Keep Firefox opaque while viewing YouTube, including when unfocused.
o.window({ class = "^[Ff]irefox$", title = ".*YouTube.*" }, {
  opacity = "1 override 1 override 1 override",
})


-- Playwright / MCP automation launches headed Chromium (ported from main).
-- Keep it a floating, centered window parked silently on its own special
-- workspace so an agent driving a browser never steals focus or reshuffles the
-- layout. SUPER+ALT+B in hypr/bindings.lua peeks at it. Omarchy's
-- default/hypr/apps/browser.lua tags it chromium-based-browser and tiles it, and
-- that tile rule wins over a later float, so drop the tag first. "silent" only
-- keeps the rule itself from switching workspaces: Playwright then asks
-- Chromium to raise the window, and focusing a window on a special workspace
-- shows that workspace. Suppressing activation is what keeps it off screen.
hl.workspace_rule({ workspace = "special:playwright", gaps_out = 20, gaps_in = 10 })
o.window({ class = "^chromium$" }, { tag = "-chromium-based-browser" })
o.window({ class = "^chromium$" }, {
  float = true,
  size = { 1920, 1080 },
  center = true,
  workspace = "special:playwright silent",
  no_initial_focus = true,
  suppress_event = "activate activatefocus",
})
