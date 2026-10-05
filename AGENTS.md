# Agent Instructions

## Project

Afloat is a Wayland desktop shell built with **Quickshell** (QML), targeting the Niri compositor. Branch `lazer`: osu!lazer-styled frontend + service layer.

## Architecture

- `shell.qml` — entrypoint. Mounts wallpaper, top bar, notification host, session lock. Must run from repo root: `qs -p /path/to/afloat`.
- `services/` — QML **singletons** (registered in `services/qmldir`, imported as `Services.*`). Pure logic lives in sibling `.js` files (e.g. `barlayout/`, `launcher/`) so it can be tested without instantiating QML.
- `modules/bar/` — layout-driven top bar (`TopBar`, `BarContent`, `widgets/`). `modules/lazerbar/` — lazer surfaces (settings panel, launcher, notifications, overlays; singletons `LazerTheme`, `MotionTokens`, `SettingsOverlayBridge` via its own `qmldir`). `modules/lock/` — session lock. `modules/shared/glsl/` — shaders.
- `scripts/` — `afloat-ipc <target> <function> [args...]` wraps `qs ipc`; Python bridges tested under `scripts/tests/`. `docs/superpowers/` — dated design-intent plans.

## Running & verifying

**Default verification: run the shell and read its log.** `scripts/check-shell.sh`
reports what went wrong since the last time you asked, grouped so the two lines
that matter are not buried under the machine's own noise:

```bash
scripts/check-shell.sh                # since last time — this is the gate
scripts/check-shell.sh --watch        # follow the live shell while you restart it
scripts/check-shell.sh --all          # the whole log
scripts/check-shell.sh --launch 20    # no shell running: start one for 20s
```

It exits non-zero when there is a QML diagnostic naming a file in this repo, or
one of our services reporting a failure, so it gates a commit the way a test run
did. It never starts a second shell over a live one — restart your own, then read.

### Do not run the test suite

**Do not run `scripts/run-tests.sh`, `scripts/qmltest.sh` or pytest to verify a
change unless the user explicitly asks for it.** Run `scripts/check-shell.sh`
instead. This is not a preference about speed — the suite is the wrong instrument
for most of this codebase:

- A desktop shell mostly fails in ways no assertion can reach. Reading the live
  log on this branch found a `NiriService` that could not write its kdl file, an
  `Image` that could not open a lock asset, and two `TypeError`s in the
  window-hint file — each recurring dozens of times, none covered by any test.
- The suite's own track record is worse than its coverage suggests: 8 files /
  113 test functions had **never executed** while being counted as coverage,
  and `tst_lazer_settings_controls` had been red on 15 of 36 functions since
  August. A red suite is evidence about the tests, not the product.
- It is disruptive by construction. Every `tests/qml/` file is its own process,
  and on a graphical platform each one maps a window and takes keyboard focus
  (measured: 1228 fcitx5 `FocusOut` in one batch).

So: shell log first, always. If a change is pure logic and you believe a test
would genuinely catch a regression, **say so and let the user decide** — offer to
run the relevant file rather than running it unprompted.

When the user does ask for the suite:

- One file: `scripts/qmltest.sh <name-substring>` (resolves under `tests/qml/`).
- Whole suite: `scripts/run-tests.sh` (~5 min; `--suite` puts the QtTest tier in
  one process, ~5x faster). `-g` also runs the window-only harnesses — ask first,
  they paint on the live desktop.
- Python bridges: `python3 -m pytest scripts/tests/`.
- Never invoke `qmltestrunner` directly; see "Never disturb the live session".

Launch: `qs -p /path/to/afloat`. IPC: `scripts/afloat-ipc <target> <function> [args...]`.
- Logic tests (pure `.js`, in `tests/qml/`) run under QtTest, which `scripts/qmltest.sh` wraps. The raw form, if you ever need it, is `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_layout.qml -o -,txt` — **and it must carry `QT_QPA_PLATFORM=offscreen`**, or it will steal keyboard focus.
  - Use the Qt6 runner path exactly — `/usr/bin/qmltestrunner` is Qt5 and fails silently. `qs -p tests/qml/tst_*.qml` runs **zero** tests (Quickshell never drives QtTest).
- Service-behavior harnesses (need Quickshell singletons) live in the **repo root**: `qs -p tst_media_binding.qml` (from repo root). Under the offscreen platform a harness that instantiates a `PanelWindow` cannot load (`No PanelWindow backend loaded`) — the runner classifies that as window-only and skips it.
- Python: `python3 -m pytest scripts/tests/`.
- **After every QML change**, run `scripts/check-shell.sh` and fix what it reports
  before finishing. Do not run the suite for this; offer it if you believe a test
  would catch something the log cannot.

## Never disturb the live session (read before running anything)

A test that maps a real window is indistinguishable, to the user, from their
shell misbehaving. Offscreen is the mechanism that prevents it: the offscreen
platform has no layer-shell backend, so a window-based harness *fails to load*
instead of painting over the desktop. Never defeat it.

**The damage is not only visual — a focused window breaks their typing.** A bare
`qmltestrunner` inherits `QT_QPA_PLATFORM=wayland` and maps a real window per
test file, which niri focuses. Measured: 1228 fcitx5 `FocusOut` against 0
`FocusIn` in a single batch, because each of ~70 window creations deactivated
the input method and discarded what was being typed. Nothing appears on screen,
which is exactly why this survived so long and looked like a random IME glitch
rather than a consequence of running the tests.

So the platform must be chosen **at the invocation site**, by
`scripts/qmltest.sh`, which refuses to run on a graphical platform and says so.
No in-QML guard can substitute: `qmltestrunner` creates the window *before* it
loads the test file, so a check inside the file's `Component.onCompleted` runs
after the damage. When you need a real surface, the answer is `qs -p` on a
window-only harness under `-g`, never QtTest.

**Off limits — never run unprompted, and never inside automation:**

| File | What it does to the live session |
| --- | --- |
| `lock-test.qml` | Mounts `Lock` and, with `AFLOAT_LOCK_SELFTEST=1`, **grabs the session lock and blacks out the screen for 5s**. Manual-only; ask the user first. |
| `tst_bar_popup_host.qml`, `tst_bar_two_layer_popup.qml`, `tst_real_volume.qml`, `tst_top_volume_half.qml` | Drive `BarPopupHost.surfaceActive` → a real full-width popup panel flashes over the bar. |
| `tst_network_visual.qml`, `tst_loading_ring_visual.qml`, `tst_loading_ring_wiring.qml`, `tst_network_popup.qml` | Declare a `PanelWindow` with an opaque background — a solid rectangle painted over the output while they run. |

These run only via `scripts/run-tests.sh -g`, which prints a warning naming each
file first. Everything else is headless-safe: the `tests/qml/` suite, the other
root `tst_*.qml` harnesses, and the ad-hoc probes (`ghost_race_harness.qml`,
`harness_media_char.qml`, `clock_scene_probe.qml`, `launcher_churn_stress.qml`,
`launcher_rewrite_stress.qml`, `launcher_launch_e2e.qml` — the last three only
write inside `/tmp/opencode/xdg-data/`, never your real desktop entries).

## Adding a test

**Default: do not add one.** A test is a permanent liability — it costs a process
spawn per run, it rots the moment the implementation moves, and a test that
cannot fail is worse than no test because it reads as coverage. The log gate
covers bindings, assets, services and compositor calls; a test only earns its
place for **pure logic** whose failure would be silent and obvious in the log.

Before writing one, answer all three. If any answer is "no", do not add it:

1. **Would this fail if the logic broke?** Name the mutation that makes it red.
   If you cannot name one, you are writing a coverage marker, not a test.
2. **Can it decide without a live compositor?** If it needs `Quickshell.*`, it
   cannot run under `tests/qml/` at all — it goes to the repo root as a `qs -p`
   harness, which cannot be verified in CI and costs seconds per run. 8 files
   and 113 functions are sitting in exactly that state right now: written,
   counted as coverage, never executed.
3. **Is the assertion about the contract, not a snapshot?** Assert the product's
   own expression (`optionListHeight`, `bodyHeight`,
   `MotionTokens.popupFromScale`), never a copied literal. Copying a constant
   desyncs silently on the next deliberate retune, and the retune reads as a
   broken test rather than a changed design.

Then, mechanically:

- Root-level `tst_*.qml` only, and only if it needs Quickshell singletons; a
  pure-logic test belongs in `tests/qml/`.
- Never give a `tests/qml/` file a `Window` root. QtTest hosts the file in a
  `QQuickView` and rejects any other root ("invalid root object"), and the
  `visible: true` you would add to make `when: windowShown` fire maps a window
  on the live desktop. Use an `Item` root sized to the viewport.
- If it instantiates `PanelWindow` / `PopupWindow` / `WlSessionLockSurface`
  (directly or transitively, e.g. via `BarPopupHost` or anything under
  `modules/lock/`), it is window-only by definition. Name it `tst_*.qml` at the
  repo root so the runner auto-classifies it, and add a line to the table above.
- Assert geometry only after it settles: a QML `TestCase` function does not run
  the event loop, so reading a property that a `Behavior` animation drives
  returns the pre-change value. Use `tryCompare` / `tryVerify` / an explicit
  `wait(MotionTokens.<duration>)`, and reset anything a test function mutates
  (a sibling test's `init()` will not do it for you).
- Run through the runner so `AFLOAT_APP_THEME_PREFIX` points at a throwaway
  prefix; without it `AppThemeService` restyles your real kitty/GTK config.
  `scripts/qmltest.sh` applies that sandbox itself, so a single-file run is
  safe on that axis too — but only if you go through it.
- **Never invoke `qmltestrunner` directly**, not even for a one-off, and not
  even inside a loop that you believe is short. Every bare invocation maps and
  steals focus, and the tell is invisible: a repeat-and-check loop is the exact
  shape that produced 1228 input-method deactivations. `scripts/qmltest.sh` is
  the only supported entry point.
- A test must be green the first time it runs. "It was red when I committed it"
  means it never executed (the suite could not load) or it was written against
  behaviour that had already changed — both are how the current
  `tst_lazer_settings_controls` debt accumulated.

## Gotchas

- QML singletons are lazy: a bare reference can be dropped without instantiating. `shell.qml` injects `LazerTheme.settingsService/colorService` and calls `Services.AppThemeService.apply()` explicitly to force instantiation — follow that pattern.
- Import blackhole: `qs -p <file>` silently empties any relative import resolving outside the config root (e.g. `../../services` from `tests/qml/`). Hence root-level harnesses for singletons, pure-JS imports only under `tests/qml/`.
- Cross-service signals fire mid-cascade while sibling bindings still hold stale values — defer consumer refreshes one event-loop turn (`Qt.callLater` / 0-interval `Timer`).
- `PanelWindow` is not an `Item`: no `Keys.*` handlers on it (inner `Item` with `focus: true` instead); size with `implicitWidth`/`implicitHeight`, not `width`/`height`.
- `QtQuick.Shapes` (every renderer, Qt 6.11) leaves a 1px **opaque white** ring on antialiased edges, so a shape mask over a transparent layer-shell surface shows a light outline. Rasterize such masks from an inline **SVG data URL** on an `Image` instead — QPainter antialiases it cleanly. Do **not** use a `Canvas` for a layer-shell mask: a canvas node caches its raster in a texture that is not rebuilt when the surface is torn down and mapped again, so the mask silently goes blank after any remap (toggling the feature off/on, a screen re-key, hiding the window) and shows whatever is underneath instead. See `modules/lazerbar/ScreenCornerMask.qml`.
- **Two surfaces in the same layer-shell layer cannot be ordered against each other by the client** — the compositor decides, and re-commits can change its mind. Mounting a surface "last" is not a z-order guarantee (`shell.qml` claimed exactly that for the screen bezel, and it was wrong: the bar won, and its translucent fill washed the bezel out to a light tint). Any decoration overlapping a sibling surface must be painted **by the surface that owns that region**; never let two surfaces both paint the same pixels. The bezel splits its four corners this way (`ScreenCornerMask.corners` plus `barCornerMask`/`barFreeCornerMask`): the bar paints the corners it physically covers, the bezel surface paints the remaining two. When a radius is shared across two hosts, clamp it against the *screen* extent rather than the host window's, or a short host (the bar is a 48px strip) silently caps it at half its own height.
- Qt 6.11 effect stack, verified on this machine (Qt 6.11.2 / Mesa / radeonsi): inline GLSL in `ShaderEffect` **no longer compiles** (its `vertexShader`/`fragmentShader` are now `.qsb` URLs, so every inline shader reports `status === Error`), and `MultiEffect`'s mask/blur passes drop the source or render nothing. `Qt5Compat.GraphicalEffects.OpacityMask` (rounded-rect mask source) is the one that works — see `modules/lazerbar/WallpaperReveal.qml`. Its edge is 1px hard; a nested blur inside a `maskSource` renders nothing.
- Full-screen images (wallpapers) exceed `QPixmapCache`'s 10 MB default, so `Image.cache: true` never produces a cache hit for them: a second request for the same source re-decodes from disk. Hand a full-screen wallpaper over with `asynchronous: false` (the assignment returns with pixels ready) or keep both layers alive and swap roles — an `asynchronous: true` reload shows whatever is underneath until the decode lands.
- Lock screen (`modules/lock/`, `LockService`): `WlSessionLockSurface` constraints — no `Repeater`, backdrop z-order, re-arm choreography. Load `session-lock-surface-constraints` skill before touching it.

## Style

- Visual language is osu!lazer "sharp": right-angled rectangles + geometric joins on major surfaces; rounded corners only on details/icons. Settings panel is the style authority — reuse its highlight/click-flash/scroll patterns and `MotionTokens` values, never invent new motion.
- Comment before major QML element declarations. Conventional commits (`feat(bar): ...`, `fix(notifications): ...`).

## Skills (`.agents/skills/`)

- Before running/writing tests: `qml-testing`. Before any visible UI change: `osu-sharp-design-language` + `settings-panel-style-authority`.
- Load others on symptom: `lazer-settings-surface-details` (settings panel edits), `submenu-surface-motion` (tray/submenu motion), `overlay-pointer-event-starvation` (lost hover), `multi-instance-focus-ownership` (input lost on reopen), `effective-visibility-cycle-debugging` (mapped but paints nothing), `reactive-measurement-layout-debugging` (clipped/drifted sizes), `quickshell-process-stdio-hazards` (a `Process` ran the wrong argv, or a handler overwrote a good result — affects every service that shells out), `per-frame-surface-resize-jank` / `reveal-before-clip` / `async-layer-sync-lag-debugging` (animation jank), `browser-media-metadata-fallback` (web-player metadata), `active-window-live-sync`, `marquee-exit-ghosts`, `first-batch-cold-path-prewarm`, `surface-owner-split-debugging`, `visual-transition-rules`, `comment-before-declarations`, `osu-lazer-ui-reference` (exact lazer colors/sizes/durations).
- Load `layer-shell-overflow-hit-testing` when a visible layer-shell popup overflows a primary column but the submenu has no hover/click response, especially when the compositor region is wide but a Qt Quick ancestor remains narrow.
- Load `startup-reveal-scheduling` before touching boot ordering, the wallpaper reveal, `MotionTokens.wallpaperBootReveal` / `wallpaperSwap`, startup gates, the launcher's `startupPrewarmAllowed`, or any boot watchdog interval.
- Load `quickshell-variants-delegate-hijack` when a surface is missing from the compositor (desktop shows the compositor's own background colour) with no error beyond one `qs:`-category `modelData` warning, and before adding any child object inside a `Variants`-rooted component or at one of its instantiation sites.
- Load `regression-proof` before claiming any bug is fixed, and after a fix "did not work". A test that copies the logic it asserts passes vacuously, one green run on a flaky suite is noise, and after two wrong root causes the answer is an instrumented reproduction rather than more source reading.
