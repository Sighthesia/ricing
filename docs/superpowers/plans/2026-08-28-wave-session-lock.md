# Wave Session Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real Wayland session-lock surface to Afloat and reuse the existing sharp Wave reveal so locking visually grows over the live desktop snapshot into a full-screen password surface.

**Architecture:** Add a focused `modules/lock` module with one `WlSessionLock`, per-screen `WlSessionLockSurface` instances, a PAM context, and a snapshot-preparation state machine. Extract only the reusable four-layer Wave rendering into `WaveRevealLayers.qml`; keep launcher routing, masks, and opener focus ownership in the launcher implementation.

**Tech Stack:** Quickshell QML, QtQuick, `Quickshell.Wayland`, `Quickshell.Services.Pam`, QtTest/qmltestrunner, existing `LazerTheme` and `MotionTokens`.

## Global Constraints

- Use `WlSessionLock` / `WlSessionLockSurface`; a normal `PanelWindow` is not a lock screen.
- Do not expose an interactive ordinary overlay before the session lock is committed.
- Keep the existing 85% launcher Wave behavior unchanged.
- Use full `WlSessionLockSurface` dimensions for lock mode.
- Unlock only after the reverse animation completes.
- Use `MotionTokens` for durations/easing and gate animation with `MotionTokens.reducedMotion`.
- Keep large surfaces square/rectangular according to the osu!lazer sharp language.
- Do not modify unrelated existing worktree changes.
- Run Qt6 `qmltestrunner` for pure QML/JS tests; `qs -p` is only for behavior harnesses.

---

### Task 1: Extract Reusable Wave Layers

**Files:**
- Create: `modules/lazerbar/WaveRevealLayers.qml`
- Modify: `modules/lazerbar/WaveSurfaceHost.qml:130-152`
- Create: `tests/qml/tst_wave_reveal_layers.qml`

**Interfaces:**
- Consumes: `width`, `height`, `progress`, `palette`, and optional `fullscreen` from consumers.
- Produces: a visual-only item whose four `FullscreenWave` delegates follow the existing angles, palette order, offsets, clipping, and reduced-motion behavior.

- [ ] **Step 1: Write the failing test**

Create a QtTest fixture that mounts `WaveRevealLayers` at `800x600`, sets `progress` to `0` and `1`, and verifies four delegates, existing angles `13, -7, 4, -2`, `clip === true`, and final delegate progress/opacity.

```qml
import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

Item {
    width: 800
    height: 600

    Lazer.WaveRevealLayers {
        id: layers
        anchors.fill: parent
        palette: ({ light4: "#111111", light3: "#222222", dark4: "#333333", dark3: "#444444" })
    }

    TestCase {
        name: "WaveRevealLayers"

        function test_fourLayersAndAngles() {
            compare(layers.waveRepeater.count, 4)
            compare(layers.waveRepeater.itemAt(0).angle, 13)
            compare(layers.waveRepeater.itemAt(1).angle, -7)
            compare(layers.waveRepeater.itemAt(2).angle, 4)
            compare(layers.waveRepeater.itemAt(3).angle, -2)
            verify(layers.waveRepeater.itemAt(0).clip)
        }

        function test_progressReachesFinalGeometry() {
            layers.progress = 0
            compare(layers.waveRepeater.itemAt(0).progress, 0)
            layers.progress = 1
            compare(layers.waveRepeater.itemAt(0).progress, 1)
            compare(layers.waveRepeater.itemAt(0).opacity, 1)
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wave_reveal_layers.qml -o -,txt`

Expected: FAIL because `WaveRevealLayers.qml` does not exist.

- [ ] **Step 3: Implement the reusable layer**

Move the four-layer `Repeater` from `WaveSurfaceHost.qml` into `WaveRevealLayers.qml`. Expose `property real progress`, `property var palette`, `property alias waveRepeater: waveRepeater`, and use `anchors.fill: parent`. Preserve `Logic.waveAngle(index)`, the existing palette selection, offsets, and clipping. Replace the old inline repeater in `WaveSurfaceHost.qml` with the new component.

- [ ] **Step 4: Run focused tests**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wave_reveal_layers.qml -o -,txt`

Expected: PASS with no WARN/ERROR output.

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wave_surface_host.qml -o -,txt`

Expected: PASS; existing launcher geometry and animation contracts remain unchanged.

- [ ] **Step 5: Commit**

```bash
git add modules/lazerbar/WaveRevealLayers.qml modules/lazerbar/WaveSurfaceHost.qml tests/qml/tst_wave_reveal_layers.qml
git commit -m "refactor(lazerbar): extract reusable wave reveal layers"
```

### Task 2: Add Lock State and PAM Context

**Files:**
- Create: `modules/lock/LockContext.qml`
- Create: `modules/lock/LockLogic.js`
- Create: `tests/qml/tst_lock_logic.qml`

**Interfaces:**
- Consumes: password text and injected PAM-like result events in logic tests.
- Produces: `LockContext` with `currentText`, `unlockInProgress`, `showFailure`, `errorMessage`, `unlocked()` and `failed()`; `LockLogic` functions `canStart`, `nextState`, and `shouldReleaseLock`.

- [ ] **Step 1: Write failing pure logic tests**

Test `canStart(false, false) === true`, duplicate lock rejection, `nextState("locked", "auth-success") === "exiting"`, `shouldReleaseLock("exiting", false) === false`, and `shouldReleaseLock("exiting", true) === true`.

- [ ] **Step 2: Run the tests to verify failure**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lock_logic.qml -o -,txt`

Expected: FAIL because `LockLogic.js` does not exist.

- [ ] **Step 3: Implement pure state helpers**

Implement finite string states `idle`, `preparing`, `locked`, and `exiting`. `canStart(isLocked, isPreparing)` returns false for either true flag. `nextState` maps `prepare-ready` to `locked`, `auth-success` to `exiting`, and `exit-finished` to `idle`. `shouldReleaseLock` returns true only for state `exiting` with `animationFinished === true`.

- [ ] **Step 4: Implement password PAM context**

Create a `Scope` with a `PamContext` using the project’s existing PAM import. Keep `currentText` in the context, respond with it only when PAM requests a response, clear it after responding, set `unlockInProgress` while authenticating, emit `unlocked()` on `PamResult.Success`, and clear/set failure state on non-success. Add a `reset()` function that aborts PAM and clears transient state.

- [ ] **Step 5: Run tests**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lock_logic.qml -o -,txt`

Expected: PASS with no WARN/ERROR output.

- [ ] **Step 6: Commit**

```bash
git add modules/lock/LockContext.qml modules/lock/LockLogic.js tests/qml/tst_lock_logic.qml
git commit -m "feat(lock): add password authentication context"
```

### Task 3: Add Snapshot Preparation and Session-Lock Surface

**Files:**
- Create: `modules/lock/LockSnapshot.qml`
- Create: `modules/lock/LockSurface.qml`
- Create: `tests/qml/tst_lock_surface_logic.qml`

**Interfaces:**
- Consumes: a `screen` object, optional snapshot URL/provider result, `LazerTheme`, `MotionTokens`, and `LockContext`.
- Produces: `LockSnapshot` with `request(screenCount)`, `ready`, `generation`, and `prepared(generation)`; `LockSurface` with `startReveal()`, `startExit()`, and `releaseRequested()`.

- [ ] **Step 1: Write failing surface contract tests**

Test that a surface is full-size, reveal progress starts at `0`, reaches `1`, and `releaseRequested` is not emitted before exit animation completion. Test reduced motion reaches final values immediately.

- [ ] **Step 2: Run the tests to verify failure**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lock_surface_logic.qml -o -,txt`

Expected: FAIL because the surface files do not exist.

- [ ] **Step 3: Implement snapshot preparation**

Use the available Quickshell screencopy/snapshot API verified against the installed Quickshell version. Track a monotonically increasing generation and complete when all requested screens report ready. Add a short timeout fallback that marks the request ready without a desktop image; the consumer must then show a solid opaque background. Do not create a normal interactive window during preparation.

- [ ] **Step 4: Implement the full-screen `WlSessionLockSurface`**

Create a `WlSessionLockSurface` with transparent surface color and full parent geometry. Put an opaque fallback rectangle at the bottom, an optional snapshot image above it, `WaveRevealLayers` above the snapshot, and a square/rectangular lock content area above the Wave. Use `waveProgress` for reveal geometry. Keep password input inside an inner `Item` with `focus: true`; do not attach `Keys` handlers to the surface itself.

- [ ] **Step 5: Implement animation ordering**

On startup, show the snapshot/fallback immediately, animate `waveProgress` from `0` to `1` using `MotionTokens.waveBackdropEnter` or the closest existing Wave token, then fade in the password content. On `LockContext.unlocked`, fade out auth content, animate `waveProgress` back to `0`, and emit `releaseRequested` only from the finished handler. Under reduced motion, set all values to their final state and emit the release signal without a visual animation.

- [ ] **Step 6: Run tests**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lock_surface_logic.qml -o -,txt`

Expected: PASS with no WARN/ERROR output.

- [ ] **Step 7: Commit**

```bash
git add modules/lock/LockSnapshot.qml modules/lock/LockSurface.qml tests/qml/tst_lock_surface_logic.qml
git commit -m "feat(lock): add full-screen wave lock surface"
```

### Task 4: Wire Lock Controller, IPC, Shortcut, and Shell

**Files:**
- Create: `modules/lock/Lock.qml`
- Create: `modules/lock/qmldir`
- Modify: `shell.qml:1-22`
- Create: `tests/qml/tst_lock_controller_logic.qml`

**Interfaces:**
- Consumes: `LockSnapshot`, `LockSurface`, `LockContext`, `LockLogic`, and `Quickshell.screens`.
- Produces: `Lock` with `lock()`, `unlock()`, `isLocked()`, `locked`, and `preparing` properties; IPC target `lock`; shortcut name `lock`.

- [ ] **Step 1: Write failing controller tests**

Test duplicate `lock()` returns false while `locked` or `preparing`, successful snapshot preparation transitions to locked, and `unlock()` does not directly clear the locked state.

- [ ] **Step 2: Run the tests to verify failure**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lock_controller_logic.qml -o -,txt`

Expected: FAIL because the controller does not exist.

- [ ] **Step 3: Implement the controller**

Create one `WlSessionLock` and load one `LockSurface` per session-lock surface through its child component structure. `lock()` resets context, sets `preparing`, requests snapshots for `Quickshell.screens.length`, and commits `sessionLock.locked = true` when the matching generation is prepared. Add a bounded timeout fallback so `sessionLock.locked` is always eventually committed.

- [ ] **Step 4: Add IPC and shortcut**

Add an `IpcHandler` with target `lock` and functions `lock()`, `unlock()`, and `isLocked()`. `unlock()` may call the surface/context’s normal authentication flow only; it must not set `WlSessionLock.locked = false` or bypass PAM. Add a `CustomShortcut` named `lock` that calls the controller lock function.

- [ ] **Step 5: Mount from `shell.qml` and register module**

Register files in `modules/lock/qmldir` if required by the local import conventions, import `modules/lock` in `shell.qml`, and instantiate `Lock {}` next to the wallpaper, bar, and notification hosts. Preserve all existing screen variants and do not move existing panel windows.

- [ ] **Step 6: Run tests**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lock_controller_logic.qml -o -,txt`

Expected: PASS with no WARN/ERROR output.

- [ ] **Step 7: Commit**

```bash
git add modules/lock/Lock.qml modules/lock/qmldir shell.qml tests/qml/tst_lock_controller_logic.qml
git commit -m "feat(lock): wire session lock into afloat"
```

### Task 5: Full Verification and Cleanup

**Files:**
- Modify only files from Tasks 1-4 if fixes are needed.

- [ ] **Step 1: Run all affected pure QML tests**

Run:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wave_reveal_layers.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wave_surface_host.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_fullscreen_wave.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lock_logic.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lock_surface_logic.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lock_controller_logic.qml -o -,txt
```

Expected: every command reports PASS, zero WARN/ERROR, and zero failed tests.

- [ ] **Step 2: Launch smoke test**

Run: `qs -p /home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat`

Expected: shell starts without QML type/import errors. Trigger lock through the configured IPC command, verify the Wave expands to every screen, password input receives focus, failed authentication keeps the lock, and successful authentication reverses the Wave before desktop restoration. Stop the smoke-test process after verification.

- [ ] **Step 3: Inspect final status**

Run: `git status --short` and `git diff --check`

Expected: only intended lock/Wave files are changed by this work; existing unrelated modifications and temporary files remain untouched.

- [ ] **Step 4: Commit fixes if required**

```bash
git add modules/lock modules/lazerbar/WaveRevealLayers.qml modules/lazerbar/WaveSurfaceHost.qml shell.qml tests/qml docs/superpowers/plans/2026-08-28-wave-session-lock.md
git commit -m "fix(lock): resolve session lock verification issues"
```
