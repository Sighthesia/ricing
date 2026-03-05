# Wallpaper Background Rendering & Disc Transition Design

**Date:** 2026-03-04
**Status:** Approved

## Overview

Replace swww-based wallpaper display with a QML-native `WlrLayer.Background` rendering layer.
Wallpaper switching uses a **disc reveal** transition (growing circle via `OpacityMask`), fired
on shell startup and every time the user picks a new wallpaper. A new `WallpaperPickerWindow`
provides folder-browsing and thumbnail-grid selection.

## Reference Projects

| Project               | Pattern adopted                                                                                                                                                       |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **noctalia-shell**    | `Variants { model: Quickshell.screens }` per-screen `PanelWindow` at `WlrLayer.Background`; dual-`Image` + transition animation; `performStartupTransition()` pattern |
| **illogical-impulse** | `FolderListModel` file-browser picker; `apply(path)` service function; random-from-folder helpers                                                                     |
| **DankMaterialShell** | Per-monitor wallpaper cycling service; `currentWallpapers` map pattern                                                                                                |

## Architecture

```
BackgroundWindow (WlrLayer.Background, per-screen)
  ├─ Image currentWallpaper  ← source = displayed path
  ├─ Image nextWallpaper     ← source = incoming path (hidden, texture only)
  ├─ Rectangle discMask      ← animated circle, invisible, used as mask shape
  └─ OpacityMask             ← clips nextWallpaper through discMask, stacked above current

WallpaperPickerWindow (AnimatedPanelBase, top-right, below bar)
  ├─ FolderListModel         ← lists current directory
  └─ GridView                ← thumbnail cards + folder cards

WallpaperService (Singleton, modified)
  ├─ setWallpaper(path)      ← updates settings + emits signal + triggers matugen
  ├─ wallpaperChanged(path)  ← observed by BackgroundWindow
  └─ [removed] swww polling  ← no longer needed
```

## New / Modified Files

| File                                           | Status     | Responsibility                                    |
| ---------------------------------------------- | ---------- | ------------------------------------------------- |
| `modules/background/BackgroundWindow.qml`      | **New**    | Per-screen wallpaper rendering + disc transition  |
| `modules/background/WallpaperPickerWindow.qml` | **New**    | Folder-browsing wallpaper picker panel            |
| `modules/background/WallpaperPickerItem.qml`   | **New**    | Single thumbnail/folder card                      |
| `services/WallpaperService.qml`                | **Modify** | Remove swww poll; add `setWallpaper()`            |
| `shell.qml`                                    | **Modify** | Register BackgroundWindow + WallpaperPickerWindow |
| `modules/bar/settings/AppearancePage.qml`      | **Modify** | Add "浏览…" button next to wallpaper path field   |
| `services/BarLayoutService.qml`                | **Modify** | Add `wallpaperPickerOpen: bool` property          |

## BackgroundWindow Design

### Properties

```qml
property real transitionProgress: 0   // 0 = current fully visible, 1 = next fully visible
property real discCenterX: 0.5        // normalized [0,1]
property real discCenterY: 0.5        // normalized [0,1]
property bool isStartupTransition: true
```

### Layer Structure

```
PanelWindow (WlrLayer.Background, anchors: fill)
└── Item (clip: false)
    ├── Image currentWallpaper     fillMode: PreserveAspectCrop, cache: false
    ├── Image nextWallpaper        fillMode: PreserveAspectCrop, cache: false, visible: false
    ├── Rectangle discMask         (white, radius: width/2, visible: false)
    │     x: discCenterX * parent.width - width/2
    │     y: discCenterY * parent.height - height/2
    │     width:  transitionProgress * discMaxRadius * 2
    │     height: width
    └── OpacityMask                (source: nextWallpaper, maskSource: discMask)
          anchors.fill: nextWallpaper
```

`discMaxRadius = Math.hypot(screen.width, screen.height)` — guarantees coverage regardless of
center position.

### Transition Animation

```qml
NumberAnimation {
    id: discAnim
    target: root
    property: "transitionProgress"
    from: 0.0; to: 1.0
    duration: 900
    easing.type: Easing.OutCubic
    onStopped: _swapAndReset()  // currentWallpaper ← nextWallpaper.source; cleanup
}
```

### Startup Flow

```
Component.onCompleted
  → _waitForServices()       // retry via Qt.callLater() until SettingsService ready
  → nextWallpaper.source = SettingsService.data.appearance.wallpaperPath
  → wait for nextWallpaper.status === Image.Ready
  → startupTransitionTimer.start()  // 150 ms to let compositor map the window
  → discCenterX = 0.5, discCenterY = 0.5
  → discAnim.start()
  → onStopped: _swapAndReset(); isStartupTransition = false
```

### Wallpaper Change Flow

```
Connections { target: WallpaperService; onWallpaperChanged(path) }
  → nextWallpaper.source = path
  → wait for Image.Ready
  → discCenterX = Math.random(), discCenterY = Math.random()
  → discAnim.start()
  → onStopped: _swapAndReset()
```

## WallpaperService Changes

### Removed

- `swwwPollTimer` — no longer polling
- `swwwQueryProcess` — no longer needed

### Added

```qml
// Public: apply new wallpaper (write to settings + emit signal + trigger matugen)
function setWallpaper(path) {
    if (!path || path === SettingsService.data.appearance.wallpaperPath) return
    SettingsService.data.appearance.wallpaperPath = path
    root.wallpaperChanged(path)
    debounceTimer.restart()            // still debouncing matugen
}
```

### Retained

- `Process matugenProcess` — color extraction still runs on wallpaper changes
- `debounceTimer` — debounces rapid changes before invoking matugen
- `wallpaperChanged(string path)` signal
- `matugenCompleted()` / `matugenFailed(string error)` signals

## WallpaperPickerWindow Design

### Position

Same as `SettingsPanelWindow`:
- `AnimatedPanelBase` with `anchors { top: true; right: true }`
- `margins.top: Theme.barHeight`
- `active: BarLayoutService.wallpaperPickerOpen`

### Layout

```
WallpaperPickerWindow (width: 520, height: 600)
└── Rectangle (card, radius, border)
    ├── RowLayout (navigation bar, height: 36)
    │   ├── Button "←"   (navigateUp; disabled at rootDirectory)
    │   ├── Text         (current directory, elided)
    │   └── Button "✕"   (close picker)
    ├── TextField        (search query, filters by filename)
    └── GridView         (cellWidth: 115, cellHeight: 115, ScrollBar)
        └── WallpaperPickerItem delegate
```

### WallpaperPickerItem

```
Item (115×115)
├── Rectangle (card bg, radius)
│   ├── Image   (source: filePath, fillMode: PreserveAspectCrop)  — for image files
│   ├── Image   (folder icon from assets)                          — for directories
│   └── Text    (filename, elided, bottom-anchored)
└── MouseArea → onClicked:
        if (isDir) root.currentDirectory = filePath
        else { WallpaperService.setWallpaper(filePath); close() }
```

### FolderListModel

```qml
FolderListModel {
    folder: Qt.resolvedUrl(root.currentDirectory)
    showDirs:  true
    showFiles: true
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.avif", "*.bmp"]
    sortField: FolderListModel.Name
    showOnlyReadable: true
    showDotAndDotDot: false
}
```

Default root directory: `SettingsService.data.appearance.wallpaperDirectory` (added to settings),
defaulting to `StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/Wallpapers"`.

## Settings Schema Additions

```json
// Under appearance:
"wallpaperDirectory": ""   // "" = ~/Pictures/Wallpapers
```

## AppearancePage Changes

In the wallpaper path `TextFieldSection`, add a secondary "浏览…" button on the trailing side:

```qml
Button {
    text: "浏览…"
    onClicked: BarLayoutService.wallpaperPickerOpen = true
}
```

## shell.qml Changes

```qml
import qs.modules.background

ShellRoot {
    BackgroundWindow {}    // ← new
    BarWindow {}
    SettingsPanelWindow {}
    ContextMenuBackdrop {}
    WidgetPickerWindow {}
    WallpaperPickerWindow {} // ← new
}
```

## Non-Goals

- Video wallpapers (mpvpaper) — out of scope for this iteration
- Per-monitor different wallpapers — always applies to all screens
- swww compatibility / external wallpaper change detection
