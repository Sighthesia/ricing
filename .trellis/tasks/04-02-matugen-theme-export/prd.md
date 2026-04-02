# Add matugen theme export targets

## Goal
Add repo-owned matugen templates and configuration so wallpaper-generated themes can also write into common desktop/application targets such as GTK, Qt, KDE, Niri, and Kitty, while preserving DymicShell's existing dynamic color loading.

## Requirements
- Keep the current `colors.json` output used by `config/Colors.qml` working.
- Stop relying on the user's global `~/.config/matugen/config.toml`.
- Generate theme outputs for at least GTK, Qt, KDE, Niri, and Kitty.
- Make generated outputs usable by adding minimal include/import wiring where needed.
- Keep the implementation repo-owned and service-driven from the existing `WallpaperService` flow.
- If Noctalia Shell is used as inspiration, mark the relevant file(s) with a reference note and link.

## Acceptance Criteria
- [ ] `WallpaperService` runs `matugen` against a repo-owned config file.
- [ ] DymicShell still reads updated wallpaper colors from generated `colors.json`.
- [ ] GTK export writes generated colors and ensures `gtk.css` imports them.
- [ ] Qt/KDE export writes generated schemes to standard user paths.
- [ ] Niri and Kitty export write generated theme files and ensure they can be consumed from user config.
- [ ] Reference note is included where Noctalia Shell inspired the implementation.

## Technical Notes
- Prefer a single repo-owned `matugen/config.toml` plus template files over custom hand-written renderers.
- Use a small helper script only for idempotent include/import wiring or lightweight reload hooks.
- Keep external write failures diagnosable without breaking the shell itself.
