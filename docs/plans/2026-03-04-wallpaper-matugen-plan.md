# Wallpaper Management & Matugen Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add wallpaper management and matugen-based dynamic color extraction to DymicShell.

**Architecture:** A new `WallpaperService` singleton polls `swww query` and invokes `matugen`
when the wallpaper changes, writing the MD3 color palette to `matugen-colors.json`. `Colors.qml`
watches this file and conditionally sources all token colors from it. Settings persistence lives
in `SettingsService.data.appearance` as four new fields.

**Tech Stack:** QML/Quickshell (`Singleton`, `Process`, `FileView`, `JsonAdapter`), matugen CLI.

**Design doc:** `docs/plans/2026-03-04-wallpaper-matugen-design.md`

---

## Task 1: Extend Settings Schema

**Goal:** Add `wallpaperPath`, `matugenEnabled`, `matugenScheme`, `darkMode` to persistence.

**Files:**
- Modify: `services/SettingsService.qml` — `appearance` JsonObject
- Modify: `config/settings-default.json` — matching default keys

### Step 1: Add fields to SettingsService appearance block

In `services/SettingsService.qml`, inside the `property JsonObject appearance` block, append
after the last existing field (`fontSizeIcon`):

```qml
        property string wallpaperPath:  ""
        property bool   matugenEnabled: false
        property string matugenScheme:  "scheme-tonal-spot"
        property bool   darkMode:       true
```

### Step 2: Add fields to settings-default.json

In `config/settings-default.json`, inside the `"appearance"` object, append after `"fontSizeIcon"`:

```json
        "wallpaperPath":  "",
        "matugenEnabled": false,
        "matugenScheme":  "scheme-tonal-spot",
        "darkMode":       true
```

### Step 3: Verify shell starts without errors

Run: `quickshell -p /path/to/DymicShell`
Expected: Shell loads, settings panel opens, Appearance page shows no new errors in console.

### Step 4: Commit

```bash
git add services/SettingsService.qml config/settings-default.json
git commit -m "feat(settings): add wallpaper and matugen fields to appearance schema"
```

---

## Task 2: Create ToggleSection.qml

**Goal:** A reusable labeled toggle switch that follows the same API as SliderSection/TextFieldSection.

**Files:**
- Create: `modules/bar/settings/ToggleSection.qml`

### Step 1: Write ToggleSection.qml

The toggle switch visual code is already proven in `BehaviorSection.qml` (auto-hide toggle).
Extract it into a generic component with the same `filterQuery` / highlight pattern as
`SliderSection.qml`:

```qml
import QtQuick
import qs.config

// A labeled toggle switch row for boolean settings.
//
// Usage:
//   ToggleSection {
//     label: "深色模式"
//     value: SettingsService.data.appearance.darkMode
//     filterQuery: root.searchQuery
//     onToggled: (v) => SettingsService.data.appearance.darkMode = v
//   }
Item {
    id: root

    property string label: ""
    property bool value: false

    signal toggled(bool newValue)

    property string filterQuery: ""

    readonly property bool _matchesFilter: filterQuery === "" ||
        label.toLowerCase().indexOf(filterQuery.toLowerCase()) !== -1

    readonly property bool searchHighlight: filterQuery !== "" && _matchesFilter

    visible: _matchesFilter
    height: _matchesFilter ? implicitHeight : 0

    implicitWidth: 296
    implicitHeight: Theme.settingsRowHeight

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 4; anchors.rightMargin: 4
        radius: 4
        color: Colors.highlight
        opacity: root.searchHighlight ? 0.1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
    }

    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 4 }
        width: 3; radius: 1
        color: Colors.highlight
        opacity: root.searchHighlight ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.settingsPanelPadding
        anchors.rightMargin: Theme.settingsPanelPadding
        spacing: 8

        Text {
            width: Theme.settingsLabelWidth
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
            elide: Text.ElideRight
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 42; height: 24

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: root.value ? Colors.highlight : Colors.surface
                opacity: 0.85
                Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
            }

            Rectangle {
                id: knob
                width: 18; height: 18
                radius: 9
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.text
                x: root.value ? 21 : 3
                Behavior on x {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Easing.InOutCubic }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled(!root.value)
            }
        }
    }
}
```

### Step 2: Commit

```bash
git add modules/bar/settings/ToggleSection.qml
git commit -m "feat(settings): add generic ToggleSection component"
```

---

## Task 3: Create WallpaperService.qml

**Goal:** Singleton that manages wallpaper path, polls swww, invokes matugen, and writes the
output JSON to `~/.config/dymicshell/matugen-colors.json`.

**Files:**
- Create: `services/WallpaperService.qml`

### Step 1: Write WallpaperService.qml

Key design points:
- Uses `Quickshell.Io.Process` for both `swww query` and `matugen image`.
- Accumulates matugen stdout in a buffer string since data arrives in chunks.
- Uses a 800 ms debounce `Timer` to avoid thrashing when a slideshow rapidly fires.
- Writes JSON with a second `Process` using `sh -c` to redirect stdout to file, since
  `FileView.writeText` is the cleanest alternative — use that to avoid shell redirection.
- swww query output format: `<monitor>: image: <path>` — extract the last token.

```qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

Singleton {
    id: root

    // Emitted after a successful wallpaper path change is detected or set.
    signal wallpaperChanged(string path)
    // Emitted after matugen writes colors successfully.
    signal matugenCompleted()
    // Emitted on matugen execution failure.
    signal matugenFailed(string error)

    readonly property bool matugenRunning: matugenProcess.running

    // Debounce rapid wallpaper changes (e.g., slideshows) before invoking matugen.
    Timer {
        id: debounceTimer
        interval: 800
        onTriggered: _runMatugen(SettingsService.data.appearance.wallpaperPath)
    }

    // Poll swww every 5 s. Only active when matugen integration is enabled.
    Timer {
        id: swwwPollTimer
        interval: 5000
        repeat: true
        running: SettingsService.data.appearance.matugenEnabled
        triggeredOnStart: true
        onTriggered: swwwQueryProcess.running = true
    }

    // ── swww query ──────────────────────────────────────────────────────────
    Process {
        id: swwwQueryProcess
        command: ["swww", "query"]

        property string _buf: ""

        stdout: SplitParser {
            onRead: (data) => swwwQueryProcess._buf += data
        }

        onExited: function(exitCode) {
            const buf = _buf.trim()
            _buf = ""
            if (exitCode !== 0 || buf === "") return

            // Each line: "eDP-1: image: /path/to/wallpaper.jpg"
            // Take the last non-empty line and parse the path after "image: ".
            const lines = buf.split("\n").filter(l => l.trim() !== "")
            const last = lines[lines.length - 1]
            const match = last.match(/image:\s+(.+)$/)
            if (!match) return

            const detected = match[1].trim()
            if (detected !== SettingsService.data.appearance.wallpaperPath) {
                SettingsService.data.appearance.wallpaperPath = detected
                root.wallpaperChanged(detected)
                debounceTimer.restart()
            }
        }
    }

    // ── matugen invocation ───────────────────────────────────────────────────
    Process {
        id: matugenProcess

        property string _buf: ""

        stdout: SplitParser {
            onRead: (data) => matugenProcess._buf += data
        }

        onExited: function(exitCode) {
            const buf = _buf.trim()
            _buf = ""
            if (exitCode !== 0 || buf === "") {
                root.matugenFailed("matugen exited with code " + exitCode)
                return
            }
            // Write the JSON output to the config directory.
            matugenColorsWriter.text = buf
            matugenColorsWriter.save()
            root.matugenCompleted()
        }
    }

    // Writes matugen JSON output to disk so Colors.qml can pick it up.
    FileView {
        id: matugenColorsWriter
        path: SettingsService.configDir + "matugen-colors.json"
    }

    // Public: trigger matugen manually (e.g., when user changes the path in UI).
    function triggerMatugen() {
        const path = SettingsService.data.appearance.wallpaperPath
        if (path === "") return
        debounceTimer.restart()
    }

    function _runMatugen(wallpaperPath) {
        if (!SettingsService.data.appearance.matugenEnabled) return
        if (wallpaperPath === "") return
        if (matugenProcess.running) {
            // Still running — reschedule
            debounceTimer.restart()
            return
        }
        const scheme = SettingsService.data.appearance.matugenScheme
        matugenProcess.command = [
            "matugen", "image", wallpaperPath,
            "--json", "hex",
            "--type", scheme
        ]
        matugenProcess.running = true
    }
}
```

**Note on `FileView.save()`:** Quickshell's `FileView` exposes `writeAdapter()` for
`JsonAdapter`-backed views but also an undocumented `text` property + `save()` for plain
text views. Verify in Quickshell docs/source. If `save()` is unavailable, use:
```
["sh", "-c", "cat > " + SettingsService.configDir + "matugen-colors.json"]
```
as a fallback `Process` with stdin piped from the buffer. (FIXME: confirm API before impl.)

### Step 2: Register in qmldir (if needed)

Check if `services/` has a `qmldir` file. If so, add:
```
singleton WallpaperService 1.0 WallpaperService.qml
```
If no `qmldir` exists, Quickshell discovers singletons automatically — no action needed.

### Step 3: Commit

```bash
git add services/WallpaperService.qml
git commit -m "feat: add WallpaperService with swww polling and matugen invocation"
```

---

## Task 4: Update Colors.qml for Dynamic Theming

**Goal:** `Colors.qml` watches `matugen-colors.json`; when `matugenEnabled` and the file
is loaded, all six color tokens switch to matugen values.

**Files:**
- Modify: `config/Colors.qml`

### Step 1: Add FileView and parsed data property

Add inside the `Singleton { id: root }` body, after the existing `readonly property` block:

```qml
    // Parsed matugen output JSON; null when file absent or invalid.
    property var _matugenColors: null

    readonly property bool _usingMatugen:
        SettingsService.data.appearance.matugenEnabled && _matugenColors !== null

    readonly property bool _dark: SettingsService.data.appearance.darkMode

    FileView {
        id: matugenColorsView
        path: SettingsService.configDir + "matugen-colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root._matugenColors = JSON.parse(text)
            } catch (e) {
                root._matugenColors = null
            }
        }
        onLoadFailed: { root._matugenColors = null }
    }

    // Helper: safely access a matugen color key; returns fallback on missing.
    function _mc(key, fallback) {
        if (!_matugenColors) return fallback
        const node = _dark ? _matugenColors.colors.dark : _matugenColors.colors.light
        return node && node[key] ? node[key] : fallback
    }
```

### Step 2: Rewrite all six color properties

Replace the six existing `readonly property color` declarations with conditional variants:

```qml
    readonly property color background:
        _usingMatugen ? _mc("background",        SettingsService.data.appearance.backgroundColor)
                      : SettingsService.data.appearance.backgroundColor

    readonly property color surface:
        _usingMatugen ? _mc("surface_container", SettingsService.data.appearance.surfaceColor)
                      : SettingsService.data.appearance.surfaceColor

    readonly property color highlight:
        _usingMatugen ? _mc("primary",           SettingsService.data.appearance.accentColor)
                      : SettingsService.data.appearance.accentColor

    readonly property color text:
        _usingMatugen ? _mc("on_surface",        SettingsService.data.appearance.textColor)
                      : SettingsService.data.appearance.textColor

    readonly property color textMuted:
        _usingMatugen ? _mc("on_surface_variant",SettingsService.data.appearance.textMutedColor)
                      : SettingsService.data.appearance.textMutedColor

    readonly property color border:
        _usingMatugen ? _mc("outline_variant",   SettingsService.data.appearance.borderColor)
                      : SettingsService.data.appearance.borderColor
```

Remove the `// FIXME: matugen integration` comment.

### Step 3: Verify color fallback works

Open settings panel → `matugenEnabled` is false (default) → colors should be identical to
pre-change behavior. No visual regression expected.

### Step 4: Commit

```bash
git add config/Colors.qml
git commit -m "feat(colors): add dynamic matugen color source with FileView watcher"
```

---

## Task 5: Add Wallpaper UI to AppearancePage

**Goal:** New "壁纸 & 动态主题色" ExpandableGroup in the settings panel; existing "颜色"
group dims when matugen is enabled.

**Files:**
- Modify: `modules/bar/settings/AppearancePage.qml`

### Step 1: Add "壁纸 & 动态主题色" group

Insert a new `ExpandableGroup` **before** the existing `groupColors` block. Recall that
`ToggleSection` was created in Task 2. The scheme picker uses a `Repeater` over a model
of option strings (same pattern as position picker in `BehaviorSection.qml`).

```qml
            // ── 壁纸 & 动态主题色 ──────────────────────────────────────
            ExpandableGroup {
                id: groupWallpaper
                title: "壁纸 & 动态主题色"
                expanded: false
                forceExpand: root.groupMatches(["壁纸路径","动态主题色","配色算法","深色模式"])
                visible: root.searchQuery === "" ||
                         root.groupMatches(["壁纸路径","动态主题色","配色算法","深色模式"])
                height: visible ? implicitHeight : 0

                // ── Wallpaper path ──
                TextFieldSection {
                    label: "壁纸路径"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.wallpaperPath
                    onValueCommitted: function(v) {
                        SettingsService.data.appearance.wallpaperPath = v
                        WallpaperService.triggerMatugen()
                    }
                }

                // ── Enable dynamic theming ──
                ToggleSection {
                    label: "动态主题色"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.matugenEnabled
                    onToggled: function(v) {
                        SettingsService.data.appearance.matugenEnabled = v
                        if (v) WallpaperService.triggerMatugen()
                    }
                }

                // ── Dark mode ──
                ToggleSection {
                    label: "深色模式"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.darkMode
                    onToggled: function(v) {
                        SettingsService.data.appearance.darkMode = v
                        if (SettingsService.data.appearance.matugenEnabled)
                            WallpaperService.triggerMatugen()
                    }
                }

                // ── Scheme type picker (visible only when matugen is on) ──
                Item {
                    visible: SettingsService.data.appearance.matugenEnabled
                    height: visible ? Theme.settingsRowHeight : 0
                    width: parent.width

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.settingsPanelPadding
                        anchors.rightMargin: Theme.settingsPanelPadding
                        spacing: 8

                        Text {
                            width: Theme.settingsLabelWidth
                            anchors.verticalCenter: parent.verticalCenter
                            text: "配色算法"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.textMuted
                            elide: Text.ElideRight
                        }

                        Flickable {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.settingsLabelWidth - parent.spacing
                            height: Theme.settingsRowHeight
                            contentWidth: schemeRow.implicitWidth
                            clip: true

                            Row {
                                id: schemeRow
                                spacing: 4

                                Repeater {
                                    model: [
                                        "scheme-tonal-spot",
                                        "scheme-vibrant",
                                        "scheme-expressive",
                                        "scheme-fidelity",
                                        "scheme-neutral",
                                        "scheme-monochrome"
                                    ]

                                    delegate: Rectangle {
                                        required property string modelData
                                        required property int index

                                        readonly property bool selected:
                                            SettingsService.data.appearance.matugenScheme === modelData

                                        // Show short label (strip "scheme-" prefix)
                                        readonly property string shortLabel:
                                            modelData.replace("scheme-", "")

                                        width: schemeLabel.implicitWidth + 12
                                        height: 22
                                        radius: Theme.cornerRadius - 4
                                        color: selected ? Colors.highlight : Colors.surface
                                        opacity: selected ? 0.9 : 0.55
                                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                                        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }

                                        Text {
                                            id: schemeLabel
                                            anchors.centerIn: parent
                                            text: parent.shortLabel
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Colors.text
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                SettingsService.data.appearance.matugenScheme = parent.modelData
                                                WallpaperService.triggerMatugen()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
```

### Step 2: Dim existing "颜色" group when matugen is active

In the `groupColors` ExpandableGroup, add an opacity binding:

```qml
            ExpandableGroup {
                id: groupColors
                // ...existing props...
                opacity: SettingsService.data.appearance.matugenEnabled ? 0.4 : 1.0
                Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
```

### Step 3: Update scrollToSection map

In `scrollToSection`, add `"wallpaper": groupWallpaper` to the `map` object.

### Step 4: Update clearAllHighlights

Add `groupWallpaper.highlighted = false` to the `clearAllHighlights` function body.

### Step 5: Add import for WallpaperService

Add `import qs.services` if not already present (it is, since `SettingsService` is used).

### Step 6: Verify visually

1. Open settings → Appearance → "壁纸 & 动态主题色" group appears and expands.
2. Enter a wallpaper path → no crash.
3. Toggle "动态主题色" on → "颜色" group dims to 40% opacity.
4. "配色算法" picker appears.

### Step 7: Commit

```bash
git add modules/bar/settings/AppearancePage.qml
git commit -m "feat(settings): add wallpaper and matugen UI to AppearancePage"
```

---


**Goal:** End-to-end test: set a real wallpaper path with matugen installed.

### Step 1: Verify matugen is installed

```bash
matugen --version
```
Expected: prints version string (e.g., `matugen 2.x.x`)

### Step 2: Run matugen manually to confirm output format

```bash
matugen image ~/wallpaper.jpg --json hex --type scheme-tonal-spot
```
Expected: JSON printed to stdout with `{ "colors": { "dark": {...}, "light": {...} } }` structure.
Verify keys `background`, `surface_container`, `primary`, `on_surface`, `on_surface_variant`,
`outline_variant` exist inside `colors.dark`.

### Step 3: Set wallpaper path in settings panel

Open DymicShell settings → Appearance → "壁纸 & 动态主题色" → enter path → press Enter.
Toggle "动态主题色" on.
Expected: bar colors update within ~1 second.

### Step 4: Test swww auto-detection

Change wallpaper externally:
```bash
swww img ~/other-wallpaper.jpg
```
Wait ≤10 s.
Expected: shell colors update automatically.

### Step 5: Final commit

```bash
git add -A
git commit -m "chore: wallpaper+matugen integration complete"
```

---

## Appendix: FileView Write API Note

Before Task 3, run this search to confirm `FileView` write API in the installed
Quickshell version:

```bash
grep -r "writeText\|\.text =\|save()" ~/.local/share/quickshell/ 2>/dev/null | head -20
quickshell --docs 2>/dev/null | grep -A5 FileView
```

If `FileView` does not support direct text writing, replace the matugen JSON write step
in `WallpaperService` with:

```qml
Process {
    id: jsonWriteProcess
    command: ["sh", "-c",
        "printf '%s' " + JSON.stringify(buffer) + " > " +
        SettingsService.configDir + "matugen-colors.json"
    ]
}
```

Or pipe via stdin using a `Process` with `stdin` writer.
