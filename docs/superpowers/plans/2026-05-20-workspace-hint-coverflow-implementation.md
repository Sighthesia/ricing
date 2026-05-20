# Workspace Hint Coverflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current three-slot workspace hint stack with a fixed-camera coverflow-style scrolling viewport that keeps all workspace capsules alive while `mod` is held and animates multi-step workspace switching continuously.

**Architecture:** Keep `services/WindowHintService.qml` as the data source, then move scroll orchestration into `modules/workspace-hint/WorkspaceHintWindow.qml`. Introduce a small pure logic helper for queue decomposition and visual math so the coverflow behavior can be tested with `qmltestrunner` before the window and capsule QML are updated.

**Tech Stack:** QML, QtTest via `qmltestrunner`, Quickshell, existing services in `services/`, existing motion tokens in `services/Motion.qml`.

---

## File Map

- Create: `modules/workspace-hint/WorkspaceHintViewportModel.js`
  - Pure logic for step queue decomposition, clamped bounce targets, relative offset math, and opacity/focus progression helpers.
- Create: `modules/workspace-hint/WorkspaceHintViewportState.qml`
  - Small non-visual state owner for queue progression, boundary rebound state, and testable `visualFocusPosition` behavior.
- Modify: `services/WindowHintService.qml`
  - Add previous workspace position and transition revision metadata while keeping visual math out of the service.
- Modify: `modules/workspace-hint/WorkspaceHintWindow.qml`
  - Replace the three fixed capsules with a repeater-backed viewport driven by `WorkspaceHintViewportState`.
- Modify: `modules/workspace-hint/WorkspaceHintCapsule.qml`
  - Accept relative-position-driven inputs and animate width, opacity, and content handoff continuously.
- Create: `tests/qml/tst_workspace_hint.qml`
  - QML tests for pure viewport logic, service transition metadata, capsule morphing, queue progression, boundary rebound, and held-lifecycle behavior.

### Task 1: Add Testable Viewport Math Helper

**Files:**
- Create: `modules/workspace-hint/WorkspaceHintViewportModel.js`
- Create: `tests/qml/tst_workspace_hint.qml`
- Reference: `modules/workspace-hint/WorkspaceHintWindow.qml`

- [ ] **Step 1: Write the failing QML tests for queue and fade math**

Create `tests/qml/tst_workspace_hint.qml` with a first `TestCase` that imports the helper and asserts the expected queue decomposition and opacity behavior.

```qml
import QtQuick
import QtTest
import "../../modules/workspace-hint/WorkspaceHintViewportModel.js" as ViewportModel

TestCase {
    name: "WorkspaceHintViewportModel"

    function test_buildStepQueue_walks_each_workspace() {
        compare(JSON.stringify(ViewportModel.buildStepQueue(1, 3)), JSON.stringify([2, 3]))
        compare(JSON.stringify(ViewportModel.buildStepQueue(3, 1)), JSON.stringify([2, 1]))
        compare(JSON.stringify(ViewportModel.buildStepQueue(2, 2)), JSON.stringify([]))
    }

    function test_opacity_keeps_neighbors_fully_visible() {
        compare(ViewportModel.opacityForDistance(0, 72, 216), 1)
        compare(ViewportModel.opacityForDistance(1, 72, 216), 1)
        verify(ViewportModel.opacityForDistance(2, 72, 216) < 1)
        compare(ViewportModel.opacityForDistance(5, 72, 216), 0)
    }

    function test_boundary_bounce_stays_small_and_signed() {
        compare(ViewportModel.boundaryBounceTarget(0, -1, 0.18), -0.18)
        compare(ViewportModel.boundaryBounceTarget(4, 1, 0.18), 4.18)
    }
}
```

- [ ] **Step 2: Run the QML tests to verify they fail**

Run: `qmltestrunner -input tests/qml/tst_workspace_hint.qml`

Expected: FAIL with import or `Property 'buildStepQueue' of object [object Object] is not a function` because the helper file does not exist yet.

- [ ] **Step 3: Write the minimal pure logic helper**

Create `modules/workspace-hint/WorkspaceHintViewportModel.js` with only the deterministic helpers the tests need.

```javascript
.pragma library

function buildStepQueue(fromPosition, toPosition) {
    const steps = []
    if (fromPosition === toPosition)
        return steps

    const direction = toPosition > fromPosition ? 1 : -1
    for (let cursor = fromPosition + direction; direction > 0 ? cursor <= toPosition : cursor >= toPosition; cursor += direction)
        steps.push(cursor)
    return steps
}

function opacityForDistance(distance, capsulePitch, fadeDistance) {
    const absoluteDistance = Math.abs(distance)
    if (absoluteDistance <= 1)
        return 1

    const yDistance = Math.max(0, (absoluteDistance - 1) * capsulePitch)
    if (yDistance >= fadeDistance)
        return 0

    return 1 - (yDistance / fadeDistance)
}

function boundaryBounceTarget(edgePosition, direction, amplitude) {
    return edgePosition + (direction * amplitude)
}

function relativeOffset(workspacePosition, visualFocusPosition) {
    return workspacePosition - visualFocusPosition
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `qmltestrunner -input tests/qml/tst_workspace_hint.qml`

Expected: PASS for `WorkspaceHintViewportModel`.

- [ ] **Step 5: Commit**

```bash
git add modules/workspace-hint/WorkspaceHintViewportModel.js tests/qml/tst_workspace_hint.qml
git commit -m "test(workspace-hint): add viewport math coverage"
```

### Task 2: Add Transition Metadata To WindowHintService

**Files:**
- Modify: `services/WindowHintService.qml`
- Modify: `tests/qml/tst_workspace_hint.qml`

- [ ] **Step 1: Extend the failing test with service transition expectations**

Append a second `TestCase` to `tests/qml/tst_workspace_hint.qml` that checks previous position and revision updates without asking the service for visual math.

```qml
import "../../services" as Services

TestCase {
    name: "WindowHintServiceTransitions"

    function test_empty_hint_exposes_transition_metadata() {
        const hint = Services.WindowHintService._emptyHint()
        compare(hint.previousActiveWorkspacePosition, -1)
        compare(hint.workspaceTransitionRevision, 0)
    }

    function test_build_hint_tracks_previous_workspace_position() {
        const originalActiveWorkspace = Services.WindowHintService._activeWorkspace
        const originalActiveWorkspacePosition = Services.WindowHintService._activeWorkspacePosition
        const originalWorkspaceWindows = Services.WindowHintService._workspaceWindows
        const originalWorkspaceSummaries = Services.WindowHintService._workspaceSummaries

        Services.WindowHintService._revision = 0
        Services.WindowHintService._workspaceTransitionRevision = 0
        Services.WindowHintService._lastActiveWorkspacePosition = 1
        Services.WindowHintService._activeWorkspace = function() { return { wsId: "ws-2", idx: 3, name: "Workspace 3" } }
        Services.WindowHintService._activeWorkspacePosition = function() { return 2 }
        Services.WindowHintService._workspaceWindows = function() { return [] }
        Services.WindowHintService._workspaceSummaries = function() { return [] }

        try {
            const hint = Services.WindowHintService._buildHint(true)
            compare(hint.previousActiveWorkspacePosition, 1)
            compare(hint.activeWorkspacePosition, 2)
            compare(hint.workspaceTransitionRevision, 1)
        } finally {
            Services.WindowHintService._activeWorkspace = originalActiveWorkspace
            Services.WindowHintService._activeWorkspacePosition = originalActiveWorkspacePosition
            Services.WindowHintService._workspaceWindows = originalWorkspaceWindows
            Services.WindowHintService._workspaceSummaries = originalWorkspaceSummaries
        }
    }
}
```

- [ ] **Step 2: Run the QML tests to verify they fail**

Run: `qmltestrunner -input tests/qml/tst_workspace_hint.qml`

Expected: FAIL because `_emptyHint()` does not expose `previousActiveWorkspacePosition` or `workspaceTransitionRevision` yet.

- [ ] **Step 3: Add minimal transition metadata in the service**

Modify `services/WindowHintService.qml` to track the last active workspace position and include transition metadata in both empty and populated hints.

```qml
property int _lastActiveWorkspacePosition: -1
property int _workspaceTransitionRevision: 0

function _emptyHint() {
    return {
        visible: false,
        revision: root._revision,
        workspaceTransitionRevision: root._workspaceTransitionRevision,
        previousActiveWorkspacePosition: root._lastActiveWorkspacePosition,
        workspaceId: "",
        workspaceIndex: -1,
        activeWorkspacePosition: -1,
        currentWindowTitle: "",
        currentWindowAppId: "",
        currentWindowIcon: "",
        currentIndex: -1,
        windows: [],
        workspaces: [],
        previousWindow: root._emptyWindow(),
        nextWindow: root._emptyWindow()
    }
}
```

Update `_buildHint(visible)` with the current and previous positions:

```qml
const activePosition = root._activeWorkspacePosition()
const previousActivePosition = root._lastActiveWorkspacePosition

if (previousActivePosition !== activePosition)
    root._workspaceTransitionRevision += 1

root._lastActiveWorkspacePosition = activePosition

return {
    visible: !!visible,
    revision: nextRevision,
    workspaceTransitionRevision: root._workspaceTransitionRevision,
    previousActiveWorkspacePosition: previousActivePosition,
    workspaceId: workspace.wsId,
    workspaceIndex: workspace.idx,
    activeWorkspacePosition: activePosition,
    currentWindowTitle: currentWindow.title || workspace.name || ("Workspace " + workspace.idx),
    currentWindowAppId: currentWindow.appId,
    currentWindowIcon: currentWindow.icon,
    currentIndex: currentIndex,
    windows: windows,
    workspaces: root._workspaceSummaries(),
    previousWindow: root._windowAt(windows, currentIndex - 1),
    nextWindow: root._windowAt(windows, currentIndex + 1)
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `qmltestrunner -input tests/qml/tst_workspace_hint.qml`

Expected: PASS for `WorkspaceHintViewportModel` and `WindowHintServiceTransitions`.

- [ ] **Step 5: Commit**

```bash
git add services/WindowHintService.qml tests/qml/tst_workspace_hint.qml
git commit -m "feat(workspace-hint): track workspace transition metadata"
```

### Task 3: Add A Testable Viewport State Owner And Wire The Window To It

**Files:**
- Create: `modules/workspace-hint/WorkspaceHintViewportState.qml`
- Modify: `modules/workspace-hint/WorkspaceHintWindow.qml`
- Modify: `tests/qml/tst_workspace_hint.qml`
- Reference: `modules/workspace-hint/WorkspaceHintViewportModel.js`

- [ ] **Step 1: Add the failing viewport-state tests**

Extend `tests/qml/tst_workspace_hint.qml` with a harness that instantiates a non-visual `WorkspaceHintViewportState.qml` object and asserts queue decomposition, target stepping, and edge bounce state.

```qml
import "../../modules/workspace-hint" as WorkspaceHint

TestCase {
    name: "WorkspaceHintViewportState"

    Component {
        id: viewportStateComponent
        WorkspaceHint.WorkspaceHintViewportState {}
    }

    function test_state_breaks_multi_step_switch_into_queue() {
        const state = createTemporaryObject(viewportStateComponent, this)
        verify(state !== null)

        state.enqueueWorkspaceTransition(1, 3)
        compare(JSON.stringify(state.pendingWorkspaceSteps), JSON.stringify([2, 3]))
    }

    function test_state_advances_one_step_at_a_time() {
        const state = createTemporaryObject(viewportStateComponent, this)
        verify(state !== null)

        state.visualFocusPosition = 1
        state.enqueueWorkspaceTransition(1, 3)
        state.advancePendingWorkspaceStep()
        compare(state.targetWorkspacePosition, 2)
        compare(JSON.stringify(state.pendingWorkspaceSteps), JSON.stringify([3]))
    }

    function test_state_exposes_boundary_bounce_target() {
        const state = createTemporaryObject(viewportStateComponent, this)
        verify(state !== null)

        compare(state.edgeBounceTargetForTest(0, -1), -0.18)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `qmltestrunner -input tests/qml/tst_workspace_hint.qml`

Expected: FAIL because `WorkspaceHintViewportState.qml` does not exist yet.

- [ ] **Step 3: Create the viewport state owner and wire the window to it**

Create `modules/workspace-hint/WorkspaceHintViewportState.qml` as a small `QtObject` with queue and bounce helpers, then consume it from `WorkspaceHintWindow.qml`.

Create the state file with this shape:

```qml
import QtQuick
import "WorkspaceHintViewportModel.js" as ViewportModel

QtObject {
    id: root

    property real visualFocusPosition: 0
    property int settledWorkspacePosition: 0
    property int targetWorkspacePosition: 0
    property var pendingWorkspaceSteps: []

    function enqueueWorkspaceTransition(fromPosition, toPosition) {
        pendingWorkspaceSteps = pendingWorkspaceSteps.concat(ViewportModel.buildStepQueue(fromPosition, toPosition))
    }

    function advancePendingWorkspaceStep() {
        if (pendingWorkspaceSteps.length === 0)
            return

        const nextSteps = pendingWorkspaceSteps.slice()
        targetWorkspacePosition = nextSteps.shift()
        pendingWorkspaceSteps = nextSteps
        visualFocusPosition = targetWorkspacePosition
        settledWorkspacePosition = targetWorkspacePosition
    }

    function edgeBounceTargetForTest(edgePosition, direction) {
        return ViewportModel.boundaryBounceTarget(edgePosition, direction, 0.18)
    }

    function settleEdgeBounce(legalPosition) {
        visualFocusPosition = legalPosition
        targetWorkspacePosition = legalPosition
        settledWorkspacePosition = legalPosition
    }
}
```

Then add the state owner in `modules/workspace-hint/WorkspaceHintWindow.qml` and bind the viewport to it:

```qml
property var testHintData: null
property bool testHintHeld: false
readonly property var _hintData: testHintData !== null ? testHintData : Services.WindowHintService.activeHint
readonly property bool _hintActive: testHintData !== null ? testHintHeld : Services.WindowHintService.hintVisible
readonly property int renderedCapsuleCount: capsuleRepeater.count

WorkspaceHintViewportState {
    id: viewportState
}
```

Initialize those three state fields when the hint first becomes visible, then update them through `workspaceTransitionRevision` handling instead of binding them permanently to the real active position.

Replace the three explicit capsules with a viewport repeater:

```qml
// Keep all workspace capsules alive inside one fixed camera viewport.
Item {
    id: viewport
    anchors.horizontalCenter: parent.horizontalCenter
    y: Services.BarLayoutService.barHeight + 16
    width: 420
    height: 240
    clip: true

    Repeater {
        id: capsuleRepeater
        model: hintWindow._hintData.workspaces || []

        // Render one real workspace capsule in the scrolling viewport.
        WorkspaceHintCapsule {
            required property var modelData
            required property int index

            workspacePosition: index
            workspaceIndex: modelData.workspaceIndex
            relativeOffset: ViewportModel.relativeOffset(index, viewportState.visualFocusPosition)
            focusProgress: Math.max(0, 1 - Math.min(1, Math.abs(relativeOffset)))
            cameraDistance: Math.abs(relativeOffset)
            icons: modelData.icons || []
            windows: index === hintWindow._hintData.activeWorkspacePosition ? (hintWindow._hintData.windows || []) : []
            currentWindowTitle: hintWindow._hintData.currentWindowTitle
            currentWindowIcon: hintWindow._hintData.currentWindowIcon
        }
    }
}
```

Also add a `Connections` block keyed by `workspaceTransitionRevision` so each active workspace change appends single-step transitions through `viewportState.enqueueWorkspaceTransition()` rather than swapping immediately.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `qmltestrunner -input tests/qml/tst_workspace_hint.qml`

Expected: PASS for the new `WorkspaceHintViewportState` tests, even though capsule visuals are still basic.

- [ ] **Step 5: Commit**

```bash
git add modules/workspace-hint/WorkspaceHintViewportState.qml modules/workspace-hint/WorkspaceHintWindow.qml tests/qml/tst_workspace_hint.qml
git commit -m "feat(workspace-hint): add queue-driven viewport"
```

### Task 4: Convert WorkspaceHintCapsule To Continuous Focus Morphing

**Files:**
- Modify: `modules/workspace-hint/WorkspaceHintCapsule.qml`
- Modify: `tests/qml/tst_workspace_hint.qml`
- Reference: `services/Motion.qml`
- Reference: `modules/workspace-hint/WorkspaceHintViewportModel.js`

- [ ] **Step 1: Add the failing capsule morph tests**

Extend `tests/qml/tst_workspace_hint.qml` with a capsule-only harness that checks width, opacity, and active-content handoff from `focusProgress` and `relativeOffset`.

```qml
TestCase {
    name: "WorkspaceHintCapsuleMorph"

    Component {
        id: capsuleComponent
        WorkspaceHint.WorkspaceHintCapsule {
            workspaceIndex: 2
            icons: []
            windows: [{ title: "Focused App", icon: "", isFocused: true }]
            currentWindowTitle: "Focused App"
            currentWindowIcon: ""
        }
    }

    function test_capsule_focus_progress_controls_width() {
        const capsule = createTemporaryObject(capsuleComponent, this, {
            "relativeOffset": 0,
            "focusProgress": 1,
            "cameraDistance": 0
        })
        const focusedWidth = capsule.width

        capsule.focusProgress = 0
        capsule.relativeOffset = 1

        tryVerify(function() {
            return capsule.width < focusedWidth
        }, 500)
    }

    function test_capsule_fades_distant_workspaces() {
        const capsule = createTemporaryObject(capsuleComponent, this, {
            "relativeOffset": 2,
            "focusProgress": 0,
            "cameraDistance": 2
        })
        verify(capsule.opacity < 1)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `qmltestrunner -input tests/qml/tst_workspace_hint.qml`

Expected: FAIL because `WorkspaceHintCapsule.qml` still uses `active`, `expanded`, and `baseY` instead of `relativeOffset`, `focusProgress`, and `cameraDistance`.

- [ ] **Step 3: Rewrite the capsule inputs and derived geometry minimally**

Modify `modules/workspace-hint/WorkspaceHintCapsule.qml` to derive visual state from continuous focus values.

Add the helper import at the top of the file:

```qml
import "WorkspaceHintViewportModel.js" as ViewportModel
```

Add or replace the key properties like this:

```qml
property int workspacePosition: -1
property real relativeOffset: 0
property real focusProgress: 0
property real cameraDistance: Math.abs(relativeOffset)
readonly property bool isFocusedVisual: focusProgress >= 0.999
readonly property real capsulePitch: 72
readonly property real _collapsedWidth: Math.max(neighborContent.implicitWidth + 28, 72)
readonly property real _focusedWidth: Math.max(activeContent.implicitWidth + 20, _collapsedSize)
readonly property real _focusWidth: _collapsedWidth + ((_focusedWidth - _collapsedWidth) * focusProgress)
readonly property real _focusOpacity: ViewportModel.opacityForDistance(cameraDistance, capsulePitch, capsulePitch * 3)
```

Drive geometry from those values:

```qml
x: 0
y: ((relativeOffset * capsulePitch) + (Math.sign(relativeOffset) * Math.min(10, Math.abs(relativeOffset) * 4)))
width: _focusWidth
height: _collapsedSize + ((_expandedHeight - _collapsedSize) * focusProgress)
opacity: _focusOpacity
```

Replace the hard active toggle in content visibility with a crossfade:

```qml
Row {
    id: activeContent
    anchors.centerIn: contentMask
    opacity: focusProgress
    visible: opacity > 0
}

Row {
    id: neighborContent
    anchors.centerIn: contentMask
    opacity: 1 - focusProgress
    visible: opacity > 0
}
```

Keep `Behavior` blocks on width, y, opacity, surface color, and border color so the glass-liquid motion contract still holds.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `qmltestrunner -input tests/qml/tst_workspace_hint.qml`

Expected: PASS for `WorkspaceHintCapsuleMorph` and earlier tests.

- [ ] **Step 5: Commit**

```bash
git add modules/workspace-hint/WorkspaceHintCapsule.qml tests/qml/tst_workspace_hint.qml
git commit -m "feat(workspace-hint): add capsule coverflow morphing"
```

### Task 5: Finish Release Handling And Regression Coverage

**Files:**
- Modify: `modules/workspace-hint/WorkspaceHintWindow.qml`
- Modify: `tests/qml/tst_workspace_hint.qml`
- Check: `services/WindowHintTriggerService.qml`

- [ ] **Step 1: Write the failing release behavior check**

Record the current release failure in the running shell because the hide timer lives inside a `PanelWindow` delegate and is best verified behaviorally.

1. Hold `mod` to show the workspace hint.
2. Switch workspaces once so the viewport is visibly active.
3. Release `mod`.
4. Confirm the current failure if present: the viewport hides too early, clears data before the fade completes, or still follows the old three-slot exit staging.

- [ ] **Step 2: Verify the legacy release machinery still exists before replacing it**

Read `modules/workspace-hint/WorkspaceHintWindow.qml` and confirm the old staged-slot release machinery is still present before removing it.

Expected to find state and timers shaped like this:

```qml
property bool _stageTop: false
property bool _stageMiddle: false
property bool _stageBottom: false

Timer { id: _exitBottomTimer }
Timer { id: _exitMiddleTimer }
Timer { id: _exitTopTimer }
```

Expected: the file still contains the old three-slot exit choreography and needs to be collapsed into one viewport-level release path.

- [ ] **Step 3: Complete release behavior around the new viewport**

Finish `modules/workspace-hint/WorkspaceHintWindow.qml` so release keeps the viewport visible until the hide timer completes and no longer references the old three-slot staging.

Keep the rebound settle helper on `WorkspaceHintViewportState.qml` if it was not added in Task 3:

```qml
function settleEdgeBounce(legalPosition) {
    visualFocusPosition = legalPosition
    targetWorkspacePosition = legalPosition
    settledWorkspacePosition = legalPosition
}
```

Update release handling so it stays data-safe and viewport-oriented:

```qml
on_HintActiveChanged: {
    if (_hintActive) {
        _hideTimer.stop()
        _windowVisible = true
        return
    }

    _hideTimer.restart()
}
```

Also remove `_stageTop`, `_stageMiddle`, `_stageBottom`, and the old enter/exit capsule timers once the repeater viewport owns the motion.

If `WindowHintTriggerService.qml` needs a tiny adjustment, keep it limited to preserving the current hold lifecycle and do not move queue logic into the trigger service.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `qmltestrunner -input tests/qml/tst_workspace_hint.qml`

Expected: PASS for all workspace hint QML tests.

- [ ] **Step 5: Run a final regression sweep**

Run: `qmltestrunner -input tests/qml/tst_media_lyrics.qml`

Expected: PASS, proving the new QML test file did not disturb the existing test environment.

Manual verification loop in the running shell:

1. Hold `mod` on workspace 2.
2. Switch downward to workspace 3.
3. Expected: every capsule shifts upward, workspace 2 shrinks out of focus, workspace 3 expands into focus, and workspace 4 rises in from below.
4. Keep holding `mod` and switch quickly from workspace 2 to workspace 4.
5. Expected: the viewport visually steps through workspace 3 instead of teleporting.
6. At the first and last workspaces, attempt one more move outward.
7. Expected: small rebound only, no fake capsule and no real workspace change.
8. While still holding `mod` with 4 or more workspaces available, confirm every real workspace capsule exists in the vertical strip and only far-away capsules fade by distance.

- [ ] **Step 6: Commit**

```bash
git add modules/workspace-hint/WorkspaceHintWindow.qml tests/qml/tst_workspace_hint.qml
git commit -m "feat(workspace-hint): finish coverflow lifecycle"
```
