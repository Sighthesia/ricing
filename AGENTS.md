# Agent Instructions

## Project

Afloat is a Wayland desktop shell built with **Quickshell** (QML), targeting the Niri compositor. Branch `lazer`: osu!lazer-styled frontend + service layer.

## Architecture

- `shell.qml` — entrypoint. Mounts wallpaper, top bar, notification host, session lock. Must run from repo root: `qs -p /path/to/afloat`.
- `services/` — QML **singletons** (registered in `services/qmldir`, imported as `Services.*`). Pure logic lives in sibling `.js` files (e.g. `barlayout/`, `launcher/`) so it can be tested without instantiating QML.
- `modules/bar/` — layout-driven top bar (`TopBar`, `BarContent`, `widgets/`). `modules/lazerbar/` — lazer surfaces (settings panel, launcher, notifications, overlays; singletons `LazerTheme`, `MotionTokens`, `SettingsOverlayBridge` via its own `qmldir`). `modules/lock/` — session lock. `modules/shared/glsl/` — shaders.
- `scripts/` — `afloat-ipc <target> <function> [args...]` wraps `qs ipc`; Python bridges tested under `scripts/tests/`. `docs/superpowers/` — dated design-intent plans.

## Running & testing

- Launch: `qs -p /path/to/afloat`. IPC: `scripts/afloat-ipc <target> <function> [args...]`.
- Logic tests (pure `.js`, in `tests/qml/`): `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_layout.qml -o -,txt`
  - Use the Qt6 runner path exactly — `/usr/bin/qmltestrunner` is Qt5 and fails silently. `qs -p tests/qml/tst_*.qml` runs **zero** tests (Quickshell never drives QtTest).
- Service-behavior harnesses (need Quickshell singletons) live in the **repo root**: `qs -p tst_media_binding.qml` (from repo root).
- Python: `python3 -m pytest scripts/tests/`.
- **After every QML change**, run the relevant test file(s) and fix WARN/ERROR output before finishing.

## Gotchas

- QML singletons are lazy: a bare reference can be dropped without instantiating. `shell.qml` injects `LazerTheme.settingsService/colorService` and calls `Services.AppThemeService.apply()` explicitly to force instantiation — follow that pattern.
- Import blackhole: `qs -p <file>` silently empties any relative import resolving outside the config root (e.g. `../../services` from `tests/qml/`). Hence root-level harnesses for singletons, pure-JS imports only under `tests/qml/`.
- Cross-service signals fire mid-cascade while sibling bindings still hold stale values — defer consumer refreshes one event-loop turn (`Qt.callLater` / 0-interval `Timer`).
- `PanelWindow` is not an `Item`: no `Keys.*` handlers on it (inner `Item` with `focus: true` instead); size with `implicitWidth`/`implicitHeight`, not `width`/`height`.
- Lock screen (`modules/lock/`, `LockService`): `WlSessionLockSurface` constraints — no `Repeater`, backdrop z-order, re-arm choreography. Load `session-lock-surface-constraints` skill before touching it.

## Style

- Visual language is osu!lazer "sharp": right-angled rectangles + geometric joins on major surfaces; rounded corners only on details/icons. Settings panel is the style authority — reuse its highlight/click-flash/scroll patterns and `MotionTokens` values, never invent new motion.
- Comment before major QML element declarations. Conventional commits (`feat(bar): ...`, `fix(notifications): ...`).

## Skills (`.agents/skills/`)

- Before running/writing tests: `qml-testing`. Before any visible UI change: `osu-sharp-design-language` + `settings-panel-style-authority`.
- Load others on symptom: `lazer-settings-surface-details` (settings panel edits), `submenu-surface-motion` (tray/submenu motion), `overlay-pointer-event-starvation` (lost hover), `multi-instance-focus-ownership` (input lost on reopen), `effective-visibility-cycle-debugging` (mapped but paints nothing), `reactive-measurement-layout-debugging` (clipped/drifted sizes), `per-frame-surface-resize-jank` / `reveal-before-clip` / `async-layer-sync-lag-debugging` (animation jank), `browser-media-metadata-fallback` (web-player metadata), `active-window-live-sync`, `marquee-exit-ghosts`, `first-batch-cold-path-prewarm`, `surface-owner-split-debugging`, `visual-transition-rules`, `comment-before-declarations`, `osu-lazer-ui-reference` (exact lazer colors/sizes/durations).
