-- Unreal Editor creates toasts, tooltips and drag previews as separate
-- untitled toplevel windows. Without this they float with a border. The main
-- editor window always has a title, so only the untitled helpers match.
-- (no_focus was here while Unreal ran on native Wayland, where these windows
-- stole keyboard focus; under XWayland it instead made the toast buttons
-- unclickable, so it is gone.)
o.window({ class = "^UnrealEditor$", title = "^$", float = true }, {
  border_size = 0,
  no_shadow = true,
  no_blur = true,
  no_dim = true,
  opacity = "1 1",
})

-- Unreal (now running under XWayland via SDL_VIDEO_DRIVER=x11 in its launcher)
-- sends activation requests as menus, tooltips and dialogs open, and Omarchy's
-- misc.focus_on_activate = true answers each with a cursor warp. Ignore the
-- requests, same treatment as Battle.net in features/battlenet-tsm/hypr.lua.
o.window({ class = "^UnrealEditor$" }, { focus_on_activate = false })

-- Keep the Unreal Editor fully opaque, focused or not. Same override form as
-- the YouTube rule in features/hypr-tweaks/hypr.lua so it beats Omarchy's
-- default-opacity tag.
o.window({ class = "^UnrealEditor$" }, {
  opacity = "1 override 1 override 1 override",
})

-- Blender too. Its class is "blender" on native Wayland and "Blender" under
-- XWayland, hence the case-insensitive first letter.
o.window({ class = "^[Bb]lender$" }, {
  opacity = "1 override 1 override 1 override",
})

-- NVIDIA pipeline/shader disk cache (~/.cache/nvidia/GLCache). The driver's
-- default is a 1 GB cap with eviction, and Unreal alone produces more than
-- that, so pipelines get recompiled every session (LogPSOHitching stalls).
-- 10 GB, no cleanup. env entries are read at Hyprland startup only, so a
-- logout/login is needed, not just a reload.
hl.env("__GL_SHADER_DISK_CACHE_SIZE", "10737418240")
hl.env("__GL_SHADER_DISK_CACHE_SKIP_CLEANUP", "1")
