# Design: Wallpaper Rendering & Material You Color System

## Architecture Overview

Two independent singleton services connected by a signal: wallpaper change triggers color extraction.

```
┌─────────────────────────────────────────────────────────┐
│ WallpaperService (singleton)                             │
│  - currentWallpaper (path)                              │
│  - changeWallpaper(path), wallpaperChanged signal       │
│  - persistence (FileView + JsonAdapter)                 │
└──────────────────────┬──────────────────────────────────┘
                       │ wallpaperChanged signal
                       ▼
┌─────────────────────────────────────────────────────────┐
│ ColorService (singleton)                                 │
│  - Invokes Python template-processor.py via Process     │
│  - Writes ~/.cache/afloat/colors.json                   │
│  - 150ms debounce                                       │
└──────────────────────┬──────────────────────────────────┘
                       │ file write
                       ▼
┌─────────────────────────────────────────────────────────┐
│ Color (singleton)                                        │
│  - FileView watches colors.json                         │
│  - Exposes mPrimary, mSurface, etc. with Behavior anim │
│  - Default fallback colors                              │
└─────────────────────────────────────────────────────────┘
                       ▲ property binding
                       │
┌──────────────────────┴──────────────────────────────────┐
│ All QML components (bar, background, widgets)            │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Background module (PanelWindow per screen)               │
│  - WlrLayer.Background                                  │
│  - Dual Image swap with fade transition                 │
│  - Listens to WallpaperService.wallpaperChanged         │
└─────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### D1: Separate WallpaperService and ColorService (vs noctalia's AppThemeService)

noctalia combines theme mode switching, color scheme selection, and extraction triggering in AppThemeService. afloat V1 is simpler: no light/dark toggle, no predefined schemes. Split into:
- **WallpaperService**: owns wallpaper path, persistence, change signal
- **ColorService**: owns extraction process invocation, debounce

This keeps each service focused and testable independently.

### D2: Copy noctalia Python scripts (independent maintenance)

The Python color extraction pipeline (`Scripts/python/src/theming/`) is self-contained. Copied into afloat's `scripts/theming/` directory (only `template-processor.py` + `lib/`). The Process invocation will be:
```
python3 <project>/scripts/theming/template-processor.py <wallpaper_path> --dark -o <cache>/colors.json
```

### D3: Color singleton loads from file (decoupled from extraction)

Like noctalia's Color.qml pattern: FileView watches `colors.json`, JsonAdapter maps properties. This decouples Color from the extraction mechanism — colors could also be set manually or by external tools.

### D4: Simplified Background (no shader transitions V1)

V1 uses a simple crossfade (opacity animation) instead of noctalia's 6 shader effects. The dual-image pattern is preserved for smooth transitions. Shader effects can be added later.

### D5: Single wallpaper for all screens (V1)

Unlike noctalia's per-screen wallpaper map, V1 uses one wallpaper path for all screens. The Background module still uses `Variants { model: Quickshell.screens }` for multi-monitor rendering, but all instances share the same source.

## Data Model

### Wallpaper persistence (`~/.local/share/quickshell/afloat/wallpaper.json`)
```json
{
  "version": 1,
  "wallpaper": "/path/to/image.png",
  "fillMode": "cover"
}
```

### Color output (`~/.cache/afloat/colors.json`)
```json
{
  "dark": {
    "mPrimary": "#c8bfff",
    "mOnPrimary": "#2f1f7a",
    "mSecondary": "#c8c3dc",
    "mOnSecondary": "#312c47",
    "mTertiary": "#ecb8c8",
    "mOnTertiary": "#4a2532",
    "mError": "#ffb4ab",
    "mOnError": "#690005",
    "mSurface": "#1c1b1f",
    "mOnSurface": "#e6e1e5",
    "mSurfaceVariant": "#49454f",
    "mOnSurfaceVariant": "#cac4d0",
    "mOutline": "#938f99",
    "mShadow": "#000000"
  }
}
```

## Module Boundaries

| File | Responsibility |
|------|---------------|
| `services/WallpaperService.qml` | Wallpaper state, persistence, change signal |
| `services/ColorService.qml` | Python process invocation, debounce, output path |
| `services/Color.qml` | M3 color properties, FileView watcher, animations |
| `modules/background/BackgroundWindow.qml` | PanelWindow per screen, image rendering, transitions |
| `scripts/theming/` | Symlink to noctalia's Python extraction pipeline |
| `services/qmldir` | Export all three singletons |

## Compatibility

- Background renders on WlrLayer.Background, below existing bar (WlrLayer.Top)
- ScreenCornerWindow (WlrLayer.Overlay) remains above everything
- Color singleton is opt-in: existing hardcoded colors continue working until components are migrated
- WallpaperService persistence uses same FileView pattern as BarLayoutService

## Tradeoffs

| Choice | Gains | Costs |
|--------|-------|-------|
| Copy Python scripts | Independent, no external path dependency | Must manually sync upstream improvements |
| File-based color passing | Decoupled, debuggable, external tool compatible | Extra disk I/O, 150ms+ latency |
| Single wallpaper V1 | Simpler state model | No per-monitor customization |
| Opacity crossfade V1 | No GLSL complexity | Less visually impressive transitions |
