# Design: Settings System and Panel

## Architecture Overview

```
services/SettingsService.qml  ← singleton, owns all config state + persistence
services/qmldir              ← register SettingsService

modules/settings/
├── SettingsWindow.qml       ← PanelWindow popup (overlay layer)
├── SettingsContent.qml      ← search bar + scrollable flat list
├── SettingsCategory.qml     ← category header component
└── controls/
    ├── SettingToggle.qml    ← bool setting row
    ├── SettingSlider.qml    ← numeric range setting row
    ├── SettingDropdown.qml  ← enum setting row
    ├── SettingText.qml      ← string input setting row
    └── SettingFilePicker.qml← file path + browse button

shell.qml                    ← add Settings.SettingsWindow {}
modules/bar/                 ← add settings gear widget
```

## Data Flow

```
SettingsService (singleton)
    │
    ├── FileView + JsonAdapter → settings.json (statePath)
    │       ↑ watchChanges (external edits)
    │       ↓ writeAdapter (debounced 500ms)
    │
    ├── property bindings ← read by BarLayoutService, NotificationService, etc.
    │
    └── property writes ← from SettingsContent UI controls
```

## Key Design Decisions

### 1. Single JsonAdapter with nested JsonObject (like noctalia)
The adapter defines all settings with defaults. Nested `JsonObject` groups settings by category. This gives us:
- Type-safe defaults
- Automatic serialization/deserialization
- Reactive property bindings throughout the shell

### 2. Flat VS Code-style panel (no tabs/sidebar)
All settings are rendered in a single `ScrollView` with category headers as visual separators. A search input at the top filters rows by matching against the label text. This is simpler than noctalia's tab-based approach and matches the user's request.

### 3. Panel as PanelWindow (not FloatingWindow)
The settings panel is a `PanelWindow` on the overlay layer, anchored below the bar. This keeps it consistent with other bar-triggered popups and avoids window management complexity.

### 4. Gradual migration of hardcoded values
Existing services will be updated to read from `SettingsService` properties instead of hardcoded constants. This is done incrementally — the service exposes the same property names so consumers don't need to change their binding expressions.

## Boundaries & Contracts

### SettingsService API
```qml
// Read
SettingsService.bar.height          → int
SettingsService.bar.position        → string
SettingsService.appearance.panelOpacity → real
SettingsService.notifications.maxVisible → int

// Write (triggers debounced save)
SettingsService.bar.height = 48
```

### Settings Panel ↔ SettingsService
Panel controls bind directly to `SettingsService.xxx.yyy` properties. Two-way binding via `onValueChanged: SettingsService.xxx.yyy = newValue`.

### SettingsService ↔ Existing Services
- `BarLayoutService.barHeight` → reads `SettingsService.bar.height`
- `NotificationService` popup cap → reads `SettingsService.notifications.maxVisible`
- `WallpaperService` → reads `SettingsService.appearance.wallpaperPath` on change

## Compatibility

- No breaking changes to existing module imports
- Existing hardcoded values become the defaults in SettingsService, so behavior is identical until user changes settings
- `settings.json` is created on first run with all defaults (no setup wizard needed)

## Tradeoffs

- **Flat list vs tabs**: Simpler to implement and navigate, but may feel long with many settings. Mitigated by search and category headers.
- **Single file vs per-service files**: One `settings.json` is simpler to manage but creates a single point of failure. Acceptable for a shell config.
- **Debounced save**: 500ms delay means a crash within that window loses the last change. Acceptable tradeoff for IO efficiency.
