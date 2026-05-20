# Implementation Plan: Wallpaper Rendering & Material You Color System

## Phase 1: Python Scripts Setup

### 1.1 Symlink noctalia theming scripts
- [ ] Create `scripts/` directory in afloat root
- [ ] Symlink `../noctalia-shell/Scripts/python/src/theming` → `scripts/theming`
- [ ] Verify: `python3 scripts/theming/template-processor.py --help` runs without error

## Phase 2: Color Singleton

### 2.1 Create services/Color.qml
- [ ] Singleton with 14 M3 color properties (mPrimary through mShadow)
- [ ] Default fallback colors (dark theme defaults)
- [ ] FileView watching `~/.cache/afloat/colors.json` with `watchChanges: true`
- [ ] JsonAdapter mapping JSON keys to color properties
- [ ] Behavior animations on all color properties (300ms OutCubic)
- [ ] `skipTransition` flag to suppress animation on initial load
- [ ] Debounced reload timer (200ms) for atomic file replacements

### 2.2 Update services/qmldir
- [ ] Register `Color` singleton

**Validation:** Shell loads without error. Color.mPrimary returns default color. Manually placing a colors.json triggers property updates.

## Phase 3: ColorService (Extraction Trigger)

### 3.1 Create services/ColorService.qml
- [ ] Singleton with `extractColors(wallpaperPath)` function
- [ ] Process component invoking `python3 scripts/theming/template-processor.py <path> --dark -o <cacheDir>/colors.json`
- [ ] 150ms debounce timer before launching process
- [ ] `isExtracting` property for UI feedback
- [ ] Error handling: log stderr, don't crash on Python failure
- [ ] Ensure cache directory exists (mkdir -p via Process)

### 3.2 Update services/qmldir
- [ ] Register `ColorService` singleton

**Validation:** Calling `ColorService.extractColors("/path/to/image.png")` produces valid colors.json. Color singleton picks up the new values.

## Phase 4: WallpaperService

### 4.1 Create services/WallpaperService.qml
- [ ] Singleton with `currentWallpaper` property (string path)
- [ ] `changeWallpaper(path)` function
- [ ] `wallpaperChanged(path)` signal
- [ ] FileView + JsonAdapter persistence to `Quickshell.statePath("wallpaper.json")`
- [ ] Default fallback: empty string (triggers solid color in Background)
- [ ] On wallpaper change: emit signal, trigger `ColorService.extractColors(path)`

### 4.2 Update services/qmldir
- [ ] Register `WallpaperService` singleton

**Validation:** `WallpaperService.changeWallpaper(path)` persists, survives restart, triggers color extraction.

## Phase 5: Background Rendering

### 5.1 Create modules/background/BackgroundWindow.qml
- [ ] `Variants { model: Quickshell.screens }` creating PanelWindow per screen
- [ ] `WlrLayershell.layer: WlrLayer.Background`
- [ ] `anchors.fill` with `exclusiveZone: -1` (no reserved space)
- [ ] Dual Image pattern: `currentImage` + `nextImage`
- [ ] `fillMode: Image.PreserveAspectCrop` (cover behavior)
- [ ] `asynchronous: true` on both images
- [ ] Crossfade transition: opacity animation on swap (400ms)
- [ ] Listen to `WallpaperService.wallpaperChanged` → load into nextImage → crossfade → swap
- [ ] Solid color fallback Rectangle when no wallpaper set

### 5.2 Update shell.qml
- [ ] Replace or augment `Background.ScreenCornerWindow` with `Background.BackgroundWindow`

**Validation:** Wallpaper renders behind bar on all screens. Changing wallpaper shows smooth crossfade.

## Phase 6: Integration & Polish

### 6.1 Wire bar colors
- [ ] Replace `#ffa742` in DockzoneSurfaceModel.js with `Color.mPrimary` binding (proof of concept)
- [ ] Verify bar surface color updates when wallpaper changes

### 6.2 End-to-end test
- [ ] Set wallpaper → color extraction runs → colors.json written → Color singleton updates → bar color changes
- [ ] Restart shell → wallpaper and colors persist
- [ ] Delete colors.json → defaults restored
- [ ] Invalid wallpaper path → solid color fallback, no crash

## Rollback Points

- Phase 2 (Color singleton) is independently useful — components can bind to it with manual colors.json
- Phase 4 (WallpaperService) can exist without Background rendering (headless wallpaper state)
- Phase 5 (Background) can be disabled by removing from shell.qml without affecting color system
- Phase 6 color migration is incremental — each component can be migrated independently
