# Position-Driven Expansion Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable layout-native expansion primitive and migrate the first eligible settings section to it without changing panel/window or bar-widget motion contracts.

**Architecture:** Introduce `modules/layout/PositionDrivenExpander.qml` as the only adopted-axis size owner for layout-native expansion. Verify it with a dedicated single-file QML harness run through the same `qs -p <file> -- <mode>` pattern already used by the repo's bar-motion harness, then migrate `modules/bar/settings/ExpandableGroup.qml` by making the new primitive the actual layout participant instead of wrapping it inside another size-owning root. Keep the primitive's public `expanded` API exactly as defined in the spec. By explicit user decision, `forceExpand` remains only as `ExpandableGroup.qml`'s existing compatibility API and is bridged through one private `_resolvedExpanded` path inside the primitive; it does not become part of the primitive's public contract.

**Tech Stack:** QML, Quickshell, QtQuick, existing `Theme.anim.*` tokens, shell-level harnesses run through `qs -p <file> -- <mode>`

---

## File Map

- Create: `modules/layout/`
  - New layout-local primitive namespace for first-wave expansion ownership.
- Create: `tests/qml/layout/`
  - New harness namespace for layout-native expansion verification.
- Create: `modules/layout/PositionDrivenExpander.qml`
  - Own the adopted-axis animated extent.
  - Read `collapsedSource` and `expandedSource` implicit size.
  - Publish `implicitHeight` or `implicitWidth` from `animatedExtent`.
  - Keep the orthogonal axis caller-owned.
- Modify: `modules/bar/settings/ExpandableGroup.qml`
  - Replace local `implicitHeight` expansion ownership by making `PositionDrivenExpander` the root type.
  - Keep header interaction, arrow rotation, title color, highlight, ripple, flash, and default-property content alias local.
- Create: `tests/qml/layout/PositionDrivenExpanderHarness.qml`
  - Dedicated harness entry file with multiple modes for primitive and `ExpandableGroup` verification.
- Create: `tests/qml/layout/PositionDrivenExpanderImportProbe.qml`
  - Minimal import-resolution probe used only after the primitive file exists.
- Create: `tests/run-position-driven-expander-harness.sh`
  - Thin wrapper for invoking the harness with `qs -p`.

This plan intentionally does **not** touch `modules/bar/settings/FontPickerSection.qml`, `modules/bar/settings/SettingsSidebar.qml`, `modules/bar/AnimatedPanelBase.qml`, or `modules/bar/BarExpandTransition.qml`.

---

### Task 1: Create the failing harness entrypoint

**Files:**
- Create: `modules/layout/`
- Create: `tests/qml/layout/`
- Create: `tests/qml/layout/PositionDrivenExpanderHarness.qml`
- Create: `tests/run-position-driven-expander-harness.sh`

- [ ] **Step 1: Create the missing module and harness directories if needed**

Create these directories before writing files into them:

- `modules/layout/`
- `tests/qml/layout/`

- [ ] **Step 2: Write the single-file harness skeleton**

Create `tests/qml/layout/PositionDrivenExpanderHarness.qml` with explicit imports and a small assertion helper. Follow the repo's bar-motion harness style by using one QML entry file plus `Quickshell.args` mode switching:

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../modules/layout"
import "../../../modules/bar/settings" as SettingsParts
import qs.config

Item {
    id: root
    width: 320
    height: 320

    readonly property string mode: Quickshell.args.length > 0
        ? Quickshell.args[0]
        : "primitive"

    function assertTrue(condition, message) {
        if (!condition)
            throw new Error(message)
    }

}
```

Keep the harness as one entry file so `qs -p tests/qml/layout/PositionDrivenExpanderHarness.qml -- <mode>` resolves the same imports every time.

- [ ] **Step 3: Add an import-readiness mode before any behavioral checks**

Add a mode that only instantiates `PositionDrivenExpander` after the file exists and exits immediately. This proves the repo accepts the new `modules/layout` relative import path without needing extra module metadata.

- [ ] **Step 4: Add a failing `primitive` mode**

Inside the harness, add realized measurement nodes and one missing-component use site:

```qml
Item {
    id: collapsedNode
    implicitWidth: 120
    implicitHeight: 40
    visible: false
}

Item {
    id: expandedNode
    implicitWidth: 120
    implicitHeight: 96
    visible: false
}

PositionDrivenExpander {
    id: expander
    collapsedSource: collapsedNode
    expandedSource: expandedNode
    expanded: false
}

Component.onCompleted: {
    if (root.mode !== "primitive")
        return
    root.assertTrue(expander.collapsedExtent === 40, "collapsed extent should come from collapsedSource")
    root.assertTrue(expander.expandedExtent === 96, "expanded extent should come from expandedSource")
    Qt.quit()
}
```

This should fail because `PositionDrivenExpander.qml` does not exist yet.

- [ ] **Step 5: Add the harness runner**

Create `tests/run-position-driven-expander-harness.sh`:

```bash
#!/usr/bin/env sh
set -eu

MODE="${1:-primitive}"
timeout 5 qs -p tests/qml/layout/PositionDrivenExpanderHarness.qml -- "$MODE"
```

- [ ] **Step 6: Run the harness and confirm the expected failure**

Run: `sh tests/run-position-driven-expander-harness.sh primitive`

Expected: FAIL because `PositionDrivenExpander` is missing.

### Task 2: Implement `PositionDrivenExpander.qml` and lock primitive behavior

**Files:**
- Create: `modules/layout/PositionDrivenExpander.qml`
- Create: `tests/qml/layout/PositionDrivenExpanderImportProbe.qml`
- Modify: `tests/qml/layout/PositionDrivenExpanderHarness.qml`

- [ ] **Step 1: Write the minimal primitive implementation**

Create `modules/layout/PositionDrivenExpander.qml`:

```qml
import QtQuick
import qs.config

Item {
    id: root

    required property Item collapsedSource
    required property Item expandedSource
    required property bool expanded
    property int axis: Qt.Vertical
    property bool clipOverflow: true

    readonly property bool _validSources: collapsedSource !== null && expandedSource !== null
    property bool _resolvedExpanded: expanded
    readonly property real collapsedExtent: _validSources
        ? (axis === Qt.Vertical ? collapsedSource.implicitHeight : collapsedSource.implicitWidth)
        : 0
    readonly property real expandedExtent: _validSources
        ? (axis === Qt.Vertical ? expandedSource.implicitHeight : expandedSource.implicitWidth)
        : 0
    readonly property real targetExtent: _resolvedExpanded ? expandedExtent : collapsedExtent
    property bool _initialized: false
    property real animatedExtent: targetExtent
    readonly property bool running: extentAnim.running

    clip: clipOverflow

    Binding on implicitWidth {
        when: root.axis === Qt.Horizontal
        value: root.animatedExtent
    }

    Binding on implicitHeight {
        when: root.axis === Qt.Vertical
        value: root.animatedExtent
    }

    Component.onCompleted: {
        if (!_validSources)
            throw new Error("measurement sources must be realized items")
        animatedExtent = targetExtent
        _initialized = true
    }

    onTargetExtentChanged: {
        if (!_validSources)
            throw new Error("measurement sources must be realized items")
        if (!_initialized) {
            animatedExtent = targetExtent
            return
        }
        if (targetExtent === animatedExtent)
            return
        extentAnim.stop()
        extentAnim.from = animatedExtent
        extentAnim.to = targetExtent
        extentAnim.restart()
    }

    NumberAnimation {
        id: extentAnim
        target: root
        property: "animatedExtent"
        duration: Theme.anim.moveDuration
        easing.type: Theme.anim.moveType
    }
}
```

This private `_resolvedExpanded` hook exists only so a derived root component such as `ExpandableGroup.qml` can preserve its own compatibility rules (`expanded || forceExpand`) without changing the primitive's public API. This bridge is intentionally allowed in this plan because the user explicitly approved the private-bridge approach.

Do not reference `_resolvedExpanded` from harness code, downstream components, or any new public API. It is implementation-only.

- [ ] **Step 2: Add a dedicated import probe file**

Create `tests/qml/layout/PositionDrivenExpanderImportProbe.qml` with only the imports and a minimal instantiation:

```qml
import QtQuick
import "../../../modules/layout"

Item {
    id: root

    Item { id: collapsedNode; implicitHeight: 10; implicitWidth: 10 }
    Item { id: expandedNode; implicitHeight: 20; implicitWidth: 10 }

    PositionDrivenExpander {
        collapsedSource: collapsedNode
        expandedSource: expandedNode
        expanded: false
    }
}
```

- [ ] **Step 3: Run the import probe and primitive mode and confirm they pass**

Run: `timeout 5 qs -p tests/qml/layout/PositionDrivenExpanderImportProbe.qml && sh tests/run-position-driven-expander-harness.sh primitive`

Expected: PASS and imports resolve cleanly for `modules/layout`.

- [ ] **Step 4: Add a sibling-reflow mode before any integration work**

Extend the harness with a real layout stack that proves push-down behavior instead of only checking extents:

```qml
ColumnLayout {
    id: reflowColumn
    width: 200

    Rectangle { id: topSibling; Layout.fillWidth: true; implicitHeight: 20 }

    PositionDrivenExpander {
        id: reflowExpander
        Layout.fillWidth: true
        collapsedSource: collapsedNode
        expandedSource: expandedNode
        expanded: false
    }

    Rectangle { id: bottomSibling; Layout.fillWidth: true; implicitHeight: 20 }
}
```

In `reflow` mode, record `bottomSibling.y`, toggle `reflowExpander.expanded = true`, wait for `running === false`, then assert `bottomSibling.y` increased because the layout consumed the expander's `implicitHeight`.

- [ ] **Step 5: Add `direct-child` and `wrapper-between` eligibility modes**

Add two structure checks:

- `direct-child`: mount the expander as a direct `ColumnLayout` child and assert normal reflow
- `wrapper-between`: mount `ColumnLayout -> Item wrapper -> PositionDrivenExpander` and mark it as an explicit negative/non-goal for v1

Use these two modes to pin the spec's direct-child eligibility rule in the harness notes.

- [ ] **Step 6: Add an `init-gate` mode**

Exercise the first-sync rule explicitly:

```qml
Component.onCompleted: {
    if (root.mode !== "init-gate")
        return

    root.assertTrue(expander.running === false,
        "first binding sync should not start an animation")
    root.assertTrue(expander.animatedExtent === expander.collapsedExtent,
        "first binding sync should settle directly on the initial target")
    Qt.quit()
}
```

- [ ] **Step 5: Add a `retarget` mode that waits for settled state instead of sleeping a fixed time**

Extend the harness with a polling helper:

```qml
Timer {
    id: settlePoll
    interval: 16
    repeat: true
    property var onStable
    onTriggered: {
        if (!expander.running) {
            stop()
            onStable()
        }
    }
}
```

Then add a retarget flow:

```qml
Component.onCompleted: {
    if (root.mode !== "retarget")
        return

    expander.expanded = true
    expandedNode.implicitHeight = 132
    settlePoll.onStable = function() {
        root.assertTrue(Math.abs(expander.animatedExtent - 132) < 0.5,
            "retarget should settle on the latest expanded extent")
        Qt.quit()
    }
    settlePoll.start()
}
```

- [ ] **Step 6: Add a `collapsed-retarget` mode**

Exercise the opposite direction too:

```qml
Component.onCompleted: {
    if (root.mode !== "collapsed-retarget")
        return

    expander.expanded = false
    collapsedNode.implicitHeight = 52
    settlePoll.onStable = function() {
        root.assertTrue(Math.abs(expander.animatedExtent - 52) < 0.5,
            "collapsed retarget should settle on the latest collapsed extent")
        Qt.quit()
    }
    settlePoll.start()
}
```

- [ ] **Step 7: Add deterministic negative source-validity modes**

Add two explicit construction-failure modes:

- `invalid-source`: construct `PositionDrivenExpander` with `collapsedSource: null`
- `loader-null-source`: construct it with `collapsedSource: loader.item` while `loader.item === null`

Both modes should fail deterministically with a nonzero exit. Treat the exact error text as diagnostic rather than the primary assertion.

- [ ] **Step 8: Add a `horizontal` mode**

Exercise the horizontal contract explicitly:

```qml
PositionDrivenExpander {
    id: horizontalExpander
    collapsedSource: collapsedNode
    expandedSource: expandedNode
    expanded: true
    axis: Qt.Horizontal
}
```

Assert that `implicitWidth` settles to the expanded source width and that the vertical axis remains caller-owned.

- [ ] **Step 9: Add a `clip-overflow` mode**

Exercise the containment rule explicitly in a real layout container by placing content taller than the collapsed extent inside the primitive while it is collapsed:

```qml
PositionDrivenExpander {
    id: clipExpander
    width: 200
    collapsedSource: collapsedNode
    expandedSource: expandedNode
    expanded: false
    clipOverflow: true

    Rectangle {
        id: oversizedContent
        width: 200
        height: 140
        y: 0
    }
}
```

Assert that the primitive stays at the collapsed extent, the oversized content is clipped, and the lower sibling does not move until expansion starts.

- [ ] **Step 10: Add a `scroll-passive` mode**

Wrap the same layout in a `Flickable` and assert two things:

- the expander still drives sibling reflow inside the content layout
- the scroll host only clips/scrolls and does not become the sizing owner

Use a simple `Flickable -> contentItem -> ColumnLayout -> PositionDrivenExpander` shape so the host/content split is explicit and stable in this repo.

Concrete sketch:

```qml
Flickable {
    id: flickableHost
    width: 220
    height: 80
    contentHeight: scrollColumn.implicitHeight

    ColumnLayout {
        id: scrollColumn
        width: 200

        Rectangle { id: scrollTopSibling; Layout.fillWidth: true; implicitHeight: 20 }

        PositionDrivenExpander {
            id: scrollExpander
            Layout.fillWidth: true
            collapsedSource: collapsedNode
            expandedSource: expandedNode
            expanded: false
        }

        Rectangle { id: scrollBottomSibling; Layout.fillWidth: true; implicitHeight: 20 }
    }
}
```

Record `scrollBottomSibling.y`, expand `scrollExpander`, then assert the sibling moves while `flickableHost.height` stays fixed at `80` and `flickableHost.contentHeight` grows.

- [ ] **Step 11: Add one explicit virtualization-host negative note**

In the harness file comments and in the task notes, document that `ListView` / `GridView` delegates are out of scope for v1 and are not covered by the positive harness modes.

- [ ] **Step 12: Run the positive primitive harness sweep**

Run: `timeout 5 qs -p tests/qml/layout/PositionDrivenExpanderImportProbe.qml && sh tests/run-position-driven-expander-harness.sh primitive && sh tests/run-position-driven-expander-harness.sh direct-child && sh tests/run-position-driven-expander-harness.sh init-gate && sh tests/run-position-driven-expander-harness.sh reflow && sh tests/run-position-driven-expander-harness.sh retarget && sh tests/run-position-driven-expander-harness.sh collapsed-retarget && sh tests/run-position-driven-expander-harness.sh horizontal && sh tests/run-position-driven-expander-harness.sh clip-overflow && sh tests/run-position-driven-expander-harness.sh scroll-passive`

Expected: PASS.

- [ ] **Step 13: Run an early repo load check before the integration migration**

Run: `timeout 5 qs --path .`

Expected: PASS aside from known environment warnings.

- [ ] **Step 14: Run the negative source-validity modes with harness-asserted expected-fail wrappers**

Run:

```bash
if sh tests/run-position-driven-expander-harness.sh invalid-source; then exit 1; fi
if sh tests/run-position-driven-expander-harness.sh loader-null-source; then exit 1; fi
```

Expected: both runs exit nonzero.

- [ ] **Step 15: Optional checkpoint commit for the harness and primitive foundation**

```bash
git add modules/layout/PositionDrivenExpander.qml tests/qml/layout/PositionDrivenExpanderHarness.qml tests/run-position-driven-expander-harness.sh
git commit -m "feat: add position-driven expansion foundation"
```

---

### Task 3: Add a failing `ExpandableGroup` integration harness

**Files:**
- Modify: `tests/qml/layout/PositionDrivenExpanderHarness.qml`

- [ ] **Step 1: Mount `ExpandableGroup.qml` inside a real layout with siblings**

Add a mode that instantiates the real component inside `ColumnLayout` so the test exercises actual layout consumption:

```qml
ColumnLayout {
    id: groupHost
    width: 296

    Rectangle {
        id: groupTopSibling
        Layout.fillWidth: true
        implicitHeight: 16
    }

    SettingsParts.ExpandableGroup {
        id: group
        Layout.fillWidth: true
        title: "Harness Group"
        expanded: false

        Rectangle {
            id: dynamicRect
            implicitWidth: 296
            implicitHeight: 32
        }

        Rectangle { implicitWidth: 296; implicitHeight: 24 }
    }

    Rectangle {
        id: groupBottomSibling
        Layout.fillWidth: true
        implicitHeight: 16
    }
}
```

- [ ] **Step 2: Assert group expansion pushes the lower sibling through layout reflow**

Drive the state change and poll until stable:

```qml
Component.onCompleted: {
    if (root.mode !== "expandable-group")
        return

    let initialBottomY = groupBottomSibling.y
    group.expanded = true
    settlePoll.onStable = function() {
        root.assertTrue(group.implicitHeight > Theme.settingsGroupHeaderHeight,
            "expanded group should grow beyond header height")
        root.assertTrue(groupBottomSibling.y > initialBottomY,
            "expanded group should push the lower sibling through layout reflow")
        Qt.quit()
    }
    settlePoll.start()
}
```

At this point the test should still fail because `ExpandableGroup.qml` still owns expansion locally.

- [ ] **Step 3: Run the integration harness and confirm the expected failure**

Run: `sh tests/run-position-driven-expander-harness.sh expandable-group`

Expected: FAIL before migration.

---

### Task 4: Migrate `ExpandableGroup.qml` with a single state bridge

**Files:**
- Modify: `modules/bar/settings/ExpandableGroup.qml`
- Verify: `modules/layout/PositionDrivenExpander.qml`
- Verify: `tests/qml/layout/PositionDrivenExpanderHarness.qml`

- [ ] **Step 1: Change the root type of `ExpandableGroup.qml` to `PositionDrivenExpander`**

Make `PositionDrivenExpander` the root object so it becomes the actual layout participant:

```qml
import QtQuick
import QtQuick.Layouts
import qs.config
import ".."
import "../../layout"

PositionDrivenExpander {
    id: root

    property string title: ""
    property bool forceExpand: false
    Layout.fillWidth: true
    _resolvedExpanded: expanded || forceExpand
    readonly property real _contentWidth: width > 0 ? width : implicitWidth

    collapsedSource: collapsedMeasure
    expandedSource: expandedMeasure
}
```

Do **not** leave an outer `Item` that binds its own `implicitHeight` to the expander. That would violate the spec.

This step must explicitly preserve the old horizontal sizing contract through layout ownership. The component should fill width when hosted in layouts, while `_contentWidth` only reflects actual host-owned width or implicit width instead of a hardcoded fallback.

This step must also keep `forceExpand` scoped to `ExpandableGroup.qml` only. Do not add it to `PositionDrivenExpander.qml` as a public property.

This works only because Task 2 added `_resolvedExpanded` as one private hook inside the primitive. Task 4 must use that hook exactly once at the root binding site; do not introduce a second bridge layer inside `ExpandableGroup.qml`.

- [ ] **Step 2: Document the explicit state handoff before touching layout structure**

Write the state mapping down before moving child items around:

- `expanded` stays the user-controlled toggle state
- `forceExpand` stays the external compatibility override
- `_resolvedExpanded` is the only effective-open bridge
- the primitive animates from `_resolvedExpanded`, not directly from raw toggle input
- first sync must still snap, not animate

- [ ] **Step 3: Restore measurement items and default content alias without changing header affordances yet**

Inside the new root:

```qml
Item {
    id: collapsedMeasure
    width: root._contentWidth
    implicitHeight: header.height
    visible: false
}

Item {
    id: expandedMeasure
    width: root._contentWidth
    implicitHeight: header.height + contentCol.implicitHeight
    visible: false
}

default property alias content: contentCol.data

Item {
    id: header
    width: root._contentWidth
    height: Theme.settingsGroupHeaderHeight
}

Column {
    id: contentCol
    anchors.top: header.bottom
    width: root._contentWidth
}
```

The goal of this step is only to preserve content reparenting and measurement structure.

Keep `default property alias content: contentCol.data` as the only insertion path so expanded content participates in measurement exactly once.

For this first migration wave, require the host layout or harness to supply a real width. Do not add a new magic-number width fallback inside `ExpandableGroup.qml`.

- [ ] **Step 4: Add a `width-fallback` harness mode before layout verification**

Mount the migrated group in a layout-owned width host and assert the component still measures correctly without a hardcoded fallback:

```qml
ColumnLayout {
    width: 296

    SettingsParts.ExpandableGroup {
        id: widthFallbackGroup
        Layout.fillWidth: true
        title: "Width Fallback"
        expanded: false

        Rectangle { implicitWidth: 296; implicitHeight: 24 }
    }

    Rectangle { id: widthFallbackBottom; Layout.fillWidth: true; implicitHeight: 16 }
}
```

Assert that `widthFallbackGroup.width > 0` and that expanding it still pushes `widthFallbackBottom`.

- [ ] **Step 5: Port public API and overlay/header affordance parity before layout verification**

Before running layout checks, explicitly restore and verify:

- `highlighted`
- `clearHighlight()`
- `flash()`
- hover highlight layer
- click ripple layer
- persistent highlight overlay
- flash overlay

- [ ] **Step 6: Add one explicit no-outer-owner verification point**

Before restoring local affordances, confirm the migrated file no longer contains:

- outer `Item` ownership of `implicitHeight`
- `Behavior on implicitHeight` on the root
- any second same-axis geometry owner above `PositionDrivenExpander`
- any accidental loss of the old `implicitWidth` / full-width contract

- [ ] **Step 7: Reattach the header and overlay affordances exactly as they were**

Keep these behaviors local and unchanged:

- arrow rotation animation
- title color transition
- hover highlight
- click ripple
- persistent highlight overlay
- flash overlay and `flash()` API
- `highlighted` and `clearHighlight()`

Do not reintroduce `Behavior on implicitHeight` on the component root.

- [ ] **Step 8: Add a real-component retarget mode while the group is already open**

Extend the harness so it mutates the content after opening:

```qml
Component.onCompleted: {
    if (root.mode !== "expandable-group-retarget")
        return

    group.expanded = true
    settlePoll.onStable = function() {
        dynamicRect.implicitHeight = 48
        settlePoll.onStable = function() {
            root.assertTrue(group.implicitHeight > Theme.settingsGroupHeaderHeight + 48,
                "group should retarget after measured content changes while open")
            Qt.quit()
        }
        settlePoll.start()
    }
    settlePoll.start()
}
```

- [ ] **Step 9: Add a `force-expand` regression mode**

Exercise the compatibility override independently from the user toggle:

```qml
Component.onCompleted: {
    if (root.mode !== "force-expand")
        return

    group.expanded = false
    group.forceExpand = true
    settlePoll.onStable = function() {
        root.assertTrue(group.implicitHeight > Theme.settingsGroupHeaderHeight,
            "forceExpand should open the group even when expanded is false")
        Qt.quit()
    }
    settlePoll.start()
}
```

- [ ] **Step 10: Run the positive integration modes and confirm they pass**

The harness must reuse the same `dynamicRect` declared in Step 1 so this mode mutates a real measured child.

Run: `sh tests/run-position-driven-expander-harness.sh expandable-group && sh tests/run-position-driven-expander-harness.sh width-fallback && sh tests/run-position-driven-expander-harness.sh expandable-group-retarget && sh tests/run-position-driven-expander-harness.sh force-expand`

Expected: PASS.

- [ ] **Step 11: Run grouped positive harness sweeps**

Run primitive group:

```bash
sh tests/run-position-driven-expander-harness.sh primitive && sh tests/run-position-driven-expander-harness.sh direct-child && sh tests/run-position-driven-expander-harness.sh init-gate && sh tests/run-position-driven-expander-harness.sh reflow && sh tests/run-position-driven-expander-harness.sh retarget && sh tests/run-position-driven-expander-harness.sh collapsed-retarget && sh tests/run-position-driven-expander-harness.sh horizontal
```

Run containment group:

```bash
sh tests/run-position-driven-expander-harness.sh clip-overflow && sh tests/run-position-driven-expander-harness.sh scroll-passive
```

Run integration group:

```bash
sh tests/run-position-driven-expander-harness.sh expandable-group && sh tests/run-position-driven-expander-harness.sh width-fallback && sh tests/run-position-driven-expander-harness.sh expandable-group-retarget && sh tests/run-position-driven-expander-harness.sh force-expand
```

Expected: PASS.

- [ ] **Step 12: Re-run the negative source-validity mode separately**

Run:

```bash
if sh tests/run-position-driven-expander-harness.sh invalid-source; then exit 1; fi
if sh tests/run-position-driven-expander-harness.sh loader-null-source; then exit 1; fi
```

Expected: both runs exit nonzero.

- [ ] **Step 13: Optional checkpoint commit for the integration migration**

```bash
git add modules/bar/settings/ExpandableGroup.qml modules/layout/PositionDrivenExpander.qml tests/qml/layout/PositionDrivenExpanderHarness.qml tests/run-position-driven-expander-harness.sh
git commit -m "refactor: migrate expandable group to position-driven expansion"
```

---

### Task 5: Final verification and scope guard

**Files:**
- Verify: `modules/layout/PositionDrivenExpander.qml`
- Verify: `modules/bar/settings/ExpandableGroup.qml`
- Verify: `modules/bar/settings/FontPickerSection.qml`
- Verify: `modules/bar/settings/SettingsSidebar.qml`
- Verify: `tests/qml/layout/PositionDrivenExpanderHarness.qml`
- Verify: `tests/run-position-driven-expander-harness.sh`

- [ ] **Step 1: Re-run the positive harness modes only**

Run: `timeout 5 qs -p tests/qml/layout/PositionDrivenExpanderImportProbe.qml && sh tests/run-position-driven-expander-harness.sh primitive && sh tests/run-position-driven-expander-harness.sh direct-child && sh tests/run-position-driven-expander-harness.sh init-gate && sh tests/run-position-driven-expander-harness.sh reflow && sh tests/run-position-driven-expander-harness.sh retarget && sh tests/run-position-driven-expander-harness.sh collapsed-retarget && sh tests/run-position-driven-expander-harness.sh horizontal && sh tests/run-position-driven-expander-harness.sh clip-overflow && sh tests/run-position-driven-expander-harness.sh scroll-passive && sh tests/run-position-driven-expander-harness.sh expandable-group && sh tests/run-position-driven-expander-harness.sh width-fallback && sh tests/run-position-driven-expander-harness.sh expandable-group-retarget && sh tests/run-position-driven-expander-harness.sh force-expand`

Expected: PASS.

- [ ] **Step 2: Re-run the invalid-source negative mode**

Run:

```bash
if sh tests/run-position-driven-expander-harness.sh invalid-source; then exit 1; fi
if sh tests/run-position-driven-expander-harness.sh loader-null-source; then exit 1; fi
```

Expected: both runs exit nonzero.

- [ ] **Step 3: Run the shell load check**

Run: `timeout 5 qs --path .`

Expected: PASS aside from known environment warnings.

- [ ] **Step 4: Confirm deferred scope stayed deferred**

Verify these files are unchanged in this wave:

- `modules/bar/settings/FontPickerSection.qml`
- `modules/bar/settings/SettingsSidebar.qml`
- `modules/bar/AnimatedPanelBase.qml`
- `modules/bar/BarExpandTransition.qml`

- [ ] **Step 5: Commit the final verification checkpoint**

```bash
git add modules/layout/PositionDrivenExpander.qml modules/bar/settings/ExpandableGroup.qml tests/qml/layout/PositionDrivenExpanderHarness.qml tests/run-position-driven-expander-harness.sh
git commit -m "test: verify first-wave position-driven expansion migration"
```
