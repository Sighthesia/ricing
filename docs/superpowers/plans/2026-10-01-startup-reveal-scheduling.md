# Startup Reveal Scheduling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove startup long frames by sequencing the wallpaper reveal, chrome staging, lock wave, and low-priority warmups while preserving startup-first-lock behavior and all manual/live paths.

**Architecture:** Keep `WallpaperBackground` and `LockModule.Lock` eager at the shell root. Add pure startup-stage and wallpaper-slot seams, then let the root pass explicit readiness gates to the lock and chrome. Replace the wallpaper's startup source handoff with two reusable image slots, activate bar widgets in bounded batches, and start background work only after the first lock-wave frame.

**Tech Stack:** Qt 6.11 QML/QtQuick, Quickshell, QtTest/qmltestrunner, root-level `qs -p` harnesses, JavaScript `.pragma library` logic modules.

## Global Constraints

- Preserve startup-first-lock: `LockModule.Lock` remains eagerly mounted at the shell root and startup requests always use the `wallpaper` background mode.
- Preserve manual semantics: manual wallpaper switches keep the no-gap handoff; manual lock requests keep configured screenshot/wallpaper behavior and PAM ownership.
- Do not add a new layer-shell surface for coordination.
- Do not animate a top-level window size, exclusive zone, input region, or other compositor boundary per frame.
- Do not replace the working `OpacityMask` path with inline `ShaderEffect`, `Canvas`, or `QtQuick.Shapes` masks.
- Startup stages are monotonic and idempotent: duplicate readiness signals never recreate chrome or restart a completed reveal.
- All QML tests run through `scripts/run-tests.sh`; never run `lock-test.qml` or window-only harnesses without explicit user approval.
- After every QML change, run the focused test file and fix new WARN/ERROR output before continuing.
- Keep unrelated dirty worktree changes untouched and stage only files belonging to the current task.

---

## File Map

Create:

- `modules/lazerbar/StartupRevealLogic.js` — pure monotonic startup stages, gate predicates, and ordered task batches.
- `modules/lazerbar/WallpaperSlotLogic.js` — pure two-slot promotion and decode-size decisions.
- `tests/qml/tst_startup_reveal_logic.qml` — startup-stage and gate contracts.
- `tests/qml/tst_wallpaper_slot_logic.qml` — slot promotion and source-size contracts.
- `tests/qml/tst_shipped_widgets.qml` — pure startup batch classification.
- `tst_bar_content_startup.qml` — root-level offscreen harness for batched widget activation.
- `tst_wallpaper_startup_slots.qml` — root-level offscreen harness for production wallpaper slot promotion.

Modify:

- `modules/lazerbar/WallpaperReveal.qml` — accept an externally owned `Image` as the mask source.
- `modules/lazerbar/WallpaperBackground.qml` — own two reusable image slots, promote the incoming slot without assigning a new source at settle time, and expose startup readiness.
- `tests/qml/tst_wallpaper_reveal.qml` — verify an injected source item is the actual mask source.
- `modules/lock/Lock.qml` — carry the startup request flag and explicit wallpaper/chrome readiness inputs into each lock surface; emit the first startup-wave signal.
- `modules/lock/LockSurface.qml` — prepare the startup surface without starting its wave until the gate opens; keep manual reveal behavior unchanged.
- `tests/qml/tst_lock_surface_logic.qml` — cover gated startup reveal and unchanged manual/exit behavior.
- `shell.qml` — own the startup coordinator, connect wallpaper/chrome readiness, and run the post-wave task queue.
- `modules/bar/BarContent.qml` — add deterministic startup batches and a completion property while retaining one-tick activation for normal use.
- `modules/bar/ShippedWidgets.js` — assign stable startup batch classes to widget ids.
- `modules/bar/TopBar.qml` — pass staging state into `BarContent` and aggregate per-screen readiness.
- `tests/qml/tst_startup_lock_logic.qml` — assert gate values do not alter background-mode decisions.
- `tst_lock_startup_order.qml` — extend static startup wiring regression checks.
- `services/ColorService.qml` — hold extraction until the startup quiet gate is opened.
- `services/RipplePulseService.qml` — suppress only startup-state pulse triggers while keeping the service inactive/active contract otherwise intact.
- `tst_color_service_reveal.qml` — verify pending extraction is flushed once after the quiet gate.
- `tst_glow_pulse.qml` — verify startup suppression does not suppress post-startup triggers.

---

### Task 1: Add Pure Startup and Wallpaper-Slot Contracts

**Files:**
- Create: `modules/lazerbar/StartupRevealLogic.js`
- Create: `modules/lazerbar/WallpaperSlotLogic.js`
- Create: `tests/qml/tst_startup_reveal_logic.qml`
- Create: `tests/qml/tst_wallpaper_slot_logic.qml`
- Modify: `modules/lazerbar/qmldir` only if the production QML imports the new modules by registered name; direct relative JS imports remain preferred.

**Interfaces:**
- `StartupRevealLogic.Stages` exposes integer constants `lockedFloor`, `wallpaperReveal`, `chromeStaging`, and `quietReady`.
- `StartupRevealLogic.advance(stage, event)` returns the next stage and never moves backward.
- `StartupRevealLogic.waveAllowed(isStartup, wallpaperReady, chromeReady)` returns `true` for every manual request and only when both startup gates are true for a startup request.
- `StartupRevealLogic.allScreensReady(finishedNames, currentNames)` returns `false` for an empty current list and `true` only when every current screen is recorded.
- `WallpaperSlotLogic.otherSlot(slot)` returns `1` for `0`, `0` for `1`, and `0` for invalid input.
- `WallpaperSlotLogic.promote(settledSlot, incomingSlot)` returns `{ settledSlot: incomingSlot, incomingSlot: settledSlot }` for distinct valid slots and leaves a valid pair unchanged for invalid/equal input.
- `WallpaperSlotLogic.sourceSize(screenWidth, screenHeight, devicePixelRatio, maxTexturePixels)` returns a positive `{ width, height }` bounded by the screen size multiplied by DPR and by the configured pixel cap.

- [ ] **Step 1: Write the failing pure tests.**

```qml
function test_stageOrderIsMonotonic() {
    compare(Logic.advance(Logic.Stages.lockedFloor, "wallpaper-ready"),
            Logic.Stages.wallpaperReveal)
    compare(Logic.advance(Logic.Stages.wallpaperReveal, "chrome-mounted"),
            Logic.Stages.chromeStaging)
    compare(Logic.advance(Logic.Stages.chromeStaging, "chrome-ready"),
            Logic.Stages.chromeStaging)
    compare(Logic.advance(Logic.Stages.chromeStaging, "wave-started"),
            Logic.Stages.quietReady)
    compare(Logic.advance(Logic.Stages.quietReady, "wallpaper-ready"),
            Logic.Stages.quietReady)
    compare(Logic.advance(Logic.Stages.lockedFloor, "unknown"),
            Logic.Stages.lockedFloor)
}

function test_startupWaveNeedsBothGates() {
    verify(!Logic.waveAllowed(true, false, false))
    verify(!Logic.waveAllowed(true, true, false))
    verify(!Logic.waveAllowed(true, false, true))
    verify(Logic.waveAllowed(true, true, true))
    verify(Logic.waveAllowed(false, false, false))
}
```

```qml
function test_promotionKeepsTheDecodedIncomingSlot() {
    compare(Slots.promote(0, 1), { settledSlot: 1, incomingSlot: 0 })
    compare(Slots.promote(1, 0), { settledSlot: 0, incomingSlot: 1 })
}

function test_sourceSizeIsBoundedByScreenAndTextureBudget() {
    var size = Slots.sourceSize(3840, 2160, 2, 16 * 1024 * 1024)
    verify(size.width <= 7680)
    verify(size.height <= 4320)
    verify(size.width * size.height <= 16 * 1024 * 1024)
    verify(size.width > 0 && size.height > 0)
}
```

- [ ] **Step 2: Run only the new tests and verify they fail for missing modules.**

Run: `scripts/run-tests.sh tst_startup_reveal_logic tst_wallpaper_slot_logic --no-python`

Expected: both files are reported red because the imported functions do not yet exist.

- [ ] **Step 3: Implement the pure modules with no QML or service imports.**

Use an explicit event table in `advance()` rather than numeric `Math.min()` so unknown events are fail-closed. In `sourceSize()`, preserve aspect ratio while reducing the longer side until the pixel budget is satisfied; clamp DPR to at least `1` and return integer dimensions.

- [ ] **Step 4: Run the focused tests and inspect diagnostics.**

Run: `scripts/run-tests.sh tst_startup_reveal_logic tst_wallpaper_slot_logic --no-python`

Expected: all new assertions pass with no new QML warnings.

- [ ] **Step 5: Commit the pure contracts.**

```bash
git add modules/lazerbar/StartupRevealLogic.js \
    modules/lazerbar/WallpaperSlotLogic.js \
    tests/qml/tst_startup_reveal_logic.qml \
    tests/qml/tst_wallpaper_slot_logic.qml
git commit -m "test(startup): add reveal and wallpaper slot contracts"
```

### Task 2: Reuse the Decoded Wallpaper Slot

**Files:**
- Modify: `modules/lazerbar/WallpaperReveal.qml`
- Modify: `modules/lazerbar/WallpaperBackground.qml`
- Modify: `tests/qml/tst_wallpaper_reveal.qml`

**Interfaces:**
- `WallpaperReveal.sourceItem: Item` is optional. When set, the `OpacityMask.source` and readiness/error properties use that item; when unset, the existing internal `Image` remains the live-switch fallback.
- `WallpaperBackground` maintains `settledSlot` and `incomingSlot` values of `0` or `1`, two fixed `Image` children, and a `startupImageReady`/existing `bootReady` path that reports only after the incoming slot has completed or reached a terminal outcome.
- Promotion changes slot roles and visibility/opacity only; it does not assign `source` to the newly settled image.

- [ ] **Step 1: Add the injected source-item regression test.**

Extend `tst_wallpaper_reveal.qml` with a decoded data-URL `Image` and an injected reveal:

```qml
Image {
    id: injectedWallpaper
    width: 400
    height: 240
    source: "data:image/svg+xml," + encodeURIComponent(
        '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="240">'
        + '<rect width="400" height="240" fill="blue"/></svg>')
    visible: false
}

Lazer.WallpaperReveal {
    id: injectedReveal
    width: 400
    height: 240
    sourceItem: injectedWallpaper
    radius: 24
}
```

Assert after `tryCompare(injectedWallpaper, "status", Image.Ready)` that
`injectedReveal.revealMask.source === injectedWallpaper`, `imageReady` is true, and the internal fallback image is not the mask source.

- [ ] **Step 2: Run the focused reveal test and verify the injected-source assertions fail.**

Run: `scripts/run-tests.sh tst_wallpaper_reveal --no-python`

Expected: the existing tests pass, while the new injected-source assertion fails because `WallpaperReveal` currently owns its private image unconditionally.

- [ ] **Step 3: Implement `WallpaperReveal.sourceItem` without changing the fallback path.**

Add:

```qml
property Item sourceItem: null
readonly property Item effectiveSourceItem: root.sourceItem || nextWallpaper
readonly property bool imageReady: effectiveSourceItem
        && effectiveSourceItem.status === Image.Ready
readonly property bool imageFailed: effectiveSourceItem
        && effectiveSourceItem.status === Image.Error
```

Bind `OpacityMask.source` to `effectiveSourceItem`; keep the internal image source/asynchronous behavior for `sourceItem === null`. The external slot must remain a sibling in the same scene graph and keep `visible: false` so it is sampled only through the mask.

- [ ] **Step 4: Replace `baseImage`/`reveal.nextWallpaper` handoff with two slots.**

In `WallpaperBackground.qml`:

1. Import `WallpaperSlotLogic.js`.
2. Add `property int settledSlot: 0` and `property int incomingSlot: 1`.
3. Replace `baseImage` with `wallpaperSlot0` and add `wallpaperSlot1`; both fill the surface, use `PreserveAspectCrop`, `cache: false`, and `sourceSize` calculated once from the stable screen geometry through `WallpaperSlotLogic.sourceSize()`.
4. Bind each slot's `visible`/`opacity` to whether it is the current settled slot; do not bind either slot's `source` to the other slot's role.
5. Pass `sourceItem: wallpaperWindow.incomingSlot === 0 ? wallpaperSlot0 : wallpaperSlot1` to `WallpaperReveal`.
6. Assign a new path only to the current incoming slot. For boot, set `asynchronous: true` and wait for `Image.Ready`; for live switches, preserve the current synchronous no-gap contract by setting `asynchronous: false` before assignment.
7. On reveal completion, call a `promoteIncoming()` function that applies `WallpaperSlotLogic.promote()`, sets the new settled slot visible, resets the radius, then clears the old slot source after the role swap. Do not call `settledImage.source = pendingWallpaper`.
8. Update `bootOutcomeFor()` to compare against the settled slot's current source. Preserve empty/error/reduced-motion/unchanged completion branches and `ColorService.revealCompleted()` calls.

- [ ] **Step 5: Add component assertions for promotion behavior.**

Create `tst_wallpaper_startup_slots.qml` as a root-level `qs -p` harness. It must instantiate the production `WallpaperBackground` only with a synthetic settings/wallpaper input and offscreen screen data, then assert after a data-URL boot reveal that the settled source is the incoming path, `settledSlot` changed to the previous incoming slot, and no second source assignment is needed to make the settled image ready. The harness must exit cleanly when offscreen cannot load `PanelWindow`, using the same skip classification as other root-level window harnesses; do not instantiate `PanelWindow` from QtTest.

- [ ] **Step 6: Run wallpaper tests and lint the modified QML.**

Run:

```bash
scripts/run-tests.sh tst_wallpaper_reveal tst_wallpaper_boot --no-python
/usr/lib/qt6/bin/qmllint modules/lazerbar/WallpaperReveal.qml modules/lazerbar/WallpaperBackground.qml
```

Expected: all focused tests pass; only pre-existing non-error qmllint warnings remain.

- [ ] **Step 7: Commit the slot implementation.**

```bash
git add modules/lazerbar/WallpaperReveal.qml \
    modules/lazerbar/WallpaperBackground.qml \
    tests/qml/tst_wallpaper_reveal.qml
git commit -m "perf(wallpaper): promote decoded startup image slots"
```

### Task 3: Gate the Startup Lock Wave

**Files:**
- Modify: `modules/lock/Lock.qml`
- Modify: `modules/lock/LockSurface.qml`
- Modify: `tests/qml/tst_lock_surface_logic.qml`
- Modify: `tests/qml/tst_startup_lock_logic.qml`

**Interfaces:**
- `Lock.startupWallpaperReady: bool` and `Lock.startupChromeReady: bool` are externally supplied only for the startup request.
- `Lock.startupWaveStarted` is emitted once per accepted startup request when the first startup wave animation actually begins.
- `LockSurface.startupRequest: bool`, `LockSurface.startupRevealAllowed: bool`, and `LockSurface.startupWaveStarted` are explicit properties/signals.
- Manual requests always call the existing `startReveal()` behavior without waiting on startup gates.

- [ ] **Step 1: Extend the logic test with the gate contract.**

Add assertions using `StartupRevealLogic.waveAllowed()`:

```qml
function test_startupWaveNeedsWallpaperAndChromeReady() {
    verify(!Reveal.waveAllowed(true, false, false))
    verify(!Reveal.waveAllowed(true, true, false))
    verify(!Reveal.waveAllowed(true, false, true))
    verify(Reveal.waveAllowed(true, true, true))
    verify(Reveal.waveAllowed(false, false, false))
}
```

Also keep `backgroundModeFor()` assertions proving that readiness does not change startup/manual background mode.

- [ ] **Step 2: Add the failing gated-surface test to the existing harness.**

Extend the `lockSurface` test double with `startupRequest`, `startupRevealAllowed`, `startupWaveStarted`, and a `tryStartReveal()` function. Assert that `startupRequest = true` plus `startupRevealAllowed = false` leaves `waveProgress` at `0`, then setting the gate true starts the normal 800ms enter animation. Assert a manual surface starts immediately even when the gate is false.

- [ ] **Step 3: Run the focused lock tests and verify the new gate test fails.**

Run: `scripts/run-tests.sh tst_lock_surface_logic tst_startup_lock_logic --no-python`

Expected: existing manual/exit tests pass and the new startup-gate test fails before production wiring exists.

- [ ] **Step 4: Split `LockSurface.startReveal()` into preparation and gated wave start.**

Keep the current theme snapshot, focus, animation reset, and reduced-motion handling in a preparation function. Add:

```qml
property bool startupRequest: false
property bool startupRevealAllowed: true
property bool startupWaveStarted: false
signal startupWaveStartedSignal()

function beginEntryWave() {
    if (root.exitStarted || root.reducedMotion || root.startupWaveStarted)
        return
    root.startupWaveStarted = true
    root.revealStartTimer.restart()
    root.startupWaveStartedSignal()
}
```

For startup requests, `Component.onCompleted` prepares the surface and waits. For manual requests, it prepares and calls `beginEntryWave()` immediately. Add an `onStartupRevealAllowedChanged` handler that calls `beginEntryWave()` only when `startupRequest` is true and the gate becomes allowed. Preserve the bounded image wait inside `revealStartTimer`; the gate must not bypass `imagesReady` handling.

- [ ] **Step 5: Carry the startup flag and root readiness into every surface.**

In `Lock.qml`, add `startupRequest`, `startupWallpaperReady`, and `startupChromeReady` state. Set `startupRequest = startup === true` in `lock(startup)`, reset it for manual lock, and bind the `LockSurface` values:

```qml
startupRequest: root.startupRequest
startupRevealAllowed: !root.startupRequest
        || StartupRevealLogic.waveAllowed(true,
                                          root.startupWallpaperReady,
                                          root.startupChromeReady)
```

Connect the surface signal to `root.startupWaveStarted()`. Do not change `_commitLock()`, PAM release, snapshot generation, or manual `requestSessionLock()` behavior.

- [ ] **Step 6: Run focused lock tests and lint.**

Run:

```bash
scripts/run-tests.sh tst_lock_surface_logic tst_startup_lock_logic tst_lock_backdrop --no-python
/usr/lib/qt6/bin/qmllint modules/lock/Lock.qml modules/lock/LockSurface.qml
```

Expected: startup wave waits for both gates, manual wave remains immediate, and no new qmllint errors appear.

- [ ] **Step 7: Commit the lock gate.**

```bash
git add modules/lock/Lock.qml modules/lock/LockSurface.qml \
    tests/qml/tst_lock_surface_logic.qml tests/qml/tst_startup_lock_logic.qml
git commit -m "perf(lock): gate startup wave behind settled chrome"
```

### Task 4: Batch Bar Widget Activation and Report Chrome Readiness

**Files:**
- Modify: `modules/bar/ShippedWidgets.js`
- Modify: `modules/bar/BarContent.qml`
- Modify: `modules/bar/TopBar.qml`
- Create: `tst_bar_content_startup.qml`

**Interfaces:**
- `ShippedWidgets.startupBatch(widgetId)` returns `0` for `clock`/`active-window`, `1` for `workspaces`/`media`/`tray`, and `2` for other shipped widgets.
- `BarContent.startupStaging: bool` enables batching; `startupBatchLimit: int` is the number of released batches; `startupReady: bool` reports completion.
- `TopBar.startupStaging: bool` passes staging to each screen's `BarContent`; `TopBar.startupReady: bool` becomes true only after every current screen reports its bar content ready.

- [ ] **Step 1: Add pure batch classification assertions.**

Create `tests/qml/tst_shipped_widgets.qml` with the pure JS import and these assertions:

```qml
compare(Widgets.startupBatch("clock"), 0)
compare(Widgets.startupBatch("active-window"), 0)
compare(Widgets.startupBatch("workspaces"), 1)
compare(Widgets.startupBatch("tray"), 1)
compare(Widgets.startupBatch("network"), 2)
compare(Widgets.startupBatch("unknown"), 2)
```

- [ ] **Step 2: Implement batch state in `BarContent`.**

Add `startupStaging`, `startupBatchLimit`, `startupReady`, `startupBatchCount: 3`, a `startupBatchTimer` with a 16ms interval, and a `startupFinished` signal. Keep `widgetsReady` as the one-tick service-registration gate. Change delegate activation to:

```qml
active: root.widgetsReady
        && (!root.startupStaging
            || Number(modelData.startupBatch || 0) < root.startupBatchLimit)
```

`loadableWidgets(sectionName)` must clone/annotate each layout entry with `startupBatch` without changing its order. When staging starts, reset the limit to `0`; after `widgetsReady`, increment one batch per timer tick. Once `startupBatchLimit === startupBatchCount`, stop the timer, set `startupReady = true`, and emit `startupFinished` on the next event-loop turn. When `startupStaging` is false, preserve the existing one-tick activation and set `startupReady` true after the initial activation.

- [ ] **Step 3: Add the root-level offscreen harness before wiring TopBar.**

Create `tst_bar_content_startup.qml` importing `BarContent` under `qs -p` with an `Item` root and injected test doubles for `SettingsService` and `BarLayoutService` where the layout model contains `clock`, `workspaces`, and `network`. Set `startupStaging: true`, wait for `startupReady`, then assert every `Loader` with a loadable model entry has `active === true`. Record the `startupBatchLimit` changes through a test connection and assert the sequence is `0 → 1 → 2 → 3`; assert that `startupReady` is not true while the limit is `0` or `1`.

Run: `scripts/run-tests.sh tst_bar_content_startup --no-python`

Expected before implementation: the harness either cannot find the new staging properties or reports the batch assertions red; it must not map a window under offscreen.

- [ ] **Step 4: Aggregate readiness in `TopBar`.**

Add `startupStaging` and a per-screen readiness registry to the `Variants` root. Each screen scope passes `startupStaging` to `BarContent` and reports its `startupReady` with the screen name. `TopBar.startupReady` must use current `Quickshell.screens` names, ignore duplicate reports, and become true when all current screens are ready. Use the existing `BootLogic.screenKey()` convention from `WallpaperBootLogic.js` so a geometry change invalidates the old readiness record. Do not recreate a screen's bar when a readiness signal repeats.

- [ ] **Step 5: Run the harness and focused bar tests.**

Run:

```bash
scripts/run-tests.sh tst_bar_content_startup tst_bar_popup_content tst_bar_status_popups --no-python
/usr/lib/qt6/bin/qmllint modules/bar/ShippedWidgets.js modules/bar/BarContent.qml modules/bar/TopBar.qml tst_bar_content_startup.qml
```

Expected: batches release one frame apart, all delegates eventually load, normal popup/content tests stay green, and no new error diagnostics appear.

- [ ] **Step 6: Commit the bar staging boundary.**

```bash
git add modules/bar/ShippedWidgets.js modules/bar/BarContent.qml \
    modules/bar/TopBar.qml tst_bar_content_startup.qml
git commit -m "perf(bar): stage startup widget activation in batches"
```

### Task 5: Coordinate the Root Startup Stages

**Files:**
- Modify: `shell.qml`
- Modify: `tst_lock_startup_order.qml`
- Modify: `modules/lazerbar/qmldir` only if a new QML coordinator component is registered.

**Interfaces:**
- Root properties: `startupStage`, `startupWallpaperReady`, `startupChromeReady`, and `startupQuietReady`.
- Root transition function: `advanceStartup(event)` delegates to `StartupRevealLogic.advance()` and is idempotent. The event table is: `wallpaper-ready` moves `lockedFloor → wallpaperReveal`; `chrome-mounted` moves `wallpaperReveal → chromeStaging`; `chrome-ready` records the chrome gate without moving past `chromeStaging`; `wave-started` moves `chromeStaging → quietReady` only after both readiness booleans are true.
- `chromeComponent.startupReady` reflects `TopBar.startupReady` plus all auxiliary loaders created after bar staging.
- `LockModule.Lock` receives `startupWallpaperReady` and `startupChromeReady` via bindings.

- [ ] **Step 1: Extend the static harness with the new ordering contract.**

Add checks that `shell.qml` contains `startupWallpaperReady`, `startupChromeReady`, `startupQuietReady`, `TopBar` staging, and a one-way `advanceStartup` call. Assert that the startup request remains outside the chrome component, while `LauncherService.primeApps()` and `ClipboardService.warmup()` are absent from the chrome component's `Component.onCompleted` block.

- [ ] **Step 2: Run the static harness and verify the new checks fail.**

Run: `scripts/run-tests.sh tst_lock_startup_order --no-python`

Expected: existing root-lock assertions pass and the new staged-startup assertions fail until `shell.qml` is wired.

- [ ] **Step 3: Add root startup state and connect wallpaper readiness.**

Import `StartupRevealLogic.js` in `shell.qml`. Initialize `startupStage` to `lockedFloor`, set `startupWallpaperReady` when `wallpaperBackground.bootReady` first becomes true, call `advanceStartup("wallpaper-ready")`, and activate `chromeLoader` exactly once. Bind the lock's readiness inputs to the root properties.

- [ ] **Step 4: Make the chrome component expose a one-way readiness result.**

Keep the component's current visual order. Pass `startupStaging: true` into `Bar.TopBar`; keep the existing visual surfaces represented by `Loader` instances whose source components are `OverviewBackgroundWindow`, `NotificationHost`, and `ScreenRoundedCorners`, and activate those loaders only after `TopBar.startupReady` is true. The component's `startupReady` must become true only after the top bar reports all screen widget batches complete and the auxiliary loaders are active. Do not call launcher, clipboard, hint, palette, or external-theme work from the component completion callback.

- [ ] **Step 5: Advance the root to chrome staging and quiet-ready.**

When `wallpaperBackground.bootReady` changes true, set `startupWallpaperReady`, call `advanceStartup("wallpaper-ready")`, and activate `chromeLoader`; activating the loader is the `chrome-mounted` event. When `chromeComponent.startupReady` changes true, set `startupChromeReady`, call `advanceStartup("chrome-ready")`, and allow the lock surface gate to start. Connect `lockModule.startupWaveStarted` to `advanceStartup("wave-started")`, then set `startupQuietReady` exactly once after that event. The root must not wait for palette extraction or launcher priming before marking quiet-ready.

- [ ] **Step 6: Run the static and focused suite.**

Run:

```bash
scripts/run-tests.sh tst_lock_startup_order tst_startup_reveal_logic \
    tst_wallpaper_boot tst_lock_surface_logic --no-python
/usr/lib/qt6/bin/qmllint shell.qml
```

Expected: the static harness reports all ordering checks passed; lock wave starts only after wallpaper and chrome gates are true.

- [ ] **Step 7: Commit root coordination.**

```bash
git add shell.qml tst_lock_startup_order.qml
git commit -m "perf(startup): coordinate wallpaper chrome and lock stages"
```

### Task 6: Defer Background Work and Suppress Startup Pulses

**Files:**
- Modify: `services/ColorService.qml`
- Modify: `services/RipplePulseService.qml`
- Modify: `shell.qml`
- Modify: `tst_color_service_reveal.qml`
- Modify: `tst_glow_pulse.qml`

**Interfaces:**
- `ColorService.startupQuietReady()` opens a one-way gate; before it opens, `extractColors()` records only the newest pending request and starts no process.
- `RipplePulseService.startupMuted: bool` suppresses `trigger()` while true without changing geometry helpers or post-startup behavior.
- Root `StartupTaskQueue` behavior is implemented with a sequence of zero/16ms timers or an existing local queue abstraction; tasks are `primeApps`, `ClipboardService.warmup`, `WindowHintService.hintHeld`, then external theme tasks at their existing delayed timer.

- [ ] **Step 1: Add failing service tests.**

In `tst_color_service_reveal.qml`, reset `startupQuietReady` to false and assert that a pending extraction remains pending while the gate is closed, then opening the gate causes exactly one debounced attempt for the latest path. In `tst_glow_pulse.qml`, assert:

```qml
pulse.startupMuted = true
pulse.trigger("DP-1", 100, 100)
verify(!pulse.active)
pulse.startupMuted = false
pulse.trigger("DP-1", 100, 100)
verify(pulse.active)
```

- [ ] **Step 2: Run focused service tests and verify the new assertions fail.**

Run: `scripts/run-tests.sh tst_color_service_reveal tst_glow_pulse --no-python`

Expected: existing reveal/pulse tests pass; new startup-gate assertions fail before production properties are present.

- [ ] **Step 3: Add the ColorService quiet gate.**

Initialize `startupQuietReady` false. In `extractColors()`, retain cache checks, assign the latest pending path, and return before starting/restarting debounce while the gate is closed. `startupQuietReady()` sets the gate once and restarts the existing debounce only when a pending path exists. Do not alter the live `revealStarted()`/`revealCompleted()` behavior after the gate is open, and do not make any process result block visual readiness.

- [ ] **Step 4: Add pulse suppression and root task scheduling.**

Add `startupMuted` to `RipplePulseService`; return from `trigger()` before changing `token`, `progress`, `active`, or the origin while muted. Set it true at root completion and false immediately before/when `startupQuietReady()` is called. Schedule the following one-shot tasks after the first startup wave signal, one event-loop turn apart:

```qml
function runStartupTask(index) {
    if (index === 0) Services.LauncherService.primeApps()
    else if (index === 1) Services.ClipboardService.warmup()
    else if (index === 2) Services.WindowHintService.hintHeld
    else return
    startupTaskTimer.restart()
}
```

Use a numeric `startupTaskIndex` and a repeating/one-shot `Timer` rather than invoking all services in one callback. At the final task, call `Services.ColorService.startupQuietReady()` and unmute the pulse service. Keep `AppThemeService` on its existing delayed timer and ensure it is not moved earlier.

- [ ] **Step 5: Run focused tests and lint.**

Run:

```bash
scripts/run-tests.sh tst_color_service_reveal tst_glow_pulse tst_lock_startup_order --no-python
/usr/lib/qt6/bin/qmllint services/ColorService.qml services/RipplePulseService.qml shell.qml
```

Expected: extraction is held until quiet-ready, startup pulse triggers are ignored, normal post-startup triggers work, and no new error diagnostics appear.

- [ ] **Step 6: Commit deferred startup work.**

```bash
git add services/ColorService.qml services/RipplePulseService.qml \
    shell.qml tst_color_service_reveal.qml tst_glow_pulse.qml
git commit -m "perf(startup): defer background work until quiet ready"
```

### Task 7: Full Regression, Static Review, and Session Verification

**Files:**
- Modify only tests/docs if a verified regression requires a narrow assertion adjustment.
- Do not stage unrelated pre-existing worktree changes.

- [ ] **Step 1: Run the focused startup and wallpaper/lock suite.**

Run:

```bash
scripts/run-tests.sh tst_wallpaper tst_lock tst_startup tst_bar_content_startup \
    tst_wallpaper_startup_slots --no-python
```

Expected: all matching QtTest and root harnesses pass; window-only harnesses remain skipped by the offscreen runner.

- [ ] **Step 2: Run the full headless suite and Python tests.**

Run:

```bash
scripts/run-tests.sh --no-python
python3 -m pytest scripts/tests/ -q
```

Expected: zero failures. Record any unrelated flaky baseline separately and do not weaken startup assertions to accommodate it.

- [ ] **Step 3: Run qmllint over every touched QML/JS file.**

Run:

```bash
/usr/lib/qt6/bin/qmllint shell.qml \
    modules/lazerbar/WallpaperReveal.qml modules/lazerbar/WallpaperBackground.qml \
    modules/lock/Lock.qml modules/lock/LockSurface.qml \
    modules/bar/BarContent.qml modules/bar/TopBar.qml \
    services/ColorService.qml services/RipplePulseService.qml \
    tst_bar_content_startup.qml tst_wallpaper_startup_slots.qml
```

Expected: no new `error` diagnostics. Existing unqualified-access warnings may remain if they were present before the task.

- [ ] **Step 4: Review the diff for startup/manual separation.**

Check explicitly that:

1. `LockModule.Lock` is still root-mounted.
2. Startup `backgroundModeFor(..., true)` still returns `wallpaper`.
3. Manual `lock()` still uses configured mode and screenshot preparation.
4. Live wallpaper switches still preserve old slot until incoming pixels are ready.
5. No top-level `PanelWindow` dimension is animated by a startup batch or reveal progress.
6. No unconditional startup debug log or absolute wallpaper path is introduced.

- [ ] **Step 5: Perform the manual Niri-session check only with user approval.**

Use the existing real-session workflow, not automation, and verify the seven live-session criteria in the design spec: stable lock floor, smooth wallpaper reveal, bar batch completion, delayed lock wave, ready desktop after unlock, unchanged manual switch/lock behavior, and no startup-only glow pulse. If temporary `AFLOAT_STARTUP_TRACE=1` instrumentation is used, remove unconditionally printed probes before committing.

- [ ] **Step 6: Commit only if the implementation is complete and green.**

```bash
git status --short
git diff --check
git add modules/lazerbar/StartupRevealLogic.js \
    modules/lazerbar/WallpaperSlotLogic.js \
    modules/lazerbar/WallpaperReveal.qml \
    modules/lazerbar/WallpaperBackground.qml \
    modules/lock/Lock.qml modules/lock/LockSurface.qml \
    modules/bar/ShippedWidgets.js modules/bar/BarContent.qml modules/bar/TopBar.qml \
    services/ColorService.qml services/RipplePulseService.qml shell.qml \
    tests/qml/tst_startup_reveal_logic.qml tests/qml/tst_wallpaper_slot_logic.qml \
    tests/qml/tst_wallpaper_reveal.qml tests/qml/tst_lock_surface_logic.qml \
    tests/qml/tst_startup_lock_logic.qml tests/qml/tst_shipped_widgets.qml \
    tst_bar_content_startup.qml tst_wallpaper_startup_slots.qml \
    tst_lock_startup_order.qml tst_color_service_reveal.qml tst_glow_pulse.qml
git commit -m "perf(startup): stage wallpaper chrome and lock reveal"
```

The final implementation commit must mention the verified root cause: startup full-screen animations and first-paint work were overlapping on the GUI/render path, and the decoded wallpaper was being synchronously handed to a second full-screen image at settle time.
