# Workspace Island Widget — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the numeric workspace widget with a Dynamic Island that shows per-workspace app icons and expands downward to display the focused window title.

**Architecture:** Single-widget replacement (`WorkspaceWidget.qml`) plus two minimal layout fixes (`BarWindow.qml`, `BarContent.qml`). The bar window surface grows by 30px (transparent overlay) while `exclusiveZone` stays at `Theme.barHeight` — the island expands into this transparent space using `clip: false`.

**Tech Stack:** QML/Quickshell. Uses `NiriService` (already present), `DesktopEntries.heuristicLookup()`, `Quickshell.iconPath()` — both native Quickshell APIs, no new imports or services needed.

---

### Task 1: Extend BarWindow surface without affecting exclusiveZone

**Files:**
- Modify: `modules/bar/BarWindow.qml`

**Step 1: Open and read the file**

Read `modules/bar/BarWindow.qml` in full (it's ~20 lines).

**Step 2: Change implicitHeight only**

Replace:
```qml
implicitHeight: Theme.barHeight
exclusiveZone: Theme.barHeight
```
With:
```qml
implicitHeight: Theme.barHeight + 30
exclusiveZone: Theme.barHeight
```

> The window surface is now 30px taller but other windows are not pushed down.

**Step 3: Verify with `qs --path .`**

Run the shell. The bar should look identical — the extra 30px is transparent and invisible. No visual regression.

**Step 4: Commit**

```
feat(bar): extend BarWindow surface by 30px for island expansion area
```

---

### Task 2: Lock BarContent sections to barHeight so verticalCenter stays correct

**Files:**
- Modify: `modules/bar/BarContent.qml`

**Step 1: Read BarContent.qml**

Note the three `BarSection` items and their `height: parent.height` property.

**Step 2: Change height on all three sections**

For `leftSection`, `centerSection`, and `rightSection`, change:
```qml
height: parent.height
```
To:
```qml
height: Theme.barHeight
```

> This confines widget layout to the visible bar strip. Without this fix, making BarWindow taller would shift all widgets 15px downward.

**Step 3: Verify with `qs --path .`**

Run the shell. All existing widgets (clock, notification bell, current workspace widget) must remain at the same vertical position as before these changes. The bar must look identical.

**Step 4: Commit**

```
fix(bar): constrain BarSection height to Theme.barHeight for correct vertical centering
```

---

### Task 3: Rewrite WorkspaceWidget — scaffolding and data layer

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml`

**Step 1: Read the current WorkspaceWidget.qml in full**

Understand the existing imports, root element, and properties.

**Step 2: Replace the file with the new scaffold**

The new root is an `Item` (not `Rectangle`, since the visual background is a child). Start with just the data layer — no visual yet:

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Enhanced workspace indicator.
// Shows per-workspace window app icons and expands downward (Dynamic Island style)
// to display the focused window title.
Item {
    id: root

    // --- layout ---
    implicitHeight: Theme.barHeight
    implicitWidth: _islandPadH * 2 + pillsRow.implicitWidth
    clip: false

    // --- private structure constants ---
    readonly property int _islandPadV:  4
    readonly property int _islandPadH:  10
    readonly property int _iconSize:    14
    readonly property int _pillGap:     5
    readonly property int _pillPadH:    8
    readonly property int _titleGap:    4
    readonly property int _titleRowH:   18
    readonly property int _collapsedH:  Theme.barHeight - 2 * _islandPadV
    readonly property int _expandedH:   _collapsedH + _titleGap + _titleRowH

    // --- focused window data (updated on every windowsUpdated signal) ---
    property string focusedWindowTitle: ""

    function _refreshFocusedWindow() {
        for (let i = 0; i < NiriService.windows.count; i++) {
            const w = NiriService.windows.get(i)
            if (w.isFocused) {
                root.focusedWindowTitle = w.title || w.appId || ""
                return
            }
        }
        root.focusedWindowTitle = ""
    }

    // --- icon resolution ---
    function _iconPath(appId) {
        if (!appId) return Quickshell.iconPath("application-x-executable")
        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable")
        return Quickshell.iconPath("application-x-executable")
    }

    Component.onCompleted: _refreshFocusedWindow()

    Connections {
        target: NiriService
        function onWindowsUpdated() { root._refreshFocusedWindow() }
    }
}
```

**Step 3: Verify the shell loads without errors**

Run `qs --path .`. The workspace widget should be invisible (no visual yet) but the shell must not crash. Check the terminal for QML errors.

---

### Task 4: Add the animated island background rectangle

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml`

**Step 1: Add `_expanded` computed property and island Rectangle inside root**

Inside the root `Item`, add after the `Connections` block:

```qml
    readonly property bool _expanded: focusedWindowTitle.length > 0

    Rectangle {
        id: islandBackground

        anchors.horizontalCenter: parent.horizontalCenter
        y: root._islandPadV
        width: pillsRow.implicitWidth + root._islandPadH * 2
        height: root._expanded ? root._expandedH : root._collapsedH
        radius: Theme.cornerRadius
        color: Colors.background

        Behavior on height {
            SequentialAnimation {
                NumberAnimation {
                    duration: root._expanded ? Theme.anim.enterDuration : Theme.anim.exitDuration
                    easing.type: root._expanded ? Theme.anim.enterType : Theme.anim.exitType
                    easing.amplitude: root._expanded ? Theme.anim.enterAmplitude : 1.0
                    easing.period:    root._expanded ? Theme.anim.enterPeriod   : 0.0
                }
            }
        }

        // Workspace pills row — takes the top _collapsedH portion
        Row {
            id: pillsRow
            x: root._islandPadH
            y: (root._collapsedH - implicitHeight) / 2
            spacing: root._pillGap
        }

        // Title text — sits below the pills row, fades in/out
        Text {
            id: titleText
            x: root._islandPadH
            y: root._collapsedH + root._titleGap
            width: islandBackground.width - root._islandPadH * 2
            text: root.focusedWindowTitle
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
            opacity: root._expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.highlightDuration
                    easing.type: Theme.anim.highlightType
                }
            }
        }
    }
```

**Step 2: Verify visually**

Run the shell. The island background should:
- Appear as a static rounded pill behind the (currently empty) pills row
- Expand downward and show the focused window title when any window is open
- Collapse back when focus is lost / desktop is shown

---

### Task 5: Add workspace pills with icons inside the Row

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml`

**Step 1: Add a Repeater inside `pillsRow`**

Replace `Row { id: pillsRow ... }` (the empty row from Task 4) with:

```qml
        Row {
            id: pillsRow
            x: root._islandPadH
            y: (root._collapsedH - implicitHeight) / 2
            spacing: root._pillGap

            Repeater {
                id: workspaceRepeater
                model: NiriService.workspaces

                delegate: Item {
                    id: wsDelegate

                    required property string wsId
                    required property int    idx
                    required property bool   isActive

                    // Per-workspace window appId list, refreshed on every windowsUpdated
                    property var _wsAppIds: []

                    // Hidden when empty and not focused
                    visible: isActive || _wsAppIds.length > 0
                    // Collapse layout space when hidden
                    width: visible ? _pill.implicitWidth : 0

                    function _refreshIcons() {
                        let arr = []
                        for (let i = 0; i < NiriService.windows.count; i++) {
                            const w = NiriService.windows.get(i)
                            if (w.workspaceId === wsDelegate.wsId) arr.push(w.appId)
                        }
                        wsDelegate._wsAppIds = arr
                    }

                    Component.onCompleted: _refreshIcons()

                    Connections {
                        target: NiriService
                        function onWindowsUpdated() { wsDelegate._refreshIcons() }
                    }

                    // Pill background
                    Rectangle {
                        id: _pill

                        implicitHeight: root._collapsedH
                        implicitWidth: Math.max(
                            _iconRow.implicitWidth + root._pillPadH * 2,
                            root._collapsedH  // minimum square-ish pill
                        )
                        radius: root._collapsedH / 2
                        color: wsDelegate.isActive ? Colors.highlight : Colors.backgroundAlt

                        Behavior on implicitWidth {
                            NumberAnimation {
                                duration: Theme.anim.moveDuration
                                easing.type: Theme.anim.moveType
                            }
                        }

                        // Icon row
                        Row {
                            id: _iconRow
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: wsDelegate._wsAppIds

                                delegate: Image {
                                    required property string modelData

                                    width:  root._iconSize
                                    height: root._iconSize
                                    source: root._iconPath(modelData)
                                    smooth: true
                                    visible: status !== Image.Error
                                    // Zero-size on load failure so row layout adapts
                                    width:  status === Image.Error ? 0 : root._iconSize
                                    height: status === Image.Error ? 0 : root._iconSize
                                }
                            }

                            // Workspace number shown when no icons (active empty workspace)
                            Text {
                                visible: wsDelegate._wsAppIds.length === 0
                                text: wsDelegate.idx
                                font.family: Theme.fontMono
                                font.bold: true
                                font.pixelSize: Theme.fontSizeBody
                                color: wsDelegate.isActive ? Colors.background : Colors.textMuted
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([
                                "niri", "msg", "action",
                                "focus-workspace", wsDelegate.idx.toString()
                            ])
                        }
                    }
                }
            }
        }
```

**Step 2: Run the shell and verify**

- Each occupied workspace should display icons for open apps
- Active workspace pill should have `Colors.highlight` background
- Active empty workspace should show its number
- Clicking a workspace pill should focus that workspace

---

### Task 6: Fix duplicate `width`/`height` properties and clean up

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml`

**Step 1: Fix Image delegate duplicate property**

The `Image` delegate in Task 5 has duplicate `width` and `height` declarations:
```qml
width:  root._iconSize   // first declaration
height: root._iconSize
// ...
width:  status === Image.Error ? 0 : root._iconSize  // duplicate — overrides first
height: status === Image.Error ? 0 : root._iconSize
```

Remove the first pair; keep only the conditional pair:
```qml
width:  status === Image.Error ? 0 : root._iconSize
height: status === Image.Error ? 0 : root._iconSize
```

**Step 2: Verify QML has no parse errors**

Run the shell. Check terminal for errors. The workspace widget must display correctly.

**Step 3: Commit all changes so far**

```
feat(widgets): WorkspaceWidget v2 — Dynamic Island with per-workspace app icons and focused title
```

---

### Task 7: Integration smoke-test checklist

Manual verification steps (run `qs --path .` for each):

1. **Empty workspace** — switch to an empty workspace → it disappears from bar widget; the active pill still shows its number if it's the last one visible.
2. **Open an app** → icon appears in the corresponding workspace pill.
3. **Focus a window** → island expands downward, title appears with fade-in, title text is truncated correctly on long names.
4. **Switch workspace** → island contracts, then expands again with new focused window title.
5. **Close last window in workspace** → workspace pill disappears (if not active).
6. **Other widgets** (clock, notification bell) → must not shift vertically.
7. **No QML errors** in terminal.

---

### Task 8: Register the widget name in BarContent (no change needed, verify)

**Files:**
- Read: `modules/bar/BarContent.qml`

Confirm that `workspaceWidget` is still the registry key and still points to `widgets/WorkspaceWidget.qml`. No file change expected — this is a verification-only step.

---

### Task 9: Final commit and cleanup

**Step 1:** Review all changed files for leftover debug `console.log()` calls.

**Step 2:** Ensure no inline `// FIXME:` markers exist without description.

**Step 3:** Commit:
```
chore(bar): remove any leftover debug logging from workspace island implementation
```
