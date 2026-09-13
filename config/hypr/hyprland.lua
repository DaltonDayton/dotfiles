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

-- Obsidian on its own special workspace (ported from main). Toggled with
-- SUPER+ALT+O in hypr/bindings.lua; launches Obsidian when opened empty.
hl.workspace_rule({ workspace = "special:obsidian", on_created_empty = "obsidian", gaps_out = 25, gaps_in = 12 })

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

-- Battle.net + TSM (launched together by ~/.local/bin/battlenet-tsm): both
-- floating and parked on the right edge, TSM in the top corner and the
-- Battle.net launcher below it. Omarchy's default/hypr/apps/battlenet.lua
-- floats and centers the launcher; this runs later and replaces the centering.
-- move coordinates are monitor-local, so the right-edge maths holds on any
-- monitor width. Title regexes must match the whole title, hence the
-- trailing .* to cover TSM's version suffix. All pinned to workspace 4.
o.window({ class = "^steam_app_battlenet$", title = "^TradeSkillMaster Application.*" }, {
  workspace = "4",
  float = true,
  size = { 600, 600 },
  move = { "monitor_w-window_w-3", "27" },
})
-- TSM's login splash ("TSM Login - v4.14.2") shows for a few seconds before
-- the main window; float it into the same corner so it doesn't tile.
o.window({ class = "^steam_app_battlenet$", title = "^TSM Login.*" }, {
  workspace = "4",
  float = true,
  move = { "monitor_w-window_w-3", "27" },
})
-- TSM's login/logout dialog is a separate window titled just "TSMApplication".
-- Centered on the main TSM window above: its centre is 303px in from the right
-- edge (3px gap + half of 600) and 327px down (27px + half of 600).
o.window({ class = "^steam_app_battlenet$", title = "^TSMApplication$" }, {
  workspace = "4",
  float = true,
  move = { "monitor_w-303-(window_w*0.5)", "327-(window_h*0.5)" },
})
o.window({ class = "^steam_app_battlenet$", title = "^Battle\\.net$" }, {
  workspace = "4",
  center = false,
  move = { "monitor_w-window_w-3", "631" },
})

-- Wine (via XWayland) asks Hyprland to activate the Battle.net/TSM windows as
-- they open, close, and hand focus to each other, and Omarchy's global
-- misc.focus_on_activate = true honours that with a cursor warp each time
-- (CWindow::activate focuses, then warpCursor()). Ignore activation requests
-- from this prefix only; keyboard focus moves and new-window focus are
-- unaffected. Same treatment Omarchy gives Telegram.
o.window({ class = "^steam_app_battlenet$" }, { focus_on_activate = false })
