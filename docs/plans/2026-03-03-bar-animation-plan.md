# Bar Animation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Provide smooth layout animations when dragging bar components, making space occupation and replacement visually continuous.

**Architecture:** Utilize QML's `Behavior` and `Transition` within the existing `Row` + `Repeater` structure.

**Tech Stack:** QtQuick 6.x / Quickshell

---

### Task 1: Add implicitWidth Animation to BarWidgetWrapper

**Files:**
- Modify: `modules/bar/BarWidgetWrapper.qml:11-15`

**Step 1: Add Behavior to implicitWidth and opacity**

```qml
    implicitWidth: _isDragging ? 0 : _naturalWidth
    implicitHeight: _isDragging ? 0 : _naturalHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }
```

**Step 2: Update opacity logic to fade out when dragging**

Modify the `opacity` property to use a Behavior as well when `_isDragging` changes.

**Step 3: Commit**

```bash
git add modules/bar/BarWidgetWrapper.qml
git commit -m "feat(bar): add width animation to widget wrapper during drag"
```

---

### Task 2: Enable Layout Transitions in BarSection

**Files:**
- Modify: `modules/bar/BarSection.qml:55-58`

**Step 1: Add move and add transitions to the Row**

```qml
    Row {
        id: widgetRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.widgetSpacing

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }
        add: Transition {
            NumberAnimation {
                properties: "opacity,x,y"
                from: 0
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }
        
        Repeater {
            model: section.widgets
            delegate: widgetDelegate
        }
    }
```

**Step 2: Commit**

```bash
git add modules/bar/BarSection.qml
git commit -m "feat(bar): enable layout transitions for smooth positioning"
```

---

### Task 3: Smooth Insertion Indicator (Ghost Line)

**Files:**
- Modify: `modules/bar/BarSection.qml:80-90`

**Step 1: Add Behavior to insertion indicator's X coordinate**

```qml
    // Insertion indicator line
    Rectangle {
        id: insertIndicator
        // ... existing visibility ...
        Behavior on x {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }
    }
```

**Step 2: Commit**

```bash
git add modules/bar/BarSection.qml
git commit -m "feat(bar): add smooth movement to insertion indicator"
```

---

### Task 4: Verification

**Step 1: Manual Test**
1. Enter Settings Mode.
2. Drag a widget. 
3. Verify that the original spot shrinks smoothly (Width Animation).
4. Verify that other widgets slide to fill the gap (Row Transition).
5. Verify that moving the ghost line across widgets is smooth (X Behavior).
6. Verify dropping at a new location expands the space smoothly.
