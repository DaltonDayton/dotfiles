-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Special workspaces
hl.workspace_rule({ workspace = "special:scratchpad", on_created_empty = "kitty", gaps_out = 40, gaps_in = 20 })
hl.workspace_rule({ workspace = "special:music", on_created_empty = "spotify", gaps_out = 20, gaps_in = 10 })
hl.workspace_rule({ workspace = "special:files", on_created_empty = "dolphin", gaps_out = 20, gaps_in = 10 })
hl.workspace_rule({ workspace = "special:monitoring", on_created_empty = "[float] kitty -e btop", gaps_out = 30, gaps_in = 15 })
hl.workspace_rule({ workspace = "special:obsidian", on_created_empty = "obsidian", gaps_out = 25, gaps_in = 12 })
hl.workspace_rule({ workspace = "special:playwright", gaps_out = 20, gaps_in = 10 })

-- Layers
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "swaync-control-center" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0.3 })

-- Windows
hl.window_rule({
    -- Ignore maximize requests from all apps.
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = { 20, "monitor_h-120" },
    float = true,
})

hl.window_rule({
    name = "world-of-warcraft",
    match = { title = "World of Warcraft" },
    idle_inhibit = "always",
    opacity = 1,
    no_anim = true,
    no_blur = true,
    no_dim = true,
    no_shadow = true,
    render_unfocused = true, -- fixes game freezing when moving workspaces
    immediate = true,
    fullscreen = true,
    fullscreen_state = "2 2",
})

hl.window_rule({
    name = "zoo-tycoon",
    match = { title = "Zoo Tycoon" },
    idle_inhibit = "always",
    opacity = 1,
    no_anim = true,
    no_blur = true,
    no_dim = true,
    no_shadow = true,
    fullscreen = true,
    fullscreen_state = "3",
    render_unfocused = true, -- fixes game freezing when moving workspaces
    monitor = "DP-1", -- HYTE case monitor — not detected since 2026-07 reinstall; fix name when reconnected
})

hl.window_rule({
    name = "tradeskillmaster-float",
    match = { title = "TradeSkillMaster Application.*" },
    float = true,
    monitor = "DP-5", -- Samsung (bottom primary); port renumbered on 2026-07 reinstall
    workspace = "4",
    move = { 2831, 48 },
    size = { 600, 600 },
})

hl.window_rule({
    name = "TSMApplication",
    match = { title = "TSMApplication " },
    float = true,
    monitor = "DP-5", -- Samsung (bottom primary); port renumbered on 2026-07 reinstall
    workspace = "4",
    move = { 2831, 48 },
})

hl.window_rule({
    name = "battlenet-float",
    match = { title = "Battle.net" },
    float = true,
})

hl.window_rule({
    name = "devtools-windowed",
    match = { class = "firefox", initial_title = "^$" },
    float = true,
    size = { 1570, 970 },
})

hl.window_rule({
    -- Playwright / MCP automation launches headed Chromium; keep it a
    -- predictable floating window, parked silently on its own special
    -- workspace (mainMod+Alt+B to view) so it never disturbs the layout.
    name = "playwright-windowed",
    match = { class = "^chromium$" },
    float = true,
    size = { 1920, 1080 },
    center = true,
    workspace = "special:playwright silent",
})
