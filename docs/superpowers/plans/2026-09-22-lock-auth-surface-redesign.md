# Lock Authentication Surface Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the lock screen's floating password card with a time-led lock screen whose bottom lock button morphs in place into a password field on interaction.

**Architecture:** Keep `LockSurface.qml` as the owner of the clock, lock button, authentication mode, keyboard focus, and lock lifecycle. Reuse `RollingClockTime`, `OsuTextField`, `OsuTextCaret`, and the existing lock SVG. The default state shows only time/date and a lock button; the same bottom rounded rectangle morphs into the password field after a click or first key event. Background wave animation, PAM context, and release ownership remain unchanged.

**Tech Stack:** QtQuick/QML, Quickshell Wayland session lock, existing `LazerTheme` and `MotionTokens`, Qt6 `qmllint`, Qt6 `qmltestrunner`.

## Global Constraints

- Do not change password input, keyboard focus, PAM verification, failure handling, unlock timing, background wave, screenshot, wallpaper reveal, or multi-screen ownership behavior.
- Do not add a second animation timing system; use `MotionTokens` and `MotionTokens.reducedMotion`.
- Default state must show no password-related text, including title, placeholder text, operation hint, verification text, or error text.
- The bottom control is one complete rounded rectangle in both lock-button and input states.
- The empty password field uses a rounded rectangular placeholder thicker than the caret, not text.
- Time and date are visible above the control; hours/minutes reuse `RollingClockTime.qml`.
- Input editing must reuse `OsuTextField.qml` and `OsuTextCaret.qml`, including falling deletion ghosts.
- Use `Services.SettingsService.effectiveColorScheme` for light/dark selection and preserve readable fallback colors.
- Add the required descriptive comment immediately before every major new or changed QML element declaration.
- Run the relevant QML test and `qmllint` after every QML change.
- Commit each functional change with a conventional commit message and do not include unrelated existing worktree changes.

---

### Task 1: Lock Time And Authentication Surface

**Files:**
- Modify: `modules/lock/LockSurface.qml`
- Reuse: `modules/bar/widgets/RollingClockTime.qml`, `modules/lazerbar/OsuTextField.qml`, `modules/lazerbar/OsuTextCaret.qml`, `modules/lazerbar/icons/lock.svg`
- Test: `tests/qml/tst_lock_surface_logic.qml`

**Interfaces:**
- Consumes the existing `root.lockContext`, `root.lightScheme`, `LazerTheme`, `MotionTokens`, and `SurfaceLogic` values plus the reusable clock and text field components.
- Produces default clock/date/lock-button state, click/first-key activation, password editing feedback, and the same `LockContext` behavior.

- [ ] **Step 1: Record the existing behavioral baseline**

Run:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_lock_surface_logic.qml -o -,txt
```

Expected: `Totals: 26 passed, 0 failed` or the current passing total if the test file has changed independently.

- [ ] **Step 2: Add the default time/date composition**

Add a clock region in the upper-center area. Drive it with a one-second `Timer`, use `RollingClockTime` with the existing clock flip durations, and place a date `Text` below it. Do not add labels or password-related text.

```qml
// Keep the primary time readout above the interaction control.
Column {
    id: lockTime
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -parent.height * 0.18
    spacing: 8

    RollingClockTime {
        currentTime: root.now
        digitPixelSize: 48
        showSeconds: false
        digitColor: root.lightScheme ? "#211F24" : Lazer.LazerTheme.textPrimary
        separatorColor: digitColor
        hourTransitionDuration: Lazer.MotionTokens.clockHourFlip
        minuteTransitionDuration: Lazer.MotionTokens.clockMinuteFlip
        transitionEasing: Lazer.MotionTokens.clockFlipEasing
    }

    Text {
        text: Qt.formatDate(root.now, "yyyy.MM.dd")
        color: root.lightScheme ? "#5F5A66" : Lazer.LazerTheme.textMuted
        font.pixelSize: 16
    }
}
```

The time region is informational and must not receive pointer input.

- [ ] **Step 3: Add click/keyboard authentication mode**

Add a boolean `inputMode` and one `enterInputMode()` function. The function must be idempotent, force the reusable password field focus, and never alter PAM state. A `TapHandler` on the bottom control calls it. The existing keyboard handler must call it before processing any printable key, Backspace, or Enter event.

```qml
property bool inputMode: false

function enterInputMode() {
    if (!inputMode)
        inputMode = true
    passwordField.forceActiveFocus()
}
```

Do not create a second lifecycle owner for input. The same bottom surface remains mounted in both modes.

- [ ] **Step 4: Build the bottom lock button and in-place input morph**

Create one bottom-centered rounded rectangle with a stable height. In default mode it shows only `icons/lock.svg`; in input mode it expands in place and contains `OsuTextField`. Do not display any text labels or error/status messages.

Use a single surface with a width binding driven by `inputMode` and a `Behavior` using `MotionTokens.medium`; reduced motion must settle immediately. The password field must use `echoMode: TextInput.Password`, bind to `lockContext.currentText`, and submit through the existing `lockContext.submit()` path.

The empty-state placeholder is a rounded rectangle thicker than `OsuTextCaret`, for example `width: 12`, `height: 6`, `radius: 3`, and must be visible only when the password is empty and the field is focused.

The button and field share the same hit area. The SVG should be tinted from the current theme rather than assuming white.

- [ ] **Step 5: Reuse launcher editing feedback without changing auth bindings**

Use the existing `OsuTextField` so its `OsuTextCaret` and `textdiff.js` deletion ghosts are reused directly. Bind the field to the lock context through the current text-change path, suppressing only programmatic synchronization where needed. Keep all authentication behavior in `LockContext`.

Do not alter these expressions:

```qml
root.lockContext.submit()
root.lockContext.currentText
```

No `PASSWORD`, `Enter password`, `Type the password`, `Verifying...`, or error text may remain in the visual tree.

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

### Task 2: Verify Time, Input Mode, And Lifecycle Regressions

**Files:**
- Modify: none unless verification exposes a regression
- Test: `tests/qml/tst_lock_surface_logic.qml`, `tests/qml/tst_lock_backdrop.qml`, `tests/qml/tst_lock_controller_logic.qml`

**Interfaces:**
- Verifies clock/input-mode visual contracts plus unchanged `LockSurfaceLogic`, `LockBackdrop`, and `LockController` behavior.
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
