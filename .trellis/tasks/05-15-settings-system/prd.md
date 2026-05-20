# Settings System and Panel

## Goal

Implement a centralized settings service with JSON persistence and a VS Code-style flat settings panel that pops up from the bar.

## Requirements

### Settings Service (`services/SettingsService.qml`)
- Singleton service owning all shell configuration state
- JSON file persistence via `FileView` + `JsonAdapter` (same pattern as `BarLayoutService` / `WallpaperService`)
- Debounced save (500ms timer) to avoid excessive IO on rapid changes (sliders)
- External file watch + reload for manual edits
- Default values baked into the adapter so the shell always has valid state

### Settings Panel (`modules/settings/`)
- Triggered from a bar button (gear icon widget)
- Popup `PanelWindow` anchored below the bar (overlay layer)
- VS Code-style flat layout: all settings visible in a single scrollable list, grouped by category headers
- No sidebar/tabs — just category headers + flat setting rows
- Search/filter input at the top to narrow visible settings

### Setting Items (MVP scope)

**Bar**
- `bar.height` (int, default 42)
- `bar.position` (enum: top/bottom, default "top")
- `bar.floating` (bool, default false)
- `bar.floatingMargin` (int, default 4)
- `bar.backgroundOpacity` (real 0-1, default 0.85)
- `bar.cornerRadius` (int, default 12)

**Appearance**
- `appearance.wallpaperPath` (string, file picker)
- `appearance.colorScheme` (enum: auto/dark/light, default "auto")
- `appearance.panelOpacity` (real 0-1, default 0.9)
- `appearance.cornerRadius` (int, default 12)
- `appearance.enableBlur` (bool, default true)

**Notifications**
- `notifications.maxVisible` (int, default 3)
- `notifications.timeout` (int ms, default 5000)
- `notifications.position` (enum: top-right/top-left/bottom-right/bottom-left, default "top-right")
- `notifications.dnd` (bool, default false)

## Acceptance Criteria

- [ ] `SettingsService` singleton loads/saves settings from `Quickshell.statePath("settings.json")`
- [ ] Changing a setting in the panel immediately reflects in the shell (reactive bindings)
- [ ] Settings persist across shell restarts
- [ ] Panel opens/closes from a bar widget button
- [ ] All MVP settings are editable with appropriate controls (slider, toggle, dropdown, file picker)
- [ ] Search input filters visible settings by label
- [ ] External edits to `settings.json` are detected and reloaded

## Constraints

- Must follow existing `services/` singleton pattern and register in `services/qmldir`
- Panel is a `PanelWindow` on overlay layer, not a separate floating window
- No new external dependencies — use only QtQuick, Quickshell, and Quickshell.Io
- Existing services (`BarLayoutService`, `NotificationService`, etc.) should read from `SettingsService` instead of hardcoding values
