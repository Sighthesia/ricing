# Panel Open/Close Animation — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add noctalia-style drop-down expand animation to SettingsPanelWindow and WidgetPickerWindow using a shared AnimatedPanelBase component.

**Architecture:** Create `AnimatedPanelBase.qml` inheriting `PanelWindow` with an internal state machine ("closed"/"opening"/"open"/"closing"). Both panels replace their root element and swap `visible:` for `active:`. Transform scale animates from the bar edge downward; opacity fades in with a slight delay.

**Tech Stack:** QML, Quickshell PanelWindow, QtQuick PropertyAnimation, Scale transform

---

### Task 1: Create AnimatedPanelBase.qml

**Files:**
- Create: `modules/bar/AnimatedPanelBase.qml`

**Step 1: Create the file**

```qml
import Quickshell
import QtQuick
import qs.config

// Animated drop-down base for PanelWindows.
// Replace `visible:` with `active:` in child panels and use this as root.
// Window stays alive during close animation; children route into the scaled wrapper.
PanelWindow {
    id: root

    default property alias data: _wrapper.data

    // Logical open/close trigger — replaces `visible:` in child panels
    property bool active: false

    color: "transparent"

    // Keep surface alive while closing to let animation finish
    visible: _state !== "closed"

    // Internal state machine: "closed" | "opening" | "open" | "closing"
    property string _state: "closed"

    onActiveChanged: {
        if (active) {
            if (_state === "closed" || _state === "closing") {
                _scaleOpenAnim.stop()
                _scaleCloseAnim.stop()
                _opacityCloseAnim.stop()
                _state = "opening"
                _wrapper._scaleY = 1.0
                _opacityDelayTimer.restart()
            }
        } else {
            if (_state === "open" || _state === "opening") {
                _scaleOpenAnim.stop()
                _opacityOpenAnim.stop()
                _opacityDelayTimer.stop()
                _state = "closing"
                _wrapper.opacity = 0.0
                _wrapper._scaleY = 0.0
            }
        }
    }

    // Delay opacity fade-in slightly so the scale animation starts first
    Timer {
        id: _opacityDelayTimer
        interval: 60
        repeat: false
        onTriggered: _wrapper.opacity = 1.0
    }

    // --- Animations (explicit PropertyAnimation to allow different easing per direction) ---

    PropertyAnimation {
        id: _scaleOpenAnim
        target: _wrapper
        property: "_scaleY"
        to: 1.0
        duration: 280
        easing.type: Easing.OutBack
        easing.overshoot: 0.7
        onFinished: if (root._state === "opening") root._state = "open"
    }

    PropertyAnimation {
        id: _scaleCloseAnim
        target: _wrapper
        property: "_scaleY"
        to: 0.0
        duration: 200
        easing.type: Easing.InBack
        easing.overshoot: 0.7
        onFinished: if (root._state === "closing") root._state = "closed"
    }

    PropertyAnimation {
        id: _opacityOpenAnim
        target: _wrapper
        property: "opacity"
        to: 1.0
        duration: 180
        easing.type: Easing.OutQuad
    }

    PropertyAnimation {
        id: _opacityCloseAnim
        target: _wrapper
        property: "opacity"
        to: 0.0
        duration: 120
        easing.type: Easing.InQuad
    }

    // --- Animated wrapper (scale grows downward from bar edge at origin y=0) ---
    Item {
        id: _wrapper
        anchors.fill: parent

        opacity: 0.0
        property real _scaleY: 0.0

        transform: Scale {
            origin.x: 0
            origin.y: 0
            xScale: 1.0
            yScale: _wrapper._scaleY
        }

        // Drive animations when target properties change
        onOpacityChanged: {
            if (opacity === 1.0 && root._state === "opening") {
                _opacityCloseAnim.stop()
                _opacityOpenAnim.restart()
            } else if (opacity === 0.0 && root._state === "closing") {
                _opacityOpenAnim.stop()
                _opacityCloseAnim.restart()
            }
        }

        on_ScaleYChanged: {
            if (_scaleY === 1.0 && root._state === "opening") {
                _scaleCloseAnim.stop()
                _scaleOpenAnim.restart()
            } else if (_scaleY === 0.0 && root._state === "closing") {
                _scaleOpenAnim.stop()
                _scaleCloseAnim.restart()
            }
        }
    }
}
```

**Step 2: Verify syntax** — open in editor, check no red underlines.

---

### Task 2: Update SettingsPanelWindow.qml

**Files:**
- Modify: `modules/bar/SettingsPanelWindow.qml`

**Step 1: Replace root element and visibility**

Change:
```qml
PanelWindow {
    ...
    visible: BarLayoutService.activePanel === "config"
```

To:
```qml
AnimatedPanelBase {
    ...
    active: BarLayoutService.activePanel === "config"
```

**Step 2:** Remove or comment old `visible:` line if it remained.

---

### Task 3: Update WidgetPickerWindow.qml

**Files:**
- Modify: `modules/bar/WidgetPickerWindow.qml`

**Step 1: Replace root element and visibility**

Change:
```qml
PanelWindow {
    ...
    visible: BarLayoutService.widgetPickerOpen && BarLayoutService.settingsMode
    onVisibleChanged: if (!visible) BarLayoutService.widgetPickerOpen = false
```

To:
```qml
AnimatedPanelBase {
    ...
    active: BarLayoutService.widgetPickerOpen && BarLayoutService.settingsMode
    onActiveChanged: if (!active) BarLayoutService.widgetPickerOpen = false
```

---

### Task 4: Smoke Test

1. Launch shell: `quickshell`
2. Open settings panel — verify downward grow + fade-in animation
3. Close settings panel — verify fade-out + shrink-up animation
4. Open widget picker (enter layout mode → right-click) — verify same animation
5. Rapidly toggle open/close — verify no stuck state or invisible window

---

### Task 5: Commit

```
git add modules/bar/AnimatedPanelBase.qml modules/bar/SettingsPanelWindow.qml modules/bar/WidgetPickerWindow.qml
git commit -m "feat(bar): add noctalia-style drop-down animation to panels

Introduce AnimatedPanelBase (inherits PanelWindow) with a four-state
machine (closed/opening/open/closing). Scale transform from origin y=0
grows panels downward from the bar; opacity fades in after a 60ms delay.
OutBack/InBack easing for the scale; OutQuad/InQuad for opacity.

Keeps Wayland surface alive during close animation to allow full
animation sequence before destroying the surface."
```
