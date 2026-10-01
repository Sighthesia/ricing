# Wallpaper-First Startup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start Afloat's first wallpaper reveal before bar/chrome construction, then mount the remaining shell surfaces after all screens have completed their initial reveal.

**Architecture:** Keep `WallpaperBackground` eagerly mounted as the wallpaper bootstrap surface. Replace the clean-frame startup gate with an image-readiness gate, and expose an idempotent cross-screen `bootReady` state. Move overview, bar, notifications, corner mask, lock, and their explicit startup service calls into a root `Loader` activated by `bootReady`.

**Tech Stack:** Quickshell, Qt 6.11 QML, QtQuick `Loader`/`Component`, `OpacityMask`, pure QML JavaScript tests with `/usr/lib/qt6/bin/qmltestrunner`.

## Global Constraints

- The first wallpaper source must begin loading without waiting for bar or chrome construction.
- The circular boot reveal must begin as soon as its pixels are ready.
- Live wallpaper changes must keep the current synchronous decode, click-origin snapshot, circular reveal, and palette gate.
- Palette extraction remains after the reveal completes.
- Empty wallpaper paths, image errors, reduced motion, screen removal, and screen addition must not strand chrome behind the loader.
- No test may mount an extra full-screen surface or interfere with the user's desktop.
- After every QML change, run the relevant Qt 6 test file and fix WARN/ERROR output before finishing.
- Preserve unrelated user changes in the worktree.

## File Map

- Create `modules/lazerbar/WallpaperBootLogic.js`: pure cross-screen boot-completion state transitions.
- Create `tests/qml/tst_wallpaper_boot.qml`: Qt 6 tests for screen keys, completion deduplication, screen changes, and readiness.
- Modify `modules/lazerbar/WallpaperBackground.qml`: remove the clean-frame gate, wait for first-image readiness, and report per-screen completion.
- Modify `shell.qml`: keep the wallpaper bootstrap eager and load all chrome through a delayed `Loader`.
- Modify `tests/qml/tst_wallpaper_reveal.qml` only if a regression assertion needs to cover the retained image-readiness contract; do not replace its existing geometry coverage.

## Task 1: Add Pure Multi-Screen Boot State

**Files:**
- Create: `modules/lazerbar/WallpaperBootLogic.js`
- Create: `tests/qml/tst_wallpaper_boot.qml`

**Interfaces:**
- Produces `screenKey(name, x, y, width, height) -> string`.
- Produces `markFinished(finishedKeys, key) -> string[]`, returning a copied list and ignoring duplicate keys.
- Produces `currentKeys(screens) -> string[]`, accepting plain test objects with `name`, `x`, `y`, `width`, and `height` fields.
- Produces `isReady(finishedKeys, currentKeys) -> bool`, returning false for an empty screen list and true only when every current screen key is finished.
- Later QML code consumes these functions without importing Quickshell into the test file.

- [ ] **Step 1: Write the failing pure QML tests.**

Create `tests/qml/tst_wallpaper_boot.qml` with this complete test shape:

```qml
import QtQuick
import QtTest
import "../../modules/lazerbar/WallpaperBootLogic.js" as Boot

Item {
    TestCase {
        name: "WallpaperBoot"
        when: windowShown
        visible: true

        function screens() {
            return [
                { name: "DP-1", x: 0, y: 0, width: 1920, height: 1080 },
                { name: "HDMI-1", x: 1920, y: 0, width: 1920, height: 1080 },
            ]
        }

        function test_keyIncludesGeometry() {
            compare(Boot.screenKey("DP-1", 0, 0, 1920, 1080),
                    "DP-1@0,0,1920x1080")
            verify(Boot.screenKey("DP-1", 0, 0, 1920, 1080)
                   !== Boot.screenKey("DP-1", 0, 0, 2560, 1440))
        }

        function test_currentKeysAreStable() {
            compare(Boot.currentKeys(screens()), [
                "DP-1@0,0,1920x1080",
                "HDMI-1@1920,0,1920x1080",
            ])
        }

        function test_duplicateCompletionIsIgnored() {
            var key = Boot.screenKey("DP-1", 0, 0, 1920, 1080)
            var once = Boot.markFinished([], key)
            var twice = Boot.markFinished(once, key)
            compare(once, [key])
            compare(twice, [key])
        }

        function test_allScreensMustFinish() {
            var keys = Boot.currentKeys(screens())
            var first = Boot.markFinished([], keys[0])
            verify(!Boot.isReady(first, keys))
            var second = Boot.markFinished(first, keys[1])
            verify(Boot.isReady(second, keys))
        }

        function test_removedScreenDoesNotBlock() {
            var keys = Boot.currentKeys(screens())
            var finished = Boot.markFinished([], keys[0])
            compare(Boot.currentKeys([screens()[0]]), [keys[0]])
            verify(Boot.isReady(finished, Boot.currentKeys([screens()[0]])))
        }

        function test_addedScreenBlocksUntilFinished() {
            var original = screens()
            var originalKeys = Boot.currentKeys(original)
            var finished = Boot.markFinished([], originalKeys[0])
            finished = Boot.markFinished(finished, originalKeys[1])
            var added = original.concat([
                { name: "DP-2", x: 0, y: 1080, width: 1920, height: 1080 },
            ])
            var addedKeys = Boot.currentKeys(added)
            verify(!Boot.isReady(finished, addedKeys))
            finished = Boot.markFinished(finished, addedKeys[2])
            verify(Boot.isReady(finished, addedKeys))
        }

        function test_emptyScreensAreNotReady() {
            verify(!Boot.isReady([], []))
        }
    }
}
```

- [ ] **Step 2: Run the new test and verify it fails.**

Run:

```fish
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_wallpaper_boot.qml -o -,txt
```

Expected: the test runner fails because `WallpaperBootLogic.js` does not yet exist or does not export the requested functions.

- [ ] **Step 3: Implement the pure logic.**

Create `modules/lazerbar/WallpaperBootLogic.js`:

```javascript
.pragma library

function finite(value, fallback) {
    var number = Number(value)
    return isFinite(number) ? number : fallback
}

function screenKey(name, x, y, width, height) {
    return String(name == null ? "" : name)
            + "@" + finite(x, 0) + "," + finite(y, 0)
            + "," + finite(width, 0) + "x" + finite(height, 0)
}

function currentKeys(screens) {
    var result = []
    for (var index = 0; index < (screens || []).length; index++) {
        var screen = screens[index]
        if (!screen)
            continue
        result.push(screenKey(screen.name, screen.x, screen.y,
                              screen.width, screen.height))
    }
    return result
}

function markFinished(finishedKeys, key) {
    var result = (finishedKeys || []).slice()
    var normalized = String(key == null ? "" : key)
    if (normalized && result.indexOf(normalized) < 0)
        result.push(normalized)
    return result
}

function isReady(finishedKeys, currentScreenKeys) {
    var finished = finishedKeys || []
    var current = currentScreenKeys || []
    if (!current.length)
        return false
    for (var index = 0; index < current.length; index++) {
        if (finished.indexOf(current[index]) < 0)
            return false
    }
    return true
}
```

- [ ] **Step 4: Run the focused test and verify it passes.**

Run the same `qmltestrunner` command. Expected: all six boot-state tests pass with no QML warnings or errors.

- [ ] **Step 5: Commit the isolated logic seam.**

```fish
git add modules/lazerbar/WallpaperBootLogic.js tests/qml/tst_wallpaper_boot.qml
git commit -m "test(wallpaper): add multi-screen boot readiness seam"
```

## Task 2: Start the Boot Reveal at Image Readiness

**Files:**
- Modify: `modules/lazerbar/WallpaperBackground.qml`
- Test: `tests/qml/tst_wallpaper_boot.qml`
- Test: `tests/qml/tst_wallpaper_reveal.qml`

**Interfaces:**
- `WallpaperBackground.bootReady: bool` is the root-level signal state consumed by `shell.qml`.
- `WallpaperBackground.reportBootFinished(screenKey: string)` records one screen completion and recomputes readiness against `Quickshell.screens`.
- Each screen instance calls `reportBootFinished` exactly once for its first wallpaper outcome.
- `WallpaperReveal.imageReady` and `WallpaperReveal.imageFailed` remain the only boot-image readiness outcomes.

- [ ] **Step 1: Re-run the pure readiness tests before editing QML.**

Run:

```fish
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_wallpaper_boot.qml -o -,txt
```

Expected: the complete pure readiness contract from Task 1 passes, establishing the seam that the QML root will consume.

- [ ] **Step 2: Refactor `WallpaperBackground.qml` root state.**

At the `Variants` root:

```qml
import "WallpaperBootLogic.js" as BootLogic

property bool bootReady: false
property var finishedBootScreens: []

function currentBootKeys() {
    return BootLogic.currentKeys(Quickshell.screens)
}

function refreshBootReady() {
    var current = currentBootKeys()
    var retained = []
    for (var index = 0; index < root.finishedBootScreens.length; index++) {
        if (current.indexOf(root.finishedBootScreens[index]) >= 0)
            retained.push(root.finishedBootScreens[index])
    }
    root.finishedBootScreens = retained
    root.bootReady = BootLogic.isReady(retained, current)
}

function reportBootFinished(screenKey) {
    root.finishedBootScreens = BootLogic.markFinished(root.finishedBootScreens, screenKey)
    root.refreshBootReady()
}

Connections {
    target: Quickshell
    function onScreensChanged() { root.refreshBootReady() }
}
```

Use a per-screen key derived from the current `modelData` name and geometry. Do not use only the screen name because a geometry change must invalidate the old completion.

- [ ] **Step 3: Replace the clean-frame gate with the image-readiness gate.**

Remove `bootFrameBudget`, `bootFrameRun`, `bootPending`, `bootWallpaper`, `cleanFrames`, `lastFrameAt`, `FrameAnimation`, and `bootTimeout`.

Keep `settledOnce`, and add per-screen state:

```qml
property bool bootRevealActive: false
property bool bootRevealWaitingForImage: false
property bool bootCompletionReported: false
```

Change the first `showWallpaper(path)` branch to call `beginWallpaper(path, true)` immediately after `surfaceReady` is true. The second argument marks the first transition only; subsequent wallpaper changes call `beginWallpaper(path, false)`.

Inside `beginWallpaper(path, isBootReveal)`:

1. stop existing animations;
2. preserve the existing `resolveRevealOrigin()` snapshot;
3. assign `pendingWallpaper`, set radius to zero, and set `bootRevealActive` from the argument;
4. for boot, if `reveal.imageReady` is false, set `bootRevealWaitingForImage` and return;
5. otherwise call a new `startRevealAnimation()` helper.

The helper must contain the existing palette gate and animation restart:

```qml
function startRevealAnimation() {
    wallpaperWindow.bootRevealWaitingForImage = false
    Services.ColorService.revealStarted()
    revealAnimation.restart()
}
```

This preserves the live-switch behavior by calling the helper immediately for non-boot switches, while boot waits only for the incoming image status.

- [ ] **Step 4: Report every boot outcome and keep live switches unchanged.**

On reveal image readiness:

```qml
function onImageReadyChanged() {
    if (reveal.imageReady && wallpaperWindow.bootRevealWaitingForImage)
        wallpaperWindow.startRevealAnimation()
}
```

On animation finish, capture whether this was the boot reveal before calling `settle()`, release the palette gate as before, then call `root.reportBootFinished(screenKey)` exactly once for that screen.

For these boot outcomes, report completion without starting a circular animation:

- empty wallpaper path;
- path already equal to `baseImage.source`;
- reduced motion;
- image error.

Do not report completion from a later live wallpaper switch. Keep `ColorService.revealStarted()` and `revealCompleted()` balanced on all paths that actually start a reveal.

- [ ] **Step 5: Add an image-readiness regression assertion.**

Keep the existing `tst_wallpaper_reveal.qml` tests. Add only a pure assertion if the refactor changes the public contract: `imageReady` must remain false for an invalid source and `asynchronous` must remain false. Do not mount the full background window in the test.

- [ ] **Step 6: Run the focused QML tests and lint.**

Run:

```fish
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_wallpaper_boot.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_wallpaper_reveal.qml -o -,txt
qmllint -I /usr/lib/qt6/qml modules/lazerbar/WallpaperBackground.qml
```

Expected: all tests pass; the intentional invalid-image warning in `tst_wallpaper_reveal.qml` may remain, but there must be no new warnings or errors.

- [ ] **Step 7: Commit the wallpaper bootstrap behavior.**

```fish
git add modules/lazerbar/WallpaperBackground.qml tests/qml/tst_wallpaper_boot.qml tests/qml/tst_wallpaper_reveal.qml
git commit -m "perf(wallpaper): start boot reveal at image readiness"
```

## Task 3: Load Chrome After the Wallpaper Bootstrap

**Files:**
- Modify: `shell.qml`
- Test: `tests/qml/tst_wallpaper_boot.qml` if root-state logic is extracted for testing

**Interfaces:**
- `WallpaperBackground.bootReady` controls the chrome Loader's `active` property.
- `chromeComponent` creates `OverviewBackgroundWindow`, `Bar.TopBar`, `NotificationHost`, and `ScreenRoundedCorners` exactly once. (`LockModule.Lock` is no longer part of it — see `2026-10-01-lock-first-startup-design.md`.)
- Explicit startup calls for `AppThemeService`, `LauncherService`, `ClipboardService`, and `lockModule.startupLock()` run from chrome completion, not root completion.

- [ ] **Step 1: Move chrome into a component without changing its child bindings.**

Keep only these eager root children in `shell.qml`:

```qml
LazerBar.WallpaperBackground { id: wallpaperBackground }
Loader {
    id: chromeLoader
    active: wallpaperBackground.bootReady
    sourceComponent: chromeComponent
}
```

Define `chromeComponent` as an `Item` containing the four chrome surfaces in their current order. (`LockModule.Lock` moved back to the shell root; see `2026-10-01-lock-first-startup-design.md`.)

- [ ] **Step 2: Move explicit startup calls into the chrome component.**

The root `Component.onCompleted` keeps only the `LazerTheme.settingsService` and `LazerTheme.colorService` injection. The chrome component's `Component.onCompleted` runs:

```qml
Services.AppThemeService.apply()
Services.AppThemeService.pushSystemTheme()
Services.LauncherService.primeApps()
Services.ClipboardService.warmup()
if (!lockModule.selfTestEnabled)
    Qt.callLater(() => lockModule.startupLock())
```

Do not move the LazerTheme injection into the delayed component because the wallpaper floor uses those bindings during bootstrap.

- [ ] **Step 3: Guard the loader against a zero-screen edge case.**

`WallpaperBackground.bootReady` must remain false when `Quickshell.screens` is empty. The chrome Loader therefore stays inactive until at least one screen has completed. When screens later appear, `WallpaperBackground` creates the per-screen instance and reports completion normally.

- [ ] **Step 4: Run shell syntax and existing focused tests.**

Run:

```fish
qmllint -I /usr/lib/qt6/qml shell.qml modules/lazerbar/WallpaperBackground.qml
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_wallpaper_boot.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_wallpaper_reveal.qml -o -,txt
```

Expected: no syntax errors, all tests pass, and no temporary diagnostics are needed.

- [ ] **Step 5: Commit the staged shell startup.**

```fish
git add shell.qml
git commit -m "perf(shell): mount chrome after wallpaper reveal"
```

## Task 4: Full Verification and Cleanup

**Files:**
- Modify only files required by a failing verification test.
- Remove any temporary diagnostic artifacts created during manual verification.

- [ ] **Step 1: Run all relevant pure QML tests.**

Run:

```fish
for test in \
  tests/qml/tst_wallpaper_boot.qml \
  tests/qml/tst_wallpaper_reveal.qml \
  tests/qml/tst_screen_corner_mask.qml \
  tests/qml/tst_launcher_page.qml
    QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
      -input $test -o -,txt
end
```

Expected: every test reports zero failures. The existing missing-image test warning is acceptable only if it is unchanged and remains attached to that intentional test case.

- [ ] **Step 2: Run Python tests and inspect the complete diff.**

```fish
python3 -m pytest scripts/tests/ -q
git diff --check
git status --short
```

Do not stage or revert unrelated user files shown by `git status`.

- [ ] **Step 3: Perform a production diagnostic-marker scan.**

```fish
grep -RInE 'TEMP DIAGNOSTIC|DEBUG-startup|afloat-wallpaper-probe|bootFrameRun|bootTimeout' \
  shell.qml modules/lazerbar/WallpaperBackground.qml modules/lazerbar/WallpaperBootLogic.js \
  tests/qml/tst_wallpaper_boot.qml || true
```

Expected: no temporary startup probe markers and no removed clean-frame gate identifiers.

- [ ] **Step 4: Manually verify the startup contract without adding a test surface.**

Reload the shell normally and confirm:

1. the wallpaper begins its circular reveal before the bar becomes visible;
2. the reveal starts from the center on startup and from the captured trigger point on a live wallpaper change;
3. the bar, notifications, corner mask, and lock appear after the initial reveal;
4. the wallpaper still switches smoothly after startup;
5. a missing wallpaper path does not leave chrome unloaded.

Use normal compositor observation only; do not add a full-screen probe or leave a `/tmp` logger in production code.

- [ ] **Step 5: Commit only verification fixes when the preceding checks require them.**

If verification changed `WallpaperBackground.qml`, `shell.qml`,
`WallpaperBootLogic.js`, `tst_wallpaper_boot.qml`, or
`tst_wallpaper_reveal.qml`, stage only those changed paths and run:

```fish
git add modules/lazerbar/WallpaperBackground.qml shell.qml \
  modules/lazerbar/WallpaperBootLogic.js tests/qml/tst_wallpaper_boot.qml \
  tests/qml/tst_wallpaper_reveal.qml
git commit -m "test(startup): verify wallpaper-first shell bootstrap"
```

If verification produces no source changes, keep the three focused commits
from Tasks 1-3 and report their hashes.

## Self-Review

- Spec coverage: Task 1 covers the pure multi-screen readiness seam; Task 2 covers image-first boot reveal, error paths, reduced motion, and live-switch preservation; Task 3 covers delayed chrome and startup service calls; Task 4 covers tests, diagnostics cleanup, and manual acceptance.
- Placeholder scan: no `TODO`, `TBD`, or unspecified implementation step is used in this plan; the conditional verification commit names every possible source path.
- Type consistency: `WallpaperBackground.bootReady` is a bool, `reportBootFinished` accepts the string generated by `WallpaperBootLogic.screenKey`, and `chromeLoader.active` consumes that bool. `markFinished` and `isReady` use string arrays throughout.
- Scope: the plan does not alter the proven mask implementation, corner geometry, palette extraction ordering, or live wallpaper switch path except where boot state must be isolated.
