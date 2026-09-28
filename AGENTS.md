# Agent Instructions

## Project

Afloat is a Wayland desktop shell built with **Quickshell** (QML), targeting the Niri compositor. Branch `lazer`: osu!lazer-styled frontend + service layer.

## Architecture

- `shell.qml` — entrypoint. Mounts wallpaper, top bar, notification host, session lock. Must run from repo root: `qs -p /path/to/afloat`.
- `services/` — QML **singletons** (registered in `services/qmldir`, imported as `Services.*`). Pure logic lives in sibling `.js` files (e.g. `barlayout/`, `launcher/`) so it can be tested without instantiating QML.
- `modules/bar/` — layout-driven top bar (`TopBar`, `BarContent`, `widgets/`). `modules/lazerbar/` — lazer surfaces (settings panel, launcher, notifications, overlays; singletons `LazerTheme`, `MotionTokens`, `SettingsOverlayBridge` via its own `qmldir`). `modules/lock/` — session lock. `modules/shared/glsl/` — shaders.
- `scripts/` — `afloat-ipc <target> <function> [args...]` wraps `qs ipc`; Python bridges tested under `scripts/tests/`. `docs/superpowers/` — dated design-intent plans.

## Running & testing

- **Run everything through `scripts/run-tests.sh`** — it defaults to the offscreen platform, so a test run never maps a window over the live desktop. `scripts/run-tests.sh <name-substring>…` filters, `--no-python` skips pytest, `-g` additionally runs the window-based harnesses (they will flash real windows — only when explicitly asked).
- Launch: `qs -p /path/to/afloat`. IPC: `scripts/afloat-ipc <target> <function> [args...]`.
- Logic tests (pure `.js`, in `tests/qml/`) run under QtTest: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_layout.qml -o -,txt`
  - Use the Qt6 runner path exactly — `/usr/bin/qmltestrunner` is Qt5 and fails silently. `qs -p tests/qml/tst_*.qml` runs **zero** tests (Quickshell never drives QtTest).
- Service-behavior harnesses (need Quickshell singletons) live in the **repo root**: `qs -p tst_media_binding.qml` (from repo root). Under the offscreen platform a harness that instantiates a `PanelWindow` cannot load (`No PanelWindow backend loaded`) — the runner classifies that as window-only and skips it.
- Python: `python3 -m pytest scripts/tests/`.
- **After every QML change**, run the relevant test file(s) and fix WARN/ERROR output before finishing.

## Never disturb the live session (read before running anything)

A test that maps a real window is indistinguishable, to the user, from their
shell misbehaving. Offscreen is the mechanism that prevents it: the offscreen
platform has no layer-shell backend, so a window-based harness *fails to load*
instead of painting over the desktop. Never defeat it.

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

Rules when **adding** a test:

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
- Qt 6.11 effect stack, verified on this machine (Qt 6.11.2 / Mesa / radeonsi): inline GLSL in `ShaderEffect` **no longer compiles** (its `vertexShader`/`fragmentShader` are now `.qsb` URLs, so every inline shader reports `status === Error`), and `MultiEffect`'s mask/blur passes drop the source or render nothing. `Qt5Compat.GraphicalEffects.OpacityMask` (rounded-rect mask source) is the one that works — see `modules/lazerbar/WallpaperReveal.qml`. Its edge is 1px hard; a nested blur inside a `maskSource` renders nothing.
- Full-screen images (wallpapers) exceed `QPixmapCache`'s 10 MB default, so `Image.cache: true` never produces a cache hit for them: a second request for the same source re-decodes from disk. Hand a full-screen wallpaper over with `asynchronous: false` (the assignment returns with pixels ready) or keep both layers alive and swap roles — an `asynchronous: true` reload shows whatever is underneath until the decode lands.
- Lock screen (`modules/lock/`, `LockService`): `WlSessionLockSurface` constraints — no `Repeater`, backdrop z-order, re-arm choreography. Load `session-lock-surface-constraints` skill before touching it.

## Style

- Visual language is osu!lazer "sharp": right-angled rectangles + geometric joins on major surfaces; rounded corners only on details/icons. Settings panel is the style authority — reuse its highlight/click-flash/scroll patterns and `MotionTokens` values, never invent new motion.
- Comment before major QML element declarations. Conventional commits (`feat(bar): ...`, `fix(notifications): ...`).

## Skills (`.agents/skills/`)

- Before running/writing tests: `qml-testing`. Before any visible UI change: `osu-sharp-design-language` + `settings-panel-style-authority`.
- Load others on symptom: `lazer-settings-surface-details` (settings panel edits), `submenu-surface-motion` (tray/submenu motion), `overlay-pointer-event-starvation` (lost hover), `multi-instance-focus-ownership` (input lost on reopen), `effective-visibility-cycle-debugging` (mapped but paints nothing), `reactive-measurement-layout-debugging` (clipped/drifted sizes), `quickshell-process-stdio-hazards` (a `Process` ran the wrong argv, or a handler overwrote a good result — affects every service that shells out), `per-frame-surface-resize-jank` / `reveal-before-clip` / `async-layer-sync-lag-debugging` (animation jank), `browser-media-metadata-fallback` (web-player metadata), `active-window-live-sync`, `marquee-exit-ghosts`, `first-batch-cold-path-prewarm`, `surface-owner-split-debugging`, `visual-transition-rules`, `comment-before-declarations`, `osu-lazer-ui-reference` (exact lazer colors/sizes/durations).
