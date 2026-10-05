# Agent Instructions

## Project

Afloat is a Wayland desktop shell built with **Quickshell** (QML), targeting the Niri compositor. Branch `lazer`: osu!lazer-styled frontend + service layer.

## Architecture

- `shell.qml` — entrypoint. Mounts wallpaper, top bar, notification host, session lock. Must run from repo root: `qs -p /path/to/afloat`.
- `services/` — QML **singletons** (registered in `services/qmldir`, imported as `Services.*`). Pure logic lives in sibling `.js` files (e.g. `barlayout/`, `launcher/`) so it can be read and reasoned about without instantiating QML.
- `modules/bar/` — layout-driven top bar (`TopBar`, `BarContent`, `widgets/`). `modules/lazerbar/` — lazer surfaces (settings panel, launcher, notifications, overlays; singletons `LazerTheme`, `MotionTokens`, `SettingsOverlayBridge` via its own `qmldir`). `modules/lock/` — session lock. `modules/shared/glsl/` — shaders.
- `scripts/` — `afloat-ipc <target> <function> [args...]` wraps `qs ipc`; `check-shell.sh` is the verification gate. `docs/superpowers/` — dated design-intent plans.

## Running & verifying

### Do not test unless it is necessary

**Do not write, run, or restore automated tests on your own initiative.** Verify
by running the shell and reading its log. Treat "add a test for it" as something
to raise with the user, not something to do.

A desktop shell breaks in ways assertions do not reach: a null binding, an asset
that will not open, a service that silently fails to write its config. The live
log shows all three on demand; a test only ever covers what someone already
suspected. The suite that used to live here had stopped being able to report on
its own honesty — 8 files and 113 functions had never executed while being
counted as coverage, and one file sat red on 15 of 36 functions for months
without anyone noticing. Meanwhile `check-shell.sh` surfaced a kdl file that was
never written, an image that could not open, and an invalid alias reference, none
of which any test would have caught.

So the burden of proof is on the test, not on the change: if you think a
regression is possible and the log cannot show it, say so and let the user decide
whether to spend a test on it. Reading the code and watching the surface is the
job.

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
one of our services reporting a failure, so it gates a commit. It never starts a
second shell over a live one — restart your own, then read.

Launch: `qs -p /path/to/afloat`. IPC: `scripts/afloat-ipc <target> <function> [args...]`.
`lock-test.qml` is a product self-test, not part of any framework: with
`AFLOAT_LOCK_SELFTEST=1` it mounts `Lock` for real, grabs the session lock and
blacks out the screen for 5s. Manual only — ask the user first, and never run it
inside automation.

- **After every QML change**, restart the shell (or let the user) and run
  `scripts/check-shell.sh`; fix everything it reports before finishing.
- Read the log rather than the symptom: a missing asset, a null binding and a
  failed service write all look identical from the outside, and each one repeats
  silently until someone reads the log.

## Never disturb the live session

Anything an agent runs that maps a surface is indistinguishable, to the user,
from their shell misbehaving. Two rules follow:

- **Never start a second shell over a live one.** Two instances paint two bars
  and two wallpapers, and the session lock belongs to one of them. Restart the
  user's shell, or use `scripts/check-shell.sh --launch` only when none is
  running (it refuses otherwise).
- **`lock-test.qml` with `AFLOAT_LOCK_SELFTEST=1` grabs the session lock and
  blacks out the screen for 5s.** Manual only, ask first, never in automation.

The lesson from the deleted suite is worth keeping: a focused window is not just
ugly, it breaks typing. One test run produced 1228 fcitx5 `FocusOut` against 0
`FocusIn`, because each window it created deactivated the input method and threw
away what was being typed — with nothing on screen to explain it. If you ever
reintroduce an automated runner, it must set `QT_QPA_PLATFORM=offscreen` at the
invocation site, because the platform cannot be chosen from inside the QML it
loads.

## Gotchas

- QML singletons are lazy: a bare reference can be dropped without instantiating. `shell.qml` injects `LazerTheme.settingsService/colorService` and calls `Services.AppThemeService.apply()` explicitly to force instantiation — follow that pattern.
- Import blackhole: `qs -p <file>` silently empties any relative import that resolves outside the config root. A scratch file placed in a subdirectory and importing `../../services` loads with no error and no service. Put throwaway QML at the repo root.
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

- Before any visible UI change: `osu-sharp-design-language` + `settings-panel-style-authority`.
- Load others on symptom: `lazer-settings-surface-details` (settings panel edits), `submenu-surface-motion` (tray/submenu motion), `overlay-pointer-event-starvation` (lost hover), `multi-instance-focus-ownership` (input lost on reopen), `effective-visibility-cycle-debugging` (mapped but paints nothing), `reactive-measurement-layout-debugging` (clipped/drifted sizes), `quickshell-process-stdio-hazards` (a `Process` ran the wrong argv, or a handler overwrote a good result — affects every service that shells out), `per-frame-surface-resize-jank` / `reveal-before-clip` / `async-layer-sync-lag-debugging` (animation jank), `browser-media-metadata-fallback` (web-player metadata), `active-window-live-sync`, `marquee-exit-ghosts`, `first-batch-cold-path-prewarm`, `surface-owner-split-debugging`, `visual-transition-rules`, `comment-before-declarations`, `osu-lazer-ui-reference` (exact lazer colors/sizes/durations).
- Load `layer-shell-overflow-hit-testing` when a visible layer-shell popup overflows a primary column but the submenu has no hover/click response, especially when the compositor region is wide but a Qt Quick ancestor remains narrow.
- Load `startup-reveal-scheduling` before touching boot ordering, the wallpaper reveal, `MotionTokens.wallpaperBootReveal` / `wallpaperSwap`, startup gates, the launcher's `startupPrewarmAllowed`, or any boot watchdog interval.
- Load `quickshell-variants-delegate-hijack` when a surface is missing from the compositor (desktop shows the compositor's own background colour) with no error beyond one `qs:`-category `modelData` warning, and before adding any child object inside a `Variants`-rooted component or at one of its instantiation sites.
- Load `regression-proof` before claiming any bug is fixed, and after a fix "did not work". A checker that cannot fail passes vacuously, one clean log read on a flaky surface is noise, and after two wrong root causes the answer is an instrumented reproduction rather than more source reading.
