# Color Scheme Presets

Preset palettes consumable by Color.qml when wallpaper adaptation is off
(`appearance.presetScheme`).

- Schema: identical to the wallpaper `colors.json` (`{"dark": {...}, "light": {...}}`,
  snake_case matugen keys), picked by the effective color scheme variant.
- Layout: `<Name>/<Name>.json` (bundled). User schemes live in
  `~/.config/afloat/colorschemes/<Name>/<Name>.json` and are picked up by
  ColorSchemeService automatically.
- Source: converted from noctalia-shell's bundled schemes (MIT License,
  Copyright (c) 2025 noctalia-dev); container steps (primary_container,
  surface_container_*) are derived from each scheme's surface/primary
  tokens to satisfy Afloat's full token set.
