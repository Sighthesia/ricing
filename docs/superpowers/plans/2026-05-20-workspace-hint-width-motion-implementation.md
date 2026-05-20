# Workspace Hint Width Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the focused workspace capsule width feel shell-first on enter and content-first on exit without changing the current y-axis motion chain.

**Architecture:** Keep the existing viewport queue, y-position spring, and release timing intact. Add two pure width-motion helper curves in `WorkspaceHintViewportModel.js`, then consume them in `WorkspaceHintCapsule.qml` to separate shell expansion from title-row reveal using a clipped reveal container.

**Tech Stack:** QML, QtQuick, Quickshell, QtTest `qmltestrunner`, `qmllint`

---

## File Map

- Modify: `tests/qml/tst_workspace_hint.qml`
  - Add failing pure-function tests for shell progress, content reveal progress, and the intended ordering between them.
- Modify: `modules/workspace-hint/WorkspaceHintViewportModel.js`
  - Add pure helper math for shell-width progress and content-reveal progress.
- Modify: `modules/workspace-hint/WorkspaceHintCapsule.qml`
  - Split focused width behavior into shell width vs title reveal width.
  - Keep y-axis motion and release timing behavior unchanged.
- Optional modify: `modules/workspace-hint/WorkspaceHintWindow.qml`
  - Only if the capsule needs a small prop wiring change; otherwise leave untouched.

### Task 1: Add Width-Motion Regression Tests

**Files:**
- Modify: `tests/qml/tst_workspace_hint.qml`
- Test: `tests/qml/tst_workspace_hint.qml`

- [ ] **Step 1: Write the failing tests**

Add these tests inside the `WorkspaceHint` `TestCase`:

```qml
        function test_shellWidthProgress_clamps_to_zero() {
            compare(Model.shellWidthProgressForOffset(2), 0)
        }

        function test_shellWidthProgress_clamps_to_one() {
            compare(Model.shellWidthProgressForOffset(0), 1)
        }

        function test_contentRevealProgress_clamps_to_zero() {
            compare(Model.contentRevealProgressForOffset(2), 0)
        }

        function test_contentRevealProgress_clamps_to_one() {
            compare(Model.contentRevealProgressForOffset(0), 1)
        }

        function test_shellWidthProgress_leads_contentReveal_mid_transition() {
            verify(Model.shellWidthProgressForOffset(0.4)
                > Model.contentRevealProgressForOffset(0.4))
        }

        function test_contentRevealProgress_retracts_before_shell_mid_exit() {
            verify(Model.contentRevealProgressForOffset(0.7)
                < Model.shellWidthProgressForOffset(0.7))
        }
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_workspace_hint.qml -o -,txt -v1
```

Expected:

- FAIL with errors stating `shellWidthProgressForOffset` and `contentRevealProgressForOffset` are not functions.

- [ ] **Step 3: Keep existing tests intact**

Do not remove or rename these existing regression tests while adding the new ones:

```qml
        function test_useFocusedWidthForCapsule_keeps_outgoing_focus_geometry() {
            compare(Model.useFocusedWidthForCapsule(false, true, 0.4), true)
        }

        function test_shouldExpandCapsule_collapses_after_release() {
            compare(Model.shouldExpandCapsule(true, false), false)
        }
```

- [ ] **Step 4: Commit**

Do not commit yet unless the user explicitly asks for a commit.

### Task 2: Implement Pure Width-Motion Helper Curves

**Files:**
- Modify: `modules/workspace-hint/WorkspaceHintViewportModel.js`
- Test: `tests/qml/tst_workspace_hint.qml`

- [ ] **Step 1: Write the minimal helper functions**

Add these functions below `focusProgressForOffset(relativeOffset)`:

```javascript
function shellWidthProgressForOffset(relativeOffset) {
    var focus = focusProgressForOffset(relativeOffset)
    var boosted = focus <= 0 ? 0 : Math.min(1, focus / 0.72)
    return Math.max(0, Math.min(1, boosted))
}

function contentRevealProgressForOffset(relativeOffset) {
    var focus = focusProgressForOffset(relativeOffset)
    var delayed = (focus - 0.22) / 0.78
    return Math.max(0, Math.min(1, delayed))
}
```

Why this shape:

- shell progress reaches readable width earlier
- content reveal waits longer and retracts earlier
- both stay pure and clamp to `0..1`

- [ ] **Step 2: Keep the existing helper API unchanged**

Do not rename or remove these functions:

```javascript
function focusProgressForOffset(relativeOffset) {
    return Math.max(0, 1 - Math.abs(relativeOffset))
}

function useFocusedWidthForCapsule(active, outgoingWithContent, focusProgress) {
    return !!active || (!!outgoingWithContent && focusProgress > 0)
}

function shouldExpandCapsule(staggerVisible, hintActive) {
    return !!staggerVisible && !!hintActive
}
```

- [ ] **Step 3: Run tests to verify the new helper math passes**

Run:

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_workspace_hint.qml -o -,txt -v1
```

Expected:

- PASS for the new shell/content helper tests
- PASS for the existing handoff and release tests

- [ ] **Step 4: Commit**

Do not commit yet unless the user explicitly asks for a commit.

### Task 3: Split Capsule Shell Width From Title Reveal

**Files:**
- Modify: `modules/workspace-hint/WorkspaceHintCapsule.qml`
- Test: `tests/qml/tst_workspace_hint.qml`

- [ ] **Step 1: Add derived width-motion properties**

In the root `Item`, add these readonly properties near the existing width properties:

```qml
    readonly property real _shellWidthProgress:
        ViewportModel.shellWidthProgressForOffset(root.relativeOffset)
    readonly property real _contentRevealProgress:
        ViewportModel.contentRevealProgressForOffset(root.relativeOffset)
```

- [ ] **Step 2: Change shell width to use shell progress**

Replace the current focused width interpolation:

```qml
    readonly property real _focusWidth: ViewportModel.focusWidth(
        _collapsedWidth, _focusedWidth, root.focusProgress)
```

With:

```qml
    readonly property real _focusWidth: ViewportModel.focusWidth(
        _collapsedWidth, _focusedWidth, root._shellWidthProgress)
```

Do not change:

```qml
    y: root.expanded ? root._animatedY : 0
```

or:

```qml
    Behavior on y {
        SpringAnimation {
            spring: Services.Motion.hover.spring
            damping: Services.Motion.hover.damping
            mass: Services.Motion.hover.mass
            epsilon: Services.Motion.hover.epsilon
        }
    }
```

- [ ] **Step 3: Keep height exit tied to the existing focus metric**

Leave the height interpolation on the existing `root.focusProgress` path:

```qml
    height: root.expanded
        ? (_collapsedSize + ((_expandedHeight - _collapsedSize) * root.focusProgress))
        : root._collapsedSize
```

This preserves the current vertical feel while only softening width behavior.

- [ ] **Step 4: Add a clipped title reveal container**

Refactor the active-content row so the workspace number stays stable while the title region is separately revealed.

Target structure:

```qml
            Row {
                id: activeContent
                anchors.centerIn: contentMask
                spacing: 8
                opacity: root.focusProgress

                Text {
                    text: String(root.workspaceIndex)
                    font.pixelSize: 12
                    font.bold: true
                    color: Services.Color.mOnSurface
                }

                Item {
                    id: titleReveal
                    width: windowTitleRow.implicitWidth * root._contentRevealProgress
                    height: Math.max(windowTitleRow.implicitHeight, emptyWorkspaceLabel.implicitHeight)
                    clip: true

                    Behavior on width {
                        NumberAnimation {
                            duration: Services.Motion.number.contentDuration
                            easing.type: Services.Motion.number.contentEasing
                        }
                    }

                    Row {
                        id: windowTitleRow
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: root.windows
                            Rectangle {
                                required property var modelData
                                required property int index
                                width: Math.max(winCardRow.implicitWidth + 14, 100)
                                height: 28
                                radius: 8
                                color: modelData.isFocused
                                    ? Qt.rgba(
                                        Services.Color.mPrimary.r,
                                        Services.Color.mPrimary.g,
                                        Services.Color.mPrimary.b,
                                        0.18
                                    )
                                    : Qt.rgba(
                                        Services.Color.mSurfaceVariant.r,
                                        Services.Color.mSurfaceVariant.g,
                                        Services.Color.mSurfaceVariant.b,
                                        0.35
                                    )
                                Row {
                                    id: winCardRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    // keep existing icon, focus dot, and text contents unchanged
                                }
                            }
                        }

                        Text {
                            id: emptyWorkspaceLabel
                            visible: root.expanded && (root.windows || []).length === 0
                            text: "空工作区"
                            font.pixelSize: 12
                            color: Services.Color.mOnSurfaceVariant
                            opacity: 0.5
                        }
                    }
                }
            }
```

Notes:

- keep the existing card internals unchanged unless needed for anchoring
- do not move the workspace number inside the clipped reveal area
- keep comments before major QML declarations in English

- [ ] **Step 5: Keep neighbor rendering unchanged**

Do not alter this section except for any required indentation cleanup:

```qml
            Row {
                id: neighborContent
                anchors.centerIn: contentMask
                spacing: 6
                opacity: 1 - root.focusProgress
                ...
            }
```

- [ ] **Step 6: Run static checks**

Run:

```bash
qmllint modules/workspace-hint/WorkspaceHintCapsule.qml modules/workspace-hint/WorkspaceHintWindow.qml modules/workspace-hint/WorkspaceHintViewportState.qml
```

Expected:

- no output

- [ ] **Step 7: Commit**

Do not commit yet unless the user explicitly asks for a commit.

### Task 4: Full Regression Verification

**Files:**
- Test: `tests/qml/tst_workspace_hint.qml`
- Verify: `modules/workspace-hint/WorkspaceHintViewportModel.js`
- Verify: `modules/workspace-hint/WorkspaceHintCapsule.qml`
- Verify: `modules/workspace-hint/WorkspaceHintWindow.qml`

- [ ] **Step 1: Run the full pure Qt suite**

Run:

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_workspace_hint.qml -o -,txt -v1
```

Expected:

- all tests pass
- no new failures in existing workspace hint tests

- [ ] **Step 2: Run QML static checks again**

Run:

```bash
qmllint modules/workspace-hint/WorkspaceHintWindow.qml modules/workspace-hint/WorkspaceHintCapsule.qml modules/workspace-hint/WorkspaceHintViewportState.qml
```

Expected:

- no output

- [ ] **Step 3: Manual behavior checklist**

Verify in the running shell:

- press `mod`: focused capsule shell appears before the title region feels fully open
- release `mod`: current y-axis exit still feels unchanged
- switch workspace once: incoming focus does not snap to full width immediately
- switch workspace once: outgoing focus title retracts before the shell fully collapses
- switch multiple workspaces: every step remains continuous

- [ ] **Step 4: Commit**

Do not commit yet unless the user explicitly asks for a commit.

## Spec Coverage Check

- Width entrance behavior: covered by Task 2 helper curves and Task 3 shell/content split
- Width exit behavior: covered by Task 2 helper curves and Task 3 clipped title reveal
- Outgoing handoff behavior: covered by keeping `useFocusedGeometry` and existing handoff tests intact in Tasks 1-3
- Title-row reveal timing: covered by Task 3 reveal container
- Preserve y-axis motion: enforced in Task 3 Step 2 and Task 3 Step 3
- Verification commands: covered in Task 4

## Placeholder Scan

- No `TODO` or `TBD` markers
- All file paths are explicit
- All verification commands are explicit
- The only optional file change is `WorkspaceHintWindow.qml`, and the plan says to leave it untouched unless wiring becomes necessary

## Type Consistency Check

- Helper names used consistently:
  - `shellWidthProgressForOffset(relativeOffset)`
  - `contentRevealProgressForOffset(relativeOffset)`
  - `useFocusedWidthForCapsule(active, outgoingWithContent, focusProgress)`
  - `shouldExpandCapsule(staggerVisible, hintActive)`
- Capsule property names used consistently:
  - `_shellWidthProgress`
  - `_contentRevealProgress`
  - `useFocusedGeometry`
