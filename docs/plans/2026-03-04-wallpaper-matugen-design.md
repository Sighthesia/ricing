# Wallpaper Management & Matugen Integration Design

**Date:** 2026-03-04  
**Status:** Approved

## Overview

Add wallpaper management and dynamic color extraction to DymicShell by integrating
`matugen`, mirroring patterns from noctalia-shell and DankMaterialShell. When enabled,
shell colors are derived from the current wallpaper's Material Design 3 palette instead
of static user-defined values.

## Reference Projects

- **noctalia-shell**: Python script replicates matugen's MD3 algorithm; QML `FileView`
  watches `colors.json`; `WallpaperService` + `AppThemeService` + `TemplateProcessor`
  orchestrate extraction.
- **DankMaterialShell**: Calls `matugen` CLI directly via `dms` backend; reads
  `dms-colors.json` in `Theme.qml` with a `FileView`; supports per-monitor wallpaper
  and scheme-type picker.

## Architecture

```
WallpaperService (new Singleton)
  ├─ wallpaperPath property ← settings.json
  ├─ swww polling (Process, every 5 s) → detect external changes
  ├─ wallpaperChanged signal
  └─ on change + matugenEnabled → run matugen → write matugen-colors.json

Colors.qml (modified Singleton)
  ├─ FileView watching ~/.config/dymicshell/matugen-colors.json
  ├─ matugenEnabled = true  → colors from parsed JSON (dark/light node)
  └─ matugenEnabled = false → colors from SettingsService (existing behavior)
```

## New / Modified Files

| File | Change | Responsibility |
|---|---|---|
| `services/WallpaperService.qml` | New Singleton | Wallpaper path management, swww polling, matugen invocation, JSON output |
| `config/Colors.qml` | Modify | Add FileView + conditional color source |
| `services/SettingsService.qml` | Modify | Add `wallpaperPath`, `matugenEnabled`, `matugenScheme`, `darkMode` to `appearance` |
| `modules/bar/settings/AppearancePage.qml` | Modify | New "壁纸 & 动态主题色" ExpandableGroup |
| `config/settings-default.json` | Modify | Add new appearance keys with safe defaults |

## WallpaperService Design

### Properties

```
wallpaperPath   : string    // persisted in settings.json; updated by swww poll
matugenRunning  : bool      // true while matugen process is active
```

### Signals

```
wallpaperChanged(string path)
matugenCompleted()
matugenFailed(string error)
```

### swww Detection

- `Timer { interval: 5000; repeat: true }` triggering `Process { command: ["swww", "query"] }`
- Parse stdout: extract the last path-like token after `"image path:"` (swww query format)
- Compare with current `wallpaperPath`; on mismatch update settings + emit `wallpaperChanged`
- Detection only runs when `SettingsService.data.appearance.matugenEnabled` is true

### matugen Invocation

```
matugen image <wallpaperPath> --json hex
```

- Uses Quickshell `Process` with `stdout` captured via `ProcessDataListener`
- Accumulates stdout chunks in a string buffer
- On exit (code 0): write buffer to `~/.config/dymicshell/matugen-colors.json` via `FileView`
- On exit (non-0): emit `matugenFailed`, leave existing JSON untouched

### Debouncing

A 800 ms `Timer` debounces rapid wallpaper changes (e.g., slideshow) before triggering matugen.

## Colors.qml Design

### New Properties

```qml
readonly property bool _usingMatugen:
    SettingsService.data.appearance.matugenEnabled && _matugenData !== null

property var _matugenData: null   // parsed JSON object from matugen output
```

### Color Source Logic

```qml
readonly property color background:
    _usingMatugen
        ? (_darkMode ? _matugenData.colors.dark.background
                     : _matugenData.colors.light.background)
        : SettingsService.data.appearance.backgroundColor
```

Applied identically for all six color tokens (see mapping below).

### Color Mapping (matugen → DymicShell tokens)

| DymicShell token | matugen dark key | matugen light key |
|---|---|---|
| `backgroundColor` | `background` | `background` |
| `surfaceColor` | `surface_container` | `surface_container` |
| `accentColor` | `primary` | `primary` |
| `textColor` | `on_surface` | `on_surface` |
| `textMutedColor` | `on_surface_variant` | `on_surface_variant` |
| `borderColor` | `outline_variant` | `outline_variant` |

### FileView

```qml
FileView {
    id: matugenColorsView
    path: SettingsService.configDir + "matugen-colors.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { _matugenData = JSON.parse(text) }
    onLoadFailed: { _matugenData = null }
}
```

## Settings Schema Changes

### settings-default.json additions (under `appearance`)

```json
"wallpaperPath":  "",
"matugenEnabled": false,
"matugenScheme":  "scheme-tonal-spot",
"darkMode":       true
```

### Supported scheme values (passed as `--type` to matugen)

- `scheme-tonal-spot` (default)
- `scheme-vibrant`
- `scheme-expressive`
- `scheme-fidelity`
- `scheme-neutral`
- `scheme-monochrome`

## Settings UI (AppearancePage.qml)

New `ExpandableGroup` titled **"壁纸 & 动态主题色"**, inserted before the existing "颜色"
group. Contains:

1. **TextFieldSection** `label: "壁纸路径"` — bound to `wallpaperPath`; shows a file-open
   hint in helper text; triggers manual matugen run on commit.
2. **BoolSection** (new primitive) `label: "动态主题色"` — toggle bound to `matugenEnabled`.
3. **DropdownSection** (new primitive) `label: "配色算法"` — visible only when
   `matugenEnabled`; items are the six scheme values above.
4. **BoolSection** `label: "深色模式"` — toggle bound to `darkMode`.

The existing "颜色" group remains fully functional; its controls are visually dimmed
(opacity 0.4) when `matugenEnabled` is true to indicate they are overridden.

## Error Handling

- matugen not found → `WallpaperService.matugenFailed("matugen not found")`; Colors.qml
  falls back to settings colors silently.
- Empty wallpaper path → skip matugen; use settings colors.
- Malformed JSON output → `_matugenData = null`; fall back to settings colors.
- swww not running → swww query exits non-zero; poll suppressed until next trigger.

## Non-Goals

- **Template engine** (noctalia-style): Writing GTK/app themes is out of scope for v1.
- **Per-monitor wallpaper tracking**: Single global wallpaper only in v1.
- **Wallpaper browser UI**: No directory picker or thumbnail grid; path input only.
