-- Unity Editor (installed through Unity Hub, runs under XWayland) reports its
-- class as "Unityhub-unity-editor-<version>". Hyprland regexes must match the
-- whole class, so the trailing .* is what makes this survive editor upgrades.
-- Same override form as the Unreal rule in features/unreal/hypr.lua so it
-- beats Omarchy's default-opacity tag.
o.window({ class = "^Unityhub-unity-editor.*" }, {
  opacity = "1 override 1 override 1 override",
})

-- The Ghostty window the Unity Neovim package launches (features/unity/README.md).
-- Floating and centered so it overlays the editor instead of tiling into it;
-- the package itself focuses it through this initial title.
o.window({ initial_title = "^nvimunity-.*" }, {
  float = true,
  size = { 1920, 1080 },
  center = true,
})
