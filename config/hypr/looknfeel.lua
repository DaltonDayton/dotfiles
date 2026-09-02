-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Bibata, carried over from the pre-Omarchy setup. Omarchy sets cursor *size*
-- (XCURSOR_SIZE/HYPRCURSOR_SIZE = 24 in default/hypr/envs.lua) but never a
-- theme, so this only adds the missing half -- don't restate the size here.
--
-- bibata-cursor-git ships hyprcursor alongside Xcursor. Hyprland renders the
-- hyprcursor SVGs natively and rescales them per-monitor; the -bin package is
-- Xcursor-only, so HYPRCURSOR_THEME would find nothing and silently fall back
-- to pre-rendered bitmaps. XCURSOR_THEME still matters for XWayland and GTK.
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")

-- https://wiki.hypr.land/Configuring/Dwindle-Layout/
hl.config({
  dwindle = {
    -- Omarchy's default is 2 ("always split right/bottom"), which is why new
    -- windows ignore the pointer. 0 splits based on where the cursor sits in
    -- the focused window: left half opens left, right half opens right.
    force_split = 0,
  },
})
