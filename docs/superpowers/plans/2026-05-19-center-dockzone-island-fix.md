# Center Dockzone Island Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore center dockzone hover expand/reset motion and center-zone widget editing while keeping `IslandWindow/IslandBody` as the visual owner.

**Architecture:** Keep the current center ownership split intact: `modules/island/IslandBody.qml` remains the only visible center surface, and the hidden bar-side `centerSection` stays non-visual. Implement the missing behavior by reproducing the dockzone hover geometry pattern inside `IslandBody` and reconnecting right-click editing to `Services.BarLayoutService` so the center area can open the existing context menu and widget picker.

**Tech Stack:** QML, Quickshell, existing singleton services in `services/`, existing bar context menu and widget picker windows.

---

### Task 1: Add Center Hover Motion To IslandBody

**Files:**
- Modify: `modules/island/IslandBody.qml`
- Reference: `modules/bar/DockzoneSurfaceModel.js`
- Reference: `services/Motion.qml`

- [ ] **Step 1: Write the failing behavioral check**

Observe the current shell behavior and record the failing expectation:

1. Launch the shell in the usual local way.
2. Move the pointer into the collapsed center island.
3. Confirm the current failure: the center island does not widen/lift/radius-morph on hover the way left/right dockzones do.
4. Move the pointer out.
5. Confirm the current failure: there is no spring-like reset animation back to the resting shape.

- [ ] **Step 2: Verify the current implementation has no hover driver**

Read `modules/island/IslandBody.qml` and confirm these current facts before editing:

```qml
property int targetW: Services.IslandService.expanded ? expandedW : collapsedW
property int targetH: Services.IslandService.expanded ? expandedH : collapsedH
property int targetR: Services.IslandService.expanded ? 24 : 14

Behavior on width {
    SpringAnimation { spring: 5.0; mass: 3.6; damping: 0.75; epsilon: 0.5 }
}
```

Expected: width/height/radius react only to `Services.IslandService.expanded`, not to hover intent.

- [ ] **Step 3: Implement the minimal hover progress and derived geometry**

Modify `modules/island/IslandBody.qml` so the collapsed island has a passive hover driver and uses it to expand modestly. Keep the expanded state visually stable.

Add geometry constants and a hover signal shaped like this:

```qml
readonly property int collapsedHoverWidthLift: 20
readonly property int collapsedHoverHeightLift: 8
readonly property int collapsedHoverRadiusLift: 6
property real hoverProgress: islandHoverHandler.hovered && !Services.IslandService.expanded ? 1 : 0

readonly property real currentHoverWidthLift: collapsedHoverWidthLift * hoverProgress
readonly property real currentHoverHeightLift: collapsedHoverHeightLift * hoverProgress
readonly property real currentHoverRadiusLift: collapsedHoverRadiusLift * hoverProgress
```

Add a passive handler near the root item:

```qml
// Track passive hover so the collapsed island breathes like other dockzones.
HoverHandler {
    id: islandHoverHandler
    enabled: !Services.IslandService.expanded
}
```

Update size and radius derivation so collapsed mode includes the hover lift while expanded mode stays unchanged:

```qml
property int targetW: Services.IslandService.expanded ? expandedW : collapsedW + currentHoverWidthLift
property int targetH: Services.IslandService.expanded ? expandedH : collapsedH + currentHoverHeightLift
property int targetR: Services.IslandService.expanded ? 24 : 14 + currentHoverRadiusLift
```

- [ ] **Step 4: Use the shared motion contract for hover reset**

Keep the existing width/height/radius `Behavior`, but switch the spring values to the shared hover motion tokens so the feel matches dockzones:

```qml
Behavior on width {
    SpringAnimation {
        spring: Services.Motion.hover.spring
        damping: Services.Motion.hover.damping
        mass: Services.Motion.hover.mass
        epsilon: Services.Motion.hover.epsilon
    }
}
```

Apply the same spring block to `height` and `bodyRadius`.

- [ ] **Step 5: Verify hover motion works**

Launch the shell and repeat the manual loop:

1. Hover into the collapsed center island.
2. Expected: the island expands slightly in width/height and softens its radius.
3. Hover out.
4. Expected: the same island surface springs back smoothly instead of snapping.


### Task 2: Reconnect Center Editing To BarLayoutService

**Files:**
- Modify: `modules/island/IslandBody.qml`
- Reference: `services/BarLayoutService.qml`
- Reference: `modules/bar/BarContextMenu.qml`

- [ ] **Step 1: Write the failing behavioral check**

Observe and record the current failure in the running shell:

1. Right-click the collapsed center island.
2. Expected failure now: no center-specific bar context menu opens.
3. Try entering layout mode from elsewhere and returning to the center island.
4. Expected failure now: the center surface still has no direct editing entry point.

- [ ] **Step 2: Verify the existing service API already supports center editing**

Read `services/BarLayoutService.qml` and confirm the existing API can be reused without new services:

```qml
function openContextMenu(x, instanceKey, widgetId) {
    contextMenuX = x
    contextMenuWidgetKey = instanceKey || ""
    contextMenuWidgetId = widgetId || ""
    contextMenuSection = _sectionForX(x)
    contextMenuVisible = true
}
```

Expected: opening the bar context menu is already centralized and the widget picker path already exists.

- [ ] **Step 3: Add the minimal right-click bridge in IslandBody**

Add a right-click `MouseArea` covering the collapsed island body surface and forward the event to the existing service using scene coordinates:

```qml
// Route center-island right click into the shared bar editing menu.
MouseArea {
    anchors.fill: parent
    enabled: !Services.IslandService.expanded
    acceptedButtons: Qt.RightButton
    propagateComposedEvents: true

    onClicked: (mouse) => {
        var scenePos = root.mapToItem(null, mouse.x, mouse.y)
        Services.BarLayoutService.openContextMenu(scenePos.x, "", "")
    }
}
```

Place this bridge on the visible collapsed body owner so it receives the event before the hidden `centerSection` would.

- [ ] **Step 4: Keep left click toggle behavior intact**

Ensure the existing collapsed left-click toggle remains left-button-only:

```qml
MouseArea {
    anchors.fill: parent
    enabled: !Services.IslandService.expanded
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: Services.IslandService.toggle()
}
```

Do not let the new right-click bridge consume left-click activation.

- [ ] **Step 5: Verify center editing is restored**

Run this manual loop:

1. Right-click the collapsed center island.
2. Expected: `BarContextMenu` opens.
3. Click `Add Widget to center`.
4. Expected: `WidgetPickerWindow` opens with `center` as the target section.
5. Add a widget.
6. Expected: the layout model updates and the new widget appears in the center section owner path.


### Task 3: Regression Sweep And Code Hygiene

**Files:**
- Modify: `modules/island/IslandBody.qml`
- Check: `modules/island/IslandWindow.qml`
- Check: `modules/bar/BarContent.qml`

- [ ] **Step 1: Add required declaration comments while editing QML**

Before each major declaration you touch in `modules/island/IslandBody.qml`, add a short English intent comment, for example:

```qml
// Track passive hover so the collapsed island breathes like other dockzones.
HoverHandler { ... }

// Route center-island right click into the shared bar editing menu.
MouseArea { ... }
```

- [ ] **Step 2: Check for interaction regressions**

In the running shell, verify these cases:

1. Left/right dockzones still animate on hover as before.
2. Collapsed center island still opens the launcher on left click.
3. Expanded island still accepts full-window click-away dismiss.
4. Right-clicking the collapsed center island does not accidentally expand it.

- [ ] **Step 3: Check for layout/editing regressions**

Verify these edit flows:

1. Right-click left or right dockzones still opens the shared context menu.
2. Right-click collapsed center island opens the same menu.
3. `Add Widget to center` still targets `center`.
4. Removing a center widget from the menu still works.

- [ ] **Step 4: Run a final source scan for accidental architecture drift**

Read the changed files and confirm these constraints still hold:

```qml
// Hidden: island module now owns center content.
visible: false
```

Expected: `modules/bar/BarContent.qml` still keeps `centerSection` hidden, and the fix lives in the island owner instead of reintroducing a second visible center surface.
