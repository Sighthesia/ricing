# Workspace Island Widget — Implementation Plan (v2 — Two-State Morph)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the "expand downward" workspace island with a two-state morphing pill: Focus Mode (icon + title, default) ↔ Overview Mode (per-workspace icon pills).

**Architecture:** Three file changes only. Revert `BarWindow.qml` to standard height. Add one signal to `NiriService.qml`. Rewrite `WorkspaceWidget.qml` with a single pill background whose width animates between the two content layers (opacity crossfade). No new imports, singletons, or services.

**Tech Stack:** QML/Quickshell, `NiriService` (already present), `DesktopEntries.heuristicLookup()`, `Quickshell.iconPath()`.

---

### Task 1: Revert BarWindow.qml — remove the +30px surface extension

The previous v1 implementation expanded `BarWindow.implicitHeight` to create overflow space for the title row. The new design stays within `Theme.barHeight`, so this must be reverted.

**Files:**
- Modify: `modules/bar/BarWindow.qml`

**Step 1: Read the file**

Read `modules/bar/BarWindow.qml`. Confirm it currently has:
```qml
implicitHeight: Theme.barHeight + 30
```

**Step 2: Revert to standard height**

Replace:
```qml
    // Extra 30px extends the surface below the bar for the workspace island expansion.
    // exclusiveZone stays at barHeight so other windows are not shifted down.
    // FIXME: hardcoded size — should derive from WorkspaceWidget's (_titleGap + _titleRowH + _padV).
    // Promote to a Theme.* token so the island and window surface stay in sync.
    implicitHeight: Theme.barHeight + 30
    exclusiveZone: Theme.barHeight
```
With:
```qml
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
```

**Step 3: Verify with `qs --path .`**

The bar must look identical to before and have no overflow area.

**Step 4: Commit**

```
revert(bar): remove BarWindow +30px surface extension — not needed in v2 island design
```

---

### Task 2: Add `workspaceActivated` signal to NiriService

The widget needs to know when the active workspace changes in order to trigger a brief overview flash. `NiriService.windowsUpdated` does not fire for workspace-only activations (no window changes), so a dedicated signal is required.

**Files:**
- Modify: `services/NiriService.qml`

**Step 1: Read NiriService.qml lines 1–15**

Confirm the existing signals: `signal windowsUpdated()` at line ~13. There is no `workspaceActivated` signal yet.

**Step 2: Add the signal declaration**

After `signal windowsUpdated()`, add:
```qml
    signal workspaceActivated()
```

**Step 3: Emit the signal in `activateWorkspace()`**

The `activateWorkspace` function ends with the for-loop. Add one line after the loop:
```qml
    function activateWorkspace(event) {
        const activeId = String(event.id);
        for (let i = 0; i < workspaces.count; i++) {
            const item = workspaces.get(i);
            const isNowActive = (item.wsId === activeId);
            if (item.isActive !== isNowActive) {
                workspaces.setProperty(i, "isActive", isNowActive);
            }
        }
        workspaceActivated();   // ← add this line
    }
```

**Step 4: Verify with `qs --path .`**

Shell must load without errors. The new signal is wired up; it won't be consumed by anything yet.

**Step 5: Commit**

```
feat(services): emit NiriService.workspaceActivated() on every workspace switch
```

---

### Task 3: Rewrite WorkspaceWidget — data layer and state machine

Start from a clean slate. Replace the entire file with just the data/logic layer — no visuals yet. This lets you verify the logic loads cleanly before adding layout.

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml`

**Step 1: Read the current file in full**

Understand all current imports and properties so nothing is missed.

**Step 2: Replace the file content**

```qml
import QtQuick
import Quickshell
import qs.config
import qs.services

// Two-state workspace indicator ("Dynamic Island" morph style).
//
// Focus Mode (default): single pill — focused app icon + window title.
// Overview Mode: per-workspace pills showing open window app icons.
//
// Mode transitions:
//   - Focus is active whenever a window is focused.
//   - Overview activates when the desktop has no focused window.
//   - Hover flips to the opposite mode temporarily.
//   - Workspace switch triggers a 1.5 s overview flash, then returns to Focus.
Item {
    id: root

    // --- layout ---
    implicitHeight: Theme.barHeight
    // implicitWidth is set after the visual layer is added (Task 5)
    implicitWidth: 60  // placeholder; replaced in Task 5

    // --- structure constants ---
    readonly property int _padV:         4    // vertical gap (pill ↔ bar top/bottom)
    readonly property int _padH:         10   // horizontal padding inside the pill
    readonly property int _iconSize:     16   // app icon in focus mode
    readonly property int _smallIcon:    13   // app icon inside workspace pills
    readonly property int _iconSpacing:  2    // gap between icons in a workspace pill
    readonly property int _pillGap:      6    // gap between workspace pills
    readonly property int _pillPadH:     8    // horizontal padding inside each workspace pill
    readonly property int _iconTitleGap: 6    // gap between focus icon and title text
    readonly property int _titleMaxW:    240  // max title render width (ElideRight after this)
    readonly property int _pillH:        Theme.barHeight - 2 * _padV

    // --- state machine ---
    // _mode is the base/preferred mode.
    // Hover XOR-flips to the other mode while the mouse is over the widget.
    // workspaceActivated fires _flashTimer to force overview for 1.5 s.
    property string _mode: "focus"    // "focus" | "overview"
    property bool   _hovered: false

    // _showOverview: the fully resolved, render-driving boolean.
    // Truth table:
    //   no focused window → always overview
    //   focused + _mode="focus"    + not hovered → false (focus)
    //   focused + _mode="focus"    + hovered     → true  (overview via hover flip)
    //   focused + _mode="overview" + not hovered → true  (overview)
    //   focused + _mode="overview" + hovered     → false (focus via hover flip)
    readonly property bool _showOverview: {
        if (_focusedTitle.length === 0) return true
        return (_mode === "overview") !== _hovered   // XOR
    }

    // --- focused window data ---
    property string _focusedAppId: ""
    property string _focusedTitle:  ""

    function _refreshFocus() {
        for (let i = 0; i < NiriService.windows.count; i++) {
            const w = NiriService.windows.get(i)
            if (w.isFocused) {
                root._focusedAppId = w.appId
                root._focusedTitle = (w.title === "Unknown") ? w.appId : w.title
                return
            }
        }
        root._focusedAppId = ""
        root._focusedTitle = ""
    }

    // --- icon resolution ---
    function _iconPath(appId) {
        if (!appId) return Quickshell.iconPath("application-x-executable")
        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable")
        return Quickshell.iconPath("application-x-executable")
    }

    // --- flash timer: workspace switch → show overview for 1.5 s then return ---
    Timer {
        id: _flashTimer
        interval: 1500
        repeat: false
        onTriggered: root._mode = "focus"
    }

    Component.onCompleted: _refreshFocus()

    Connections {
        target: NiriService
        function onWindowsUpdated()      { root._refreshFocus() }
        function onWorkspaceActivated()  {
            // Temporarily show overview so the user sees the new workspace.
            root._mode = "overview"
            _flashTimer.restart()
        }
    }
}
```

**Step 3: Verify with `qs --path .`**

Shell must load without errors. The workspace widget will be invisible (placeholder width) — that is expected. Check terminal for any QML parse errors.

**Step 4: Commit**

```
feat(widgets): WorkspaceWidget v2 — data layer and state machine
```

---

### Task 4: Add the pill background and overview content

Now add the visual layer. Start with the single pill rectangle and the overview content inside it. The focus layer (icon + title) is added in Task 5.

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml`

**Step 1: Add MouseArea + pill + overview Row inside root, after the Connections block**

Add BEFORE the closing `}` of the root `Item`:

```qml
    // Hover detection drives the _hovered XOR flip.
    MouseArea {
        id: _hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root._hovered = true
        onExited:  root._hovered = false
    }

    // ─── Visual pill ──────────────────────────────────────────────────────
    // Single rounded rectangle; width animates between overview and focus sizes.
    Rectangle {
        id: _pill

        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        height: root._pillH
        // Width is driven by _showOverview; animated by Behavior below.
        // Both content items report their implicitWidth; pill tracks the active one.
        implicitWidth: root._showOverview
            ? (_overviewRow.implicitWidth + root._padH * 2)
            : (_focusRow.implicitWidth   + root._padH * 2)

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        radius: height / 2
        color: Colors.surface

        // ── Overview content — workspace pills row ───────────────────────
        Row {
            id: _overviewRow
            anchors.centerIn: parent
            spacing: root._pillGap
            opacity: root._showOverview ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.highlightDuration
                    easing.type: Theme.anim.highlightType
                }
            }

            Repeater {
                model: NiriService.workspaces

                delegate: Item {
                    id: _wsDelegate

                    required property string wsId
                    required property int    idx
                    required property bool   isActive

                    // Per-workspace app icon list (one entry per open window).
                    property var _appIds: []

                    function _refreshIcons() {
                        let arr = []
                        for (let i = 0; i < NiriService.windows.count; i++) {
                            const w = NiriService.windows.get(i)
                            if (w.workspaceId === _wsDelegate.wsId) arr.push(w.appId)
                        }
                        _wsDelegate._appIds = arr
                    }

                    Component.onCompleted: _refreshIcons()

                    Connections {
                        target: NiriService
                        function onWindowsUpdated() { _wsDelegate._refreshIcons() }
                    }

                    // Hide empty non-active workspaces; collapse layout space.
                    visible: isActive || _appIds.length > 0
                    width:  visible ? _wsPill.implicitWidth  : 0
                    height: visible ? _wsPill.implicitHeight : 0

                    // Inner workspace pill
                    Rectangle {
                        id: _wsPill

                        implicitHeight: root._pillH
                        implicitWidth: Math.max(
                            _iconsRow.implicitWidth + root._pillPadH * 2,
                            root._pillH   // square-ish minimum
                        )
                        radius: implicitHeight / 2
                        color: _wsDelegate.isActive ? Colors.highlight : Colors.backgroundAlt

                        Behavior on implicitWidth {
                            NumberAnimation {
                                duration: Theme.anim.moveDuration
                                easing.type: Theme.anim.moveType
                            }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Theme.anim.highlightDuration }
                        }

                        // App icons (or workspace number when empty)
                        Row {
                            id: _iconsRow
                            anchors.centerIn: parent
                            spacing: root._iconSpacing

                            Repeater {
                                model: _wsDelegate._appIds

                                delegate: Image {
                                    required property string modelData

                                    readonly property bool _ok: status === Image.Ready
                                    width:  _ok ? root._smallIcon : 0
                                    height: _ok ? root._smallIcon : 0
                                    source: root._iconPath(modelData)
                                    smooth: true
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            Text {
                                visible: _wsDelegate._appIds.length === 0
                                text: _wsDelegate.idx
                                font.family: Theme.fontMono
                                font.bold: true
                                font.pixelSize: Theme.fontSizeBody
                                color: _wsDelegate.isActive ? Colors.background : Colors.textMuted

                                Behavior on color {
                                    ColorAnimation { duration: Theme.anim.highlightDuration }
                                }
                            }
                        }

                        // Hover highlight overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Colors.highlight
                            opacity: _wsArea.containsMouse ? 0.15 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.anim.highlightDuration
                                    easing.type: Theme.anim.highlightType
                                }
                            }
                        }

                        MouseArea {
                            id: _wsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([
                                "niri", "msg", "action",
                                "focus-workspace", _wsDelegate.idx.toString()
                            ])
                        }
                    }
                }
            }
        }

        // Focus content placeholder — added in Task 5
        // (Row id: _focusRow must exist for the implicitWidth binding above)
        Row {
            id: _focusRow
            anchors.centerIn: parent
            opacity: 0   // hidden until Task 5 fills it in
        }
    }
```

**Step 2: Update root.implicitWidth to track the pill**

Change the placeholder:
```qml
    implicitWidth: 60  // placeholder; replaced in Task 5
```
To:
```qml
    implicitWidth: _pill.implicitWidth
```

**Step 3: Verify with `qs --path .`**

The widget should now be visible in the bar as a small pill. Overview pills for all occupied workspaces should appear. Hover should flip between states (focus pill is empty/narrow for now). Check for QML errors.

**Step 4: Commit**

```
feat(widgets): WorkspaceWidget v2 — pill background and overview layer
```

---

### Task 5: Add focus content (icon + title row)

Fill in `_focusRow` with the real focused window icon and title.

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml`

**Step 1: Replace `_focusRow` placeholder**

Find and replace the placeholder Row with:
```qml
        // ── Focus content — app icon + window title ──────────────────────
        Row {
            id: _focusRow
            anchors.centerIn: parent
            spacing: root._iconTitleGap
            opacity: root._showOverview ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.highlightDuration
                    easing.type: Theme.anim.highlightType
                }
            }

            Image {
                id: _focusIcon
                width:  root._iconSize
                height: root._iconSize
                anchors.verticalCenter: parent.verticalCenter
                source: root._iconPath(root._focusedAppId)
                smooth: true
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: _titleText
                anchors.verticalCenter: parent.verticalCenter
                // Natural width capped at _titleMaxW; ElideRight truncates beyond that.
                width: Math.min(implicitWidth, root._titleMaxW)
                text: root._focusedTitle
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                color: Colors.text
            }
        }
```

**Step 2: Verify with `qs --path .`**

- With a focused window: pill should show the app icon + title. Width should animate when changing windows or when title length changes.
- With no focused window: widget should be in overview mode showing workspace pills.
- Hovering over the widget should temporarily flip to the other mode.
- After switching workspaces: overview flashes for ~1.5 s, then returns to focus mode.
- Long window titles: text should truncate with `…` cleanly.

**Step 3: Commit**

```
feat(widgets): WorkspaceWidget v2 — focus layer with icon and animated title pill
```

---

### Task 6: Smoke-test checklist

Run `qs --path .` and manually verify each scenario:

1. **Focused window exists** → pill shows app icon + title in Focus Mode by default.
2. **Very long title** → text truncates with `…`; pill width caps at `_titleMaxW + icon + padding`.
3. **Title changes** (e.g. browser tab switch) → pill width animates smoothly.
4. **No focused window / desktop** → widget shows workspace overview pills.
5. **Hover while in Focus Mode** → temporarily shows workspace pills; restores on mouse-out.
6. **Hover while in Overview Mode** → temporarily shows focus pill; restores on mouse-out.
7. **Workspace switch** → overview flashes for ~1.5 s, then returns to Focus Mode.
8. **New window opened** → its icon appears in the correct workspace pill (overview mode).
9. **Window closed** → icon disappears; if workspace becomes empty and non-active, pill hides.
10. **Other bar widgets** (clock, notification bell, etc.) → no visual regression, no vertical shift.
11. **No QML errors** in terminal.

---

### Task 7: Final cleanup

**Step 1:** Grep for any leftover `console.log` calls in modified files.

**Step 2:** Confirm no `// FIXME:` without a description.

**Step 3:** Commit if any cleanup was needed:
```
chore(widgets): clean up debug logging in WorkspaceWidget v2
```

