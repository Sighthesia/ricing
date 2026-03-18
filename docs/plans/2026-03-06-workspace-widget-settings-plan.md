# Workspace Widget Settings — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expose four WorkspaceWidget parameters as user-configurable settings accessible from the Widget Settings Panel.

**Architecture:** Add `"workspaceWidget"` section to `settings-default.json`; bind four hardcoded constants in `WorkspaceWidget.qml` to `SettingsService.data.workspaceWidget.*`; create `WorkspaceWidgetSection.qml` for the settings UI; wire it into `WidgetSettingsPanel.qml` via a `Loader`.

**Tech Stack:** QML/Quickshell. Uses existing `SettingsService` singleton, `SliderSection`, `BehaviorSection` UI patterns from `settings/` directory.

**Design doc:** `docs/plans/2026-03-06-workspace-widget-settings-design.md`

---

### Task 1: Add `workspaceWidget` section to settings-default.json

**Files:**
- Modify: `config/settings-default.json`

**Step 1: Read the file**

Read the file. Note the last section before the final `}`.

**Step 2: Insert the new section**

Add a `"workspaceWidget"` section after the `"notifications"` section (before the closing `}`):

```json
    "workspaceWidget": {
        "defaultMode": "focus",
        "titleMaxWidth": 240,
        "revertDelay": 1500,
        "hoverEnabled": true
    }
```

**Step 3: Verify JSON is valid**

Run `python3 -m json.tool config/settings-default.json > /dev/null && echo OK`.

**Step 4: Commit**

```
feat(settings): add workspaceWidget settings section with 4 keys
```

---

### Task 2: Bind WorkspaceWidget constants to SettingsService

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml`

**Step 1: Read the current file**

Read `modules/bar/widgets/WorkspaceWidget.qml`. Locate:
- `readonly property int _revertDelay: 1500`
- `readonly property int _revertCooldown: 50`
- `readonly property int _titleMaxW: 240`
- `readonly property bool _showOverview: ...` (multi-line)
- `_hoverArea onEntered` handler

**Step 2: Replace `_revertDelay` and `_titleMaxW` with SettingsService bindings**

Change:
```qml
    readonly property int _revertDelay:     1500  // ms — overview flash duration (workspace switch / hover)
```
To:
```qml
    readonly property int _revertDelay:  SettingsService.data.workspaceWidget.revertDelay
```

Change:
```qml
    readonly property int _titleMaxW:    240  // max title render width (ElideRight after this)
```
To:
```qml
    readonly property int _titleMaxW:    SettingsService.data.workspaceWidget.titleMaxWidth
```

**Step 3: Add `_hoverActive` readonly property**

After `_titleMaxW`, add:
```qml
    readonly property bool _hoverActive: SettingsService.data.workspaceWidget.hoverEnabled
```

**Step 4: Update `_showOverview` to respect `defaultMode`**

Replace the current `_showOverview` binding:
```qml
    // _showOverview: render-driving boolean (step 6 — derived readonly before mutable state).
    // Show overview when explicitly overridden, or when no window is focused and
    // the user hasn't hovered us into forced focus.
    readonly property bool _showOverview:
        _modeOverride === "overview" ||
        (_modeOverride !== "focus" && _focusedTitle.length === 0)
```
With:
```qml
    // _showOverview: render-driving boolean (step 6 — derived readonly before mutable state).
    // Explicit _modeOverride takes priority; natural state uses defaultMode setting.
    readonly property bool _showOverview: {
        if (_modeOverride === "overview") return true
        if (_modeOverride === "focus")    return false
        // Natural (unforced) state: use defaultMode setting
        if (SettingsService.data.workspaceWidget.defaultMode === "overview") return true
        return _focusedTitle.length === 0
    }
```

**Step 5: Gate hover on `_hoverActive`**

Find the `_hoverArea` MouseArea `onEntered` handler:
```qml
        onEntered: {
            if (root._justReverted) return  // ignore brief re-entry after auto-revert
            _revertTimer.stop()
            root._modeOverride = "overview"
        }
```
Replace with:
```qml
        onEntered: {
            if (!root._hoverActive || root._justReverted) return
            _revertTimer.stop()
            root._modeOverride = "overview"
        }
```

**Step 6: Verify with `qs --path .`**

Shell must load without errors. The widget behavior is unchanged from defaults (all settings match the previous hardcoded values).

**Step 7: Commit**

```
feat(widgets): bind WorkspaceWidget constants to SettingsService.data.workspaceWidget
```

---

### Task 3: Create WorkspaceWidgetSection.qml

**Files:**
- Create: `modules/bar/widgetsettings/WorkspaceWidgetSection.qml`

**Step 1: Read reference files for patterns**

Read `modules/bar/settings/SliderSection.qml` lines 1-30 to understand the `onValueCommitted` signal pattern.
Read `modules/bar/settings/BehaviorSection.qml` lines 35-90 to understand the segmented-button pattern.

**Step 2: Create the file**

```qml
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Functional settings for the WorkspaceWidget (two-state island indicator).
// Shown in WidgetSettingsPanel when the active widget is "workspaceWidget".
Item {
    id: root

    implicitWidth: 296
    implicitHeight: _col.implicitHeight

    Column {
        id: _col
        width: parent.width
        spacing: 0

        // ── Default mode ─────────────────────────────────────────────────
        Item {
            width: parent.width
            height: Theme.settingsRowHeight

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.settingsPanelPadding
                anchors.rightMargin: Theme.settingsPanelPadding
                spacing: 8

                Text {
                    width: Theme.settingsLabelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "默认形态"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: [
                            { value: "focus",    label: "聚焦" },
                            { value: "overview", label: "概览" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool _selected:
                                SettingsService.data.workspaceWidget.defaultMode === modelData.value

                            width: 52; height: 24
                            radius: Theme.cornerRadius - 4
                            color: _selected ? Colors.highlight : Colors.surface
                            opacity: _selected ? 0.9 : 0.6

                            Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                            Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: parent._selected ? Colors.background : Colors.text
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    SettingsService.data.workspaceWidget.defaultMode = parent.modelData.value
                                    SettingsService.save()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Hover toggle ──────────────────────────────────────────────────
        Item {
            width: parent.width
            height: Theme.settingsRowHeight

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.settingsPanelPadding
                anchors.rightMargin: Theme.settingsPanelPadding
                spacing: 8

                Text {
                    width: Theme.settingsLabelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "悬浮切换"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                Rectangle {
                    id: _toggleTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 20; radius: 10
                    color: SettingsService.data.workspaceWidget.hoverEnabled
                        ? Colors.highlight : Colors.surface
                    Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                    Rectangle {
                        id: _toggleKnob
                        anchors.verticalCenter: parent.verticalCenter
                        x: SettingsService.data.workspaceWidget.hoverEnabled ? parent.width - width - 2 : 2
                        width: 16; height: 16; radius: 8
                        color: Colors.text

                        Behavior on x { NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SettingsService.data.workspaceWidget.hoverEnabled =
                                !SettingsService.data.workspaceWidget.hoverEnabled
                            SettingsService.save()
                        }
                    }
                }
            }
        }

        // ── Title max width ───────────────────────────────────────────────
        SliderSection {
            width: parent.width
            label: "标题宽度"
            value: SettingsService.data.workspaceWidget.titleMaxWidth
            from: 60; to: 400; stepSize: 10; unit: "px"
            onValueCommitted: newValue => {
                SettingsService.data.workspaceWidget.titleMaxWidth = newValue
                SettingsService.save()
            }
        }

        // ── Revert delay ─────────────────────────────────────────────────
        SliderSection {
            width: parent.width
            label: "切换延迟"
            value: SettingsService.data.workspaceWidget.revertDelay
            from: 300; to: 5000; stepSize: 100; unit: "ms"
            onValueCommitted: newValue => {
                SettingsService.data.workspaceWidget.revertDelay = newValue
                SettingsService.save()
            }
        }
    }
}
```

**Step 3: Verify file syntax is correct**

Re-read the file to confirm no typos.

**Step 4: Commit**

```
feat(widget-settings): add WorkspaceWidgetSection with defaultMode, hover, titleMaxWidth, revertDelay
```

---

### Task 4: Wire WorkspaceWidgetSection into WidgetSettingsPanel

**Files:**
- Modify: `modules/bar/WidgetSettingsPanel.qml`

**Step 1: Read the _groupFunctional section**

Find the `ExpandableGroup` with `title: "功能"`. It currently contains a single placeholder `Text`.

**Step 2: Replace placeholder with conditional Loader**

Replace the content inside `ExpandableGroup { id: _groupFunctional ... }`:

Current:
```qml
                Text {
                    width: parent.width
                    text: "暂无可用设置"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                    color: Colors.textMuted; opacity: 0.5
                    horizontalAlignment: Text.AlignHCenter
                    height: Theme.settingsRowHeight
                    verticalAlignment: Text.AlignVCenter
                }
```

Replace with:
```qml
                Loader {
                    width: parent.width
                    active: root._widgetId === "workspaceWidget"
                    sourceComponent: WorkspaceWidgetSection { width: parent.width }
                }

                Text {
                    width: parent.width
                    visible: root._widgetId !== "workspaceWidget"
                    height: visible ? Theme.settingsRowHeight : 0
                    text: "暂无可用设置"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                    color: Colors.textMuted; opacity: 0.5
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
```

**Step 3: Verify with `qs --path .`**

Open the Widget Settings Panel for the workspace widget (right-click or long press). The "功能" section should show all four controls. For other widgets, the placeholder text should still appear.

**Step 4: Commit**

```
feat(bar): show WorkspaceWidgetSection in WidgetSettingsPanel functional group
```

---

### Task 5: Smoke-test checklist

Run `qs --path .` and verify:

1. **Shell starts** — no QML errors.
2. **Open Widget Settings for workspaceWidget** — "功能" group shows slider for 标题宽度, 切换延迟, toggle for 悬浮切换, segmented buttons for 默认形态.
3. **Change defaultMode to "overview"** — widget immediately switches to overview mode when in natural state (no window forced) even with a window focused.
4. **Change defaultMode back to "focus"** — widget returns to focus mode default.
5. **Disable 悬浮切换** — hovering the widget no longer toggles modes.
6. **Adjust 标题宽度** — title truncation point changes live.
7. **Adjust 切换延迟** — overview flash lasts longer/shorter after workspace switch.
8. **Settings persist** — close and reopen shell, settings are preserved.
9. **Other widgets** (clock) — "功能" group still shows "暂无可用设置".
