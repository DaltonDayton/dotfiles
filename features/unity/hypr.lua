-- Unity Editor (installed through Unity Hub, runs under XWayland) reports its
-- class as "Unityhub-unity-editor-<version>". Hyprland regexes must match the
-- whole class, so the trailing .* is what makes this survive editor upgrades.
-- Same override form as the Unreal rule in features/unreal/hypr.lua so it
-- beats Omarchy's default-opacity tag.
o.window({ class = "^Unityhub-unity-editor.*" }, {
  opacity = "1 override 1 override 1 override",
})
