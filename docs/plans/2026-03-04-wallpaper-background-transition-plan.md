# Wallpaper Background Rendering & Disc Transition Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace swww-based wallpaper display with QML-native `WlrLayer.Background` rendering,
add a disc-reveal transition on startup and wallpaper change, and provide a folder-browsing
thumbnail picker panel.

**Architecture:** `BackgroundWindow` (per-screen `PanelWindow` at `WlrLayer.Background`) holds
two `Image` elements (current/next) plus an animated `Rectangle` disc mask
(`Qt5Compat.GraphicalEffects.OpacityMask`). `WallpaperService` drops swww polling and gains a
`setWallpaper(path)` function. `WallpaperPickerWindow` uses `FolderListModel` + `GridView` for
folder browsing with thumbnails.

**Tech Stack:** QML/Quickshell (`PanelWindow`, `Variants`, `FolderListModel`,
`Qt5Compat.GraphicalEffects.OpacityMask`), existing `AnimatedPanelBase`.

**Design doc:** `docs/plans/2026-03-04-wallpaper-background-transition-design.md`

---

## Task 1: Extend Settings Schema

**Goal:** Add `wallpaperDirectory` to the appearance settings so the picker remembers the
last-browsed root directory.

**Files:**
- Modify: `services/SettingsService.qml` — `appearance` JsonObject
- Modify: `config/settings-default.json` — matching default key

### Step 1: Add `wallpaperDirectory` to SettingsService

In `services/SettingsService.qml`, inside `property JsonObject appearance`, append after
`property bool darkMode: true`:

```qml
        property string wallpaperDirectory: ""
```

### Step 2: Add to settings-default.json

In `config/settings-default.json`, inside `"appearance"`, append after `"darkMode": true`:

```json
        "wallpaperDirectory": ""
```

### Step 3: Verify

Start shell; open Appearance settings; confirm no console errors. Confirm `wallpaperDirectory`
appears in `~/.config/dymicshell/settings.json` after a save.

### Step 4: Commit

```bash
git add services/SettingsService.qml config/settings-default.json
git commit -m "feat(settings): add wallpaperDirectory to appearance schema"
```

---

## Task 2: Refactor WallpaperService — Remove swww, Add setWallpaper()

**Goal:** Drop swww polling; expose a single `setWallpaper(path)` API that updates settings,
emits the signal, and delegates to matugen.

**Files:**
- Modify: `services/WallpaperService.qml`

### Step 1: Remove swww artefacts

Delete the two swww items:
- `Timer { id: swwwPollTimer; ... }` — entire block
- `Process { id: swwwQueryProcess; ... }` — entire block plus its nested `stdout: StdioCollector`

### Step 2: Add `setWallpaper(path)` public function

Add after the existing `function triggerMatugen()`:

```qml
    // Public: apply a new wallpaper path — updates settings, signals BackgroundWindow,
    // and triggers matugen (if enabled). Prefer this over writing wallpaperPath directly.
    function setWallpaper(path) {
        if (!path || path === "") return
        if (path === SettingsService.data.appearance.wallpaperPath) return
        SettingsService.data.appearance.wallpaperPath = path
        root.wallpaperChanged(path)
        debounceTimer.restart()
    }
```

### Step 3: Wire `onEditingFinished` in AppearancePage to setWallpaper

In `modules/bar/settings/AppearancePage.qml`, the `TextInput#wallpaperInput`
`onEditingFinished` handler currently writes directly to settings and calls
`WallpaperService.triggerMatugen()`. Replace both lines:

```qml
// OLD:
SettingsService.data.appearance.wallpaperPath = trimmed
WallpaperService.triggerMatugen()

// NEW:
WallpaperService.setWallpaper(trimmed)
```

Do the same for the `FileDialog#wallpaperFileDialog` `onAccepted` handler:

```qml
// OLD:
SettingsService.data.appearance.wallpaperPath = path
WallpaperService.triggerMatugen()

// NEW:
WallpaperService.setWallpaper(path)
```

### Step 4: Verify

Manually type a valid wallpaper path in the text field and press Enter. Confirm settings.json
updates and matugen runs (check console for `matugen exited with code 0`).

### Step 5: Commit

```bash
git add services/WallpaperService.qml modules/bar/settings/AppearancePage.qml
git commit -m "refactor(wallpaper): remove swww polling, add setWallpaper() API"
```

---

## Task 3: Add wallpaperPickerOpen to BarLayoutService

**Goal:** Expose a boolean gate so any component can open/close the picker panel without
polling `BarLayoutService` for unrelated state.

**Files:**
- Modify: `services/BarLayoutService.qml`

### Step 1: Add property

In `services/BarLayoutService.qml`, after `property bool widgetPickerOpen: false`, add:

```qml
    // True while the wallpaper picker panel is visible.
    property bool wallpaperPickerOpen: false
```

### Step 2: Update browse button in AppearancePage

In `modules/bar/settings/AppearancePage.qml`, the `MouseArea#browseBtnArea`
`onClicked` currently calls `wallpaperFileDialog.open()`. Replace with:

```qml
onClicked: BarLayoutService.wallpaperPickerOpen = true
```

Also remove the `FileDialog { id: wallpaperFileDialog; ... }` block entirely (the new picker
replaces it; reduces portal dependency).

### Step 3: Verify

Start shell. Click "浏览" in Appearance → Wallpaper section. Confirm no errors. The picker
panel doesn't exist yet so nothing visual will show; only `BarLayoutService.wallpaperPickerOpen`
should flip to `true` in debugger / console log.

### Step 4: Commit

```bash
git add services/BarLayoutService.qml modules/bar/settings/AppearancePage.qml
git commit -m "feat(layout): add wallpaperPickerOpen gate to BarLayoutService"
```

---

## Task 4: Create WallpaperPickerItem.qml

**Goal:** A single reusable card component for the picker grid — renders a thumbnail for image
files, a folder icon for directories, and a clipped filename label.

**Files:**
- Create: `modules/background/WallpaperPickerItem.qml`

### Step 1: Write the file

```qml
import QtQuick
import qs.config

// Single card in the WallpaperPickerWindow grid.
//
// - Image files: thumbnail via Image element
// - Directories: folder icon (Unicode glyph)
// Clicking triggers onSelected(filePath, isDir).
Item {
    id: root

    property string filePath: ""
    property string fileName: ""
    property bool   isDir:    false

    signal selected(string filePath, bool isDir)

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 4
        radius: Theme.cornerRadius
        color: cardArea.containsMouse
            ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.8)
            : Colors.surface
        border.color: Colors.border
        border.width: 1
        clip: true

        Behavior on color { ColorAnimation { duration: 120 } }

        // Folder icon
        Text {
            visible: root.isDir
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -8
            text: "\uD83D\uDCC1"   // 📁
            font.pixelSize: 32
        }

        // Image thumbnail
        Image {
            visible: !root.isDir
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: labelBg.top
            }
            source: root.isDir ? "" : "file://" + root.filePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
        }

        // Filename label background
        Rectangle {
            id: labelBg
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 22
            color: Qt.rgba(0, 0, 0, 0.55)
        }

        // Filename label
        Text {
            anchors.fill: labelBg
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            verticalAlignment: Text.AlignVCenter
            text: root.fileName
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
            color: "#ffffff"
            elide: Text.ElideRight
        }

        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.selected(root.filePath, root.isDir)
        }
    }
}
```

### Step 2: Verify syntax

Open the file in the editor; confirm no red underlines from the QML language server.

### Step 3: Commit

```bash
git add modules/background/WallpaperPickerItem.qml
git commit -m "feat(background): add WallpaperPickerItem thumbnail card"
```

---

## Task 5: Create WallpaperPickerWindow.qml

**Goal:** Full folder-browsing thumbnail picker panel using `FolderListModel` + `GridView`,
opened via `BarLayoutService.wallpaperPickerOpen`.

**Files:**
- Create: `modules/background/WallpaperPickerWindow.qml`

### Step 1: Determine the default root directory helper

The root directory defaults to `~/Pictures/Wallpapers` when `wallpaperDirectory` is empty:

```qml
readonly property string _effectiveRoot: {
    const saved = SettingsService.data.appearance.wallpaperDirectory
    if (saved && saved !== "") return saved
    return Quickshell.env("HOME") + "/Pictures/Wallpapers"
}
```

### Step 2: Write WallpaperPickerWindow.qml

```qml
pragma ComponentBehavior: Bound

import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Wallpaper browser panel — folder navigation + thumbnail grid.
// Opened when BarLayoutService.wallpaperPickerOpen is true.
// Selecting an image calls WallpaperService.setWallpaper(path) and closes the panel.
AnimatedPanelBase {
    id: root

    anchors { top: true; right: true }
    margins { top: Theme.barHeight }

    implicitWidth: 520
    implicitHeight: 600

    focusable: true

    active: BarLayoutService.wallpaperPickerOpen
    onActiveChanged: if (!active) BarLayoutService.wallpaperPickerOpen = false

    // ── Directory state ───────────────────────────────────────────────────
    readonly property string _effectiveRoot: {
        const saved = SettingsService.data.appearance.wallpaperDirectory
        if (saved && saved !== "") return saved
        return Quickshell.env("HOME") + "/Pictures/Wallpapers"
    }
    property string currentDirectory: _effectiveRoot

    function navigateUp() {
        const parts = currentDirectory.split("/").filter(s => s !== "")
        const rootParts = _effectiveRoot.split("/").filter(s => s !== "")
        if (parts.length <= rootParts.length) return   // already at root
        parts.pop()
        currentDirectory = "/" + parts.join("/")
    }

    // ── FolderListModel ──────────────────────────────────────────────────
    FolderListModel {
        id: folderModel
        folder: Qt.resolvedUrl(root.currentDirectory)
        showDirs:         true
        showFiles:        true
        nameFilters:      ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.avif", "*.bmp"]
        sortField:        FolderListModel.Name
        showOnlyReadable: true
        showDotAndDotDot: false
    }

    // ── Visual shell ─────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        anchors { topMargin: 4; rightMargin: 4; bottomMargin: 4 }
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            // ── Navigation bar ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Up button
                Rectangle {
                    width: 28; height: 28
                    radius: 4
                    color: upArea.containsMouse ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.15) : "transparent"
                    border.color: Colors.border; border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "←"
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                    MouseArea {
                        id: upArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigateUp()
                    }
                }

                // Current path label
                Text {
                    Layout.fillWidth: true
                    text: root.currentDirectory
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    elide: Text.ElideLeft
                    verticalAlignment: Text.AlignVCenter
                }

                // Close button
                Rectangle {
                    width: 28; height: 28
                    radius: 4
                    color: closeArea.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.15) : "transparent"
                    border.color: Colors.border; border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.textMuted
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BarLayoutService.wallpaperPickerOpen = false
                    }
                }
            }

            // ── Thumbnail grid ────────────────────────────────────────
            GridView {
                id: pickerGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                cellWidth:  115
                cellHeight: 115
                clip: true

                model: folderModel

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: WallpaperPickerItem {
                    width:    pickerGrid.cellWidth
                    height:   pickerGrid.cellHeight
                    filePath: model.filePath
                    fileName: model.fileName
                    isDir:    model.fileIsDir

                    onSelected: (path, isDir) => {
                        if (isDir) {
                            root.currentDirectory = path
                        } else {
                            WallpaperService.setWallpaper(path)
                            BarLayoutService.wallpaperPickerOpen = false
                        }
                    }
                }
            }
        }
    }
}
```

### Step 3: Register in shell.qml

In `shell.qml`, add import and instantiation:

```qml
import qs.modules.background

ShellRoot {
    BarWindow {}
    SettingsPanelWindow {}
    ContextMenuBackdrop {}
    WidgetPickerWindow {}
    WallpaperPickerWindow {}   // ← new
}
```

### Step 4: Verify

Start shell. Click "浏览" in Appearance. Picker panel should appear (top-right, below bar)
with the contents of `~/Pictures/Wallpapers`. Navigate folders, click an image → wallpaper
path updates in settings. Close button works.

### Step 5: Commit

```bash
git add modules/background/WallpaperPickerWindow.qml shell.qml
git commit -m "feat(background): add WallpaperPickerWindow with FolderListModel grid"
```

---

## Task 6: Create BackgroundWindow.qml — Static Display

**Goal:** Render the wallpaper at `WlrLayer.Background` using a QML `Image`, one per screen.
No transition animation yet — just static display to confirm the layer works.

**Files:**
- Create: `modules/background/BackgroundWindow.qml`

### Step 1: Write BackgroundWindow.qml (static version)

```qml
pragma ComponentBehavior: Bound

import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Per-screen background rendering layer.
// Displays the wallpaper stored in SettingsService.data.appearance.wallpaperPath.
// The disc transition is added in the next task.
Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: bgRoot
        required property var modelData

        screen: modelData
        color: "#000000"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dymicshell:background"
        anchors { top: true; bottom: true; left: true; right: true }

        Image {
            id: wallpaper
            anchors.fill: parent
            source: SettingsService.data.appearance.wallpaperPath !== ""
                ? "file://" + SettingsService.data.appearance.wallpaperPath
                : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
        }
    }
}
```

### Step 2: Register in shell.qml

```qml
import qs.modules.background

ShellRoot {
    BackgroundWindow {}    // ← first window in stack (bottom layer)
    BarWindow {}
    SettingsPanelWindow {}
    ContextMenuBackdrop {}
    WidgetPickerWindow {}
    WallpaperPickerWindow {}
}
```

### Step 3: Verify

Start shell with a valid wallpaper path set in settings. Confirm:
- Wallpaper renders at the background layer
- Bar and other windows appear on top
- No console errors about wlr-layer-shell

### Step 4: Commit

```bash
git add modules/background/BackgroundWindow.qml shell.qml
git commit -m "feat(background): add static BackgroundWindow at WlrLayer.Background"
```

---

## Task 7: Add Disc Transition to BackgroundWindow

**Goal:** Animate the wallpaper switch with a disc (growing circle) reveal using
`Qt5Compat.GraphicalEffects.OpacityMask`.

**Files:**
- Modify: `modules/background/BackgroundWindow.qml`

### Step 1: Replace the static BackgroundWindow with the animated version

Rewrite `BackgroundWindow.qml` completely:

```qml
pragma ComponentBehavior: Bound

import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Per-screen wallpaper rendering with disc-reveal transition.
//
// Startup: disc expands from center (discCenterX=0.5, discCenterY=0.5).
// Change:  disc expands from a random point on screen.
//
// Animation: transitionProgress 0→1 controls discMask circle diameter.
// When complete: currentWallpaper takes nextWallpaper's source, nextWallpaper cleared.
Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: bgRoot
        required property var modelData

        screen: modelData
        color: "#000000"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dymicshell:background"
        anchors { top: true; bottom: true; left: true; right: true }

        // ── Transition state ──────────────────────────────────────────
        property real transitionProgress: 0.0
        property real discCenterX: 0.5
        property real discCenterY: 0.5

        // Diagonal length → disc reaches every corner regardless of center point
        readonly property real discMaxRadius: Math.hypot(bgRoot.width, bgRoot.height)

        // ── Images ───────────────────────────────────────────────────
        Image {
            id: currentWallpaper
            anchors.fill: parent
            source: ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
        }

        Image {
            id: nextWallpaper
            anchors.fill: parent
            source: ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
            visible: false   // used only as texture for OpacityMask
        }

        // ── Disc mask ─────────────────────────────────────────────────
        // Invisible rectangle sized as expanding circle; used as opacity mask shape.
        Rectangle {
            id: discMask
            visible: false
            color:  "white"
            radius: width / 2
            width:  bgRoot.transitionProgress * bgRoot.discMaxRadius * 2
            height: width
            x: bgRoot.discCenterX * bgRoot.width  - width  / 2
            y: bgRoot.discCenterY * bgRoot.height - height / 2
        }

        // ── Masked next-wallpaper layer (stacked above currentWallpaper) ──
        OpacityMask {
            anchors.fill: nextWallpaper
            source:       nextWallpaper
            maskSource:   discMask
        }

        // ── Animation ────────────────────────────────────────────────
        NumberAnimation {
            id: discAnim
            target:   bgRoot
            property: "transitionProgress"
            from: 0.0; to: 1.0
            duration: 900
            easing.type: Easing.OutCubic
            onStopped: {
                if (bgRoot.transitionProgress >= 1.0) {
                    bgRoot._swapAndReset()
                }
            }
        }

        // ── Startup timer ─────────────────────────────────────────────
        // Wait for compositor to map the window before starting transition.
        Timer {
            id: startupTimer
            interval: 150
            onTriggered: discAnim.start()
        }

        // ── Initialization ────────────────────────────────────────────
        Component.onCompleted: _initWallpaper()

        function _initWallpaper() {
            const path = SettingsService.data.appearance.wallpaperPath
            if (!path || path === "") return
            bgRoot.discCenterX = 0.5
            bgRoot.discCenterY = 0.5
            nextWallpaper.source = "file://" + path
        }

        Connections {
            target: nextWallpaper
            function onStatusChanged() {
                if (nextWallpaper.status === Image.Ready && !discAnim.running) {
                    startupTimer.start()
                }
            }
        }

        // ── Wallpaper change handler ──────────────────────────────────
        Connections {
            target: WallpaperService
            function onWallpaperChanged(path) {
                if (discAnim.running) {
                    // Interrupt: snap current state
                    discAnim.stop()
                    bgRoot._swapAndReset()
                }
                bgRoot.discCenterX = Math.random()
                bgRoot.discCenterY = Math.random()
                nextWallpaper.source = "file://" + path
                // Animation starts when nextWallpaper.onStatusChanged fires
            }
        }

        // Called when disc animation completes: promote next → current.
        function _swapAndReset() {
            currentWallpaper.source = nextWallpaper.source
            transitionProgress = 0.0
            // Small delay to let currentWallpaper bind before clearing next
            Qt.callLater(() => { nextWallpaper.source = "" })
        }
    }
}
```

### Step 2: Import Qt5Compat in project (if not already used)

Check if `Qt5Compat.GraphicalEffects` is already imported elsewhere in the project:

```bash
grep -r "Qt5Compat" /home/Sighthesia/0_Files/Producing/Software/Quickshell/DymicShell --include="*.qml"
```

If no results, confirm the Qt5Compat module is available on the system:
```bash
qml6 -e "import Qt5Compat.GraphicalEffects; console.log('ok')"
```

### Step 3: Verify disc transition on wallpaper change

1. Start shell with a wallpaper set.
2. Open the wallpaper picker, select a different image.
3. Observe: disc expands from a random point to reveal the new wallpaper.
4. Observe: startup (first shell launch) shows disc from center.

### Step 4: Commit

```bash
git add modules/background/BackgroundWindow.qml
git commit -m "feat(background): add disc-reveal transition via OpacityMask"
```

---

## Task 8: Persist wallpaperDirectory in Picker

**Goal:** When the user navigates to a subdirectory in the picker, remember it as the next
default starting location.

**Files:**
- Modify: `modules/background/WallpaperPickerWindow.qml`

### Step 1: Save current directory to settings on navigate

In `WallpaperPickerWindow.qml`, add an `onCurrentDirectoryChanged` handler:

```qml
onCurrentDirectoryChanged: {
    SettingsService.data.appearance.wallpaperDirectory = root.currentDirectory
}
```

### Step 2: Verify

Navigate into a subfolder in the picker. Close and reopen. Confirm picker reopens in the last
visited directory.

### Step 3: Commit

```bash
git add modules/background/WallpaperPickerWindow.qml
git commit -m "feat(picker): persist last-browsed wallpaper directory to settings"
```

---


**Goal:** Confirm all pieces work together with no regressions.

### Checklist

1. Shell starts → wallpaper appears via disc reveal from center
2. Open Settings → Appearance → click "浏览" → picker opens at correct directory
3. Navigate into subfolder → path updates in nav bar
4. Click an image → wallpaper switches with disc reveal from random point
5. Reopen picker → starts in last-visited directory
6. Type a path manually in text field + Enter → wallpaper switches
7. Enable "动态主题色" → matugen runs, colors update
8. Hot-reload shell (`qs reload`) → wallpaper still shows correctly
9. Confirm no swww daemon is required for the shell to start

### Fix & Commit

If any checklist item fails, fix and commit:

```bash
git commit -m "fix(background): <description of fix>"
```
