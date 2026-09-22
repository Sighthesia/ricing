# Lock Authentication Surface Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the lock screen's floating, fading password card with a compact authentication surface centered on a single password input slot.

**Architecture:** Keep `LockSurface.qml` as the owner of authentication layout, keyboard focus, and lock lifecycle. Remove the visual card semantics from the outer authentication container, retain a small themed input slot as the primary surface, and animate the authentication content with a short positional reveal instead of a full-card opacity reveal. Background wave animation, PAM context, and release ownership remain unchanged.

**Tech Stack:** QtQuick/QML, Quickshell Wayland session lock, existing `LazerTheme` and `MotionTokens`, Qt6 `qmllint`, Qt6 `qmltestrunner`.

## Global Constraints

- Do not change password input, keyboard focus, PAM verification, failure handling, unlock timing, background wave, screenshot, wallpaper reveal, or multi-screen ownership behavior.
- Do not add a second animation timing system; use `MotionTokens` and `MotionTokens.reducedMotion`.
- The outer authentication area must not render as an independent full card or complete border.
- The password input slot remains the main visible surface and may retain a restrained internal radius.
- Use `Services.SettingsService.effectiveColorScheme` for light/dark selection and preserve readable fallback colors.
- Add the required descriptive comment immediately before every major new or changed QML element declaration.
- Run the relevant QML test and `qmllint` after every QML change.
- Commit each functional change with a conventional commit message and do not include unrelated existing worktree changes.

---

### Task 1: Lock Authentication Surface Geometry

**Files:**
- Modify: `modules/lock/LockSurface.qml:145-265`
- Test: `tests/qml/tst_lock_surface_logic.qml`

**Interfaces:**
- Consumes the existing `root.lockContext`, `root.lightScheme`, `LazerTheme`, `MotionTokens`, and `SurfaceLogic` values.
- Produces the same keyboard and `LockContext` behavior while changing only the authentication area's visual hierarchy.

- [ ] **Step 1: Record the existing behavioral baseline**

Run:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_lock_surface_logic.qml -o -,txt
```

Expected: `Totals: 26 passed, 0 failed` or the current passing total if the test file has changed independently.

- [ ] **Step 2: Replace the outer card role with a transparent layout host**

In `LockSurface.qml`, retain the centered authentication item's width and stable height contract, but remove its complete card appearance:

```qml
// Position authentication content without introducing a floating dialog frame.
Item {
    id: authSurface
    anchors.centerIn: parent
    anchors.verticalCenterOffset: authRevealOffset
    width: Math.min(parent.width * 0.82, 420)
    height: Math.min(parent.height * 0.48, 260)
    z: 3
    opacity: authRevealOpacity
}
```

The host must not have a `color`, `border.color`, or `border.width` binding. Preserve the host's stable geometry so content changes do not affect the lock surface layout.

- [ ] **Step 3: Add reduced-motion-aware authentication reveal values**

Add root-level readonly values near the existing lock-surface properties. They must use the existing wave progress as the reveal completion signal and settle immediately when reduced motion is active:

```qml
readonly property real authRevealProgress: reducedMotion
        ? 1 : Math.max(0, Math.min(1, backdrop.maskProgress))
readonly property real authRevealOffset: (1 - authRevealProgress) * 10
readonly property real authRevealOpacity: 0.94 + authRevealProgress * 0.06
```

Do not introduce a new timer or animation. This keeps authentication reveal synchronized with the already existing backdrop reveal and avoids a second lifecycle owner.

- [ ] **Step 4: Make the input slot the primary visual surface**

Keep `maskSlot` as the only substantial rectangle in the authentication area. Preserve its fixed `44px` height, light/dark readability, `settingsControlRadius`, masked text, empty-state text, and existing `lockContext` bindings.

Use the existing pink accent as a short indicator rather than a full-width card edge:

```qml
// Mark the authentication state without outlining a floating card.
Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: maskSlot.top
    anchors.bottomMargin: 10
    width: 44
    height: 3
    color: Lazer.LazerTheme.osuPink
}
```

Place the indicator outside the input slot's hit area and keep it static in shape. It must not be a new input catcher.

- [ ] **Step 5: Rebalance the content hierarchy without changing state bindings**

Keep the existing `PASSWORD`, status, and instruction texts, but position them around the input slot so the slot reads first. The `Column` may continue to own the layout; reduce the visual prominence of the instruction line and keep the status line reserved in the existing stable content area where possible.

Do not alter these expressions:

```qml
SurfaceLogic.maskedPassword(root.lockContext ? root.lockContext.currentText : "")
SurfaceLogic.authStatus(...)
root.lockContext.submit()
root.lockContext.currentText
```

- [ ] **Step 6: Run static and behavioral verification**

Run:

```bash
/usr/lib/qt6/bin/qmllint modules/lock/LockSurface.qml
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_lock_surface_logic.qml -o -,txt
```

Expected: no `qmllint` warnings and all lock surface logic tests pass.

- [ ] **Step 7: Commit the surface redesign**

```bash
git add modules/lock/LockSurface.qml
git commit -m "refactor(lock): simplify authentication surface"
```

### Task 2: Verify Visual and Lifecycle Regressions

**Files:**
- Modify: none unless verification exposes a regression
- Test: `tests/qml/tst_lock_surface_logic.qml`, `tests/qml/tst_lock_backdrop.qml`, `tests/qml/tst_lock_controller_logic.qml`

**Interfaces:**
- Verifies the unchanged `LockSurfaceLogic`, `LockBackdrop`, and `LockController` contracts after the visual-only edit.
- Produces a final validation record for the approved design.

- [ ] **Step 1: Run the complete lock logic test set**

```bash
for test_file in \
  tests/qml/tst_lock_surface_logic.qml \
  tests/qml/tst_lock_backdrop.qml \
  tests/qml/tst_lock_controller_logic.qml; do
  QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
    -input "$test_file" -o -,txt || exit 1
done
```

Expected: every test reports zero failures.

- [ ] **Step 2: Run the final QML lint check**

```bash
/usr/lib/qt6/bin/qmllint \
  modules/lock/LockSurface.qml \
  modules/lock/LockBackdrop.qml
```

Expected: no warnings or errors introduced by the redesign.

- [ ] **Step 3: Inspect the final diff and worktree scope**

```bash
git diff --check
git diff -- modules/lock/LockSurface.qml
git status --short
```

Confirm the implementation commit contains only the intended lock surface file and that unrelated existing worktree files remain untouched.

- [ ] **Step 4: Commit any narrowly scoped verification fix**

If verification requires a source correction, rerun the affected tests and commit only the correction:

```bash
git add modules/lock/LockSurface.qml
git commit -m "fix(lock): preserve authentication surface behavior"
```
