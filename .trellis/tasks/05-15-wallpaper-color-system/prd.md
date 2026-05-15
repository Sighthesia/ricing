# Wallpaper Rendering & Material You Color System

## Goal

Implement a complete wallpaper management layer and dynamic color theming system for afloat. The wallpaper layer renders background images via PanelWindow on WlrLayer.Background with transition animations. The color system extracts Material You palettes from the active wallpaper and exposes M3 color tokens as a QML singleton consumed by all visual components.

## Context

afloat currently has no wallpaper rendering or color theming. All colors are hardcoded literals. The reference implementation is noctalia-shell, which provides:
- WallpaperService managing per-screen wallpaper state with persistence
- Background module rendering wallpapers with shader-based transitions
- Python-based Material You color extraction (Wu quantizer + HCT + M3 scheme generation)
- Color.qml singleton exposing 48 M3 tokens with animated transitions

afloat will adapt this architecture to its simpler scope while reusing noctalia's proven Python color extraction pipeline.

## Requirements

### R1: Wallpaper Rendering

- PanelWindow per screen on WlrLayer.Background via `Variants { model: Quickshell.screens }`
- Image display with proper fill mode (cover/contain) respecting screen resolution and HiDPI scale
- Transition animation between wallpapers (fade at minimum; extensible for more types)
- Dual-image swap pattern: currentWallpaper + nextWallpaper with async loading

### R2: Wallpaper Service

- Singleton `WallpaperService` owning wallpaper state
- `currentWallpaper` property (path per screen, or single path for all screens V1)
- `changeWallpaper(path)` function triggering transition and color re-extraction
- `wallpaperChanged(path)` signal for downstream consumers
- Persistence of current wallpaper path via FileView + JsonAdapter
- Graceful fallback to solid color on missing/invalid wallpaper

### R3: Color Extraction

- Invoke noctalia's Python `template-processor.py` via Quickshell `Process`
- Input: wallpaper image path
- Output: JSON file with M3 color scheme (16+ named colors)
- Debounce extraction (150ms) to coalesce rapid wallpaper changes
- Output path: `~/.cache/afloat/colors.json`

### R4: Color Singleton

- `Color.qml` singleton in `services/` exposing M3 color properties
- Load colors from `~/.cache/afloat/colors.json` via FileView with `watchChanges: true`
- Properties: mPrimary, mOnPrimary, mPrimaryContainer, mOnPrimaryContainer, mSecondary, mOnSecondary, mSecondaryContainer, mOnSecondaryContainer, mTertiary, mOnTertiary, mTertiaryContainer, mOnTertiaryContainer, mSurface, mOnSurface, mSurfaceVariant, mOnSurfaceVariant
- Smooth ColorAnimation on property changes
- Fallback default colors when JSON is missing/corrupt

### R5: Integration

- Wallpaper change automatically triggers color extraction (when enabled)
- Color singleton is importable from any QML module via services/ qmldir
- Existing bar components can bind to Color.mPrimary etc. to replace hardcoded values

## Constraints

- Must work with Quickshell's Wayland PanelWindow model (WlrLayer.Background)
- Reuse noctalia's Python scripts (symlink or copy into project scripts/ directory)
- No new system dependencies beyond Python 3 + ImageMagick (already required by noctalia scripts)
- Keep WallpaperService and ColorService as separate singletons (SRP)
- FileView persistence pattern consistent with existing BarLayoutService

## Acceptance Criteria

- [ ] Wallpaper renders on all screens behind other shell surfaces
- [ ] Changing wallpaper triggers a fade transition
- [ ] Wallpaper path persists across shell restarts
- [ ] Color extraction runs automatically on wallpaper change
- [ ] Color.qml exposes 16 M3 color properties
- [ ] Color properties animate smoothly on palette change
- [ ] Missing wallpaper falls back to solid color
- [ ] Missing/corrupt colors.json falls back to default palette
- [ ] Bar surface can bind to Color.mPrimary (integration proof)
