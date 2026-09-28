-- Bibata cursor (bibata-cursor-git, which ships hyprcursor too). Omarchy
-- already sets the size.
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")

hl.config({
  dwindle = {
    -- Split toward the cursor instead of always right/bottom.
    force_split = 0,
  },
})
