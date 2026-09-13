# KDE Dynamic Theme Design

## Goal

Generate and apply an Afloat KDE color scheme whenever the existing app-theme
synchronization runs, following Noctalia's KDE integration model while using
Afloat's generated Material color tokens.

## Scope

- Add a KDE `.colors` template to `scripts/theming/templates/`.
- Register the template in `scripts/theming/templates/app-themes.toml`.
- Render the scheme to `~/.local/share/color-schemes/Afloat.colors`.
- Merge the generated color groups into `~/.config/kdeglobals`.
- Notify KDE applications with `org.kde.KGlobalSettings.notifyChange(0, 0)`.
- Keep unrelated `kdeglobals` settings intact.
- Skip KDE notification in `--home-prefix` test runs.
- Preserve existing GTK, Qt, Kitty, and system-theme behavior.

## Color Mapping

The template will use existing Afloat tokens:

- Window and dialog backgrounds: `surface`.
- View and alternate backgrounds: `surface_container_low`.
- Button and selection backgrounds: `primary`.
- Text on primary surfaces: `on_primary`.
- Normal text: `on_surface`.
- Secondary text: `on_surface_variant`.
- Borders and separators: `outline`.
- Error states: `error` and `on_error`.

The exact KDE group names will follow the standard KDE `.colors` format so
both KDE Plasma and Qt applications can consume the generated values.

## Application Flow

1. `apply_app_themes.py` invokes the existing template processor.
2. The processor writes `Afloat.colors` under the user's KDE color-scheme directory.
3. The apply script reads the current `kdeglobals` file with case-sensitive keys.
4. It overlays only sections and keys present in `Afloat.colors`.
5. It writes the merged `kdeglobals` file without changing unrelated sections.
6. It sends the KDE global-settings notification when running outside a sandbox.

The merge operation is intentionally based on the generated scheme file rather
than replacing `kdeglobals`, because that file also stores user preferences
unrelated to colors.

## Error Handling

- Missing KDE directories are created during rendering or apply.
- Missing `kdeglobals` is treated as an empty configuration.
- Missing `dbus-send` or Python `jeepney` produces a warning and does not fail
  the rest of app-theme synchronization.
- A failed KDE notification does not invalidate the generated color file.
- Test runs use a home prefix and verify files without touching the session bus.

## Verification

- Render a dark palette and assert the KDE file contains expected background,
  foreground, primary, and error values.
- Render a light palette and verify values switch to the light token set.
- Seed `kdeglobals` with an unrelated setting and verify it survives merging.
- Run the full `scripts/tests/test_apply_app_themes.py` suite.
