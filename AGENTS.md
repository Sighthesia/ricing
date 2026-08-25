# Agent Instructions

## Project

Afloat is a Wayland desktop shell built with **Quickshell** (QML-based compositor shell framework), targeting the Niri compositor. The working branch (`lazer`) contains the full shell: an osu!lazer-styled frontend plus the service/backend layer.

## Architecture

- `shell.qml` — entrypoint. Mounts wallpaper background, top bar, and notification host via `Variants { model: Quickshell.screens }` per-screen instances.
- `services/` — **singleton QML services** (registered in `services/qmldir`), imported as `Services.*`. Key ones: `IslandService`, `BarLayoutService`, `SettingsService`, `ColorService`, `NiriService`, `VolumeService`, `MediaService`, `LauncherService`, `NotificationService`, `WindowHintService`.
  - Pure logic lives in sibling `.js` files (e.g. `barlayout/`, `launcher/`, `LauncherLogic.js`) for testability without instantiating QML.
- `modules/bar/` — layout-driven top bar (`TopBar`, `BarContent`) and per-widget components in `widgets/`.
- `modules/lazerbar/` — osu!lazer-styled surfaces: settings panel (`LazerSettings*`), launcher page, notifications, fullscreen overlay/music pages. Shared singletons here: `LazerTheme`, `MotionTokens`, `SettingsOverlayBridge` (see its `qmldir`).
- `modules/shared/glsl/` — shader sources.
- `scripts/` — Python/shell helpers: `afloat-ipc` (IPC wrapper around `qs ipc -p <config> call <target> <function>`), `netease_web_lyrics_bridge.py` + `beat_tracker_bridge.py` (tested under `scripts/tests/`, run with `pytest`), `theming/`, `tampermonkey/`, `window_hint_trigger.py`.
- `tests/qml/` — QML tests (`TestCase` from QtTest), one file per unit, importing service `.js` logic directly via relative paths.
- `docs/superpowers/` — implementation plans and specs (dated); consult for design intent of existing features.

## Running

- Launch config: `qs -p /path/to/afloat` (or symlink).
- IPC: `scripts/afloat-ipc <target> <function> [args...]`
- Tests run **per file** — there is no test runner aggregate:
  `qs -p tests/qml/tst_bar_layout.qml`
- **After every QML change**, run the relevant test files and fix any WARN/ERROR output before considering the task done.

## Conventions

- Every service in `services/` is a **QML singleton** declared in `services/qmldir`. Do not instantiate them; import and reference directly. New services must be registered there.
- Modules use `Variants { model: Quickshell.screens }` to create per-screen window instances.
- Panel windows use `Quickshell.Wayland` (`WlrLayershell`, `WlrKeyboardFocus`) for layer-shell integration.
- **PanelWindow is not a QML Item** — do not attach `Keys.*` handlers directly; put them on an inner `Item`/`Rectangle` with `focus: true`.
- **PanelWindow sizing**: use `implicitWidth`/`implicitHeight`, not `width`/`height` (the latter triggers deprecation warnings).
- Comment before major QML element declarations (see skill below).
- Commit style: conventional commits (`feat(bar): ...`, `fix(notifications): ...`).

## Visual language

The visual language is osu!lazer "sharp": major surfaces use right-angled rectangles and geometric joins (triangles/diamonds/rect strips); rounded corners belong only to component details and icons. The **settings panel is the style authority** — reuse its verified highlight/click-flash/scroll patterns and `MotionTokens` values rather than inventing new motion or feedback styles.

## Skills

Load these for detailed context on specific topics:

| Skill | When to use |
| --- | --- |
| [osu-sharp-design-language](.agents/skills/osu-sharp-design-language/SKILL.md) | Creating or reshaping any visible QML element. Load before adding any new UI shape. |
| [osu-lazer-ui-reference](.agents/skills/osu-lazer-ui-reference/SKILL.md) | Needing lazer's exact colors, font sizes, durations, or easing values; styling buttons/sliders/text fields/menus to lazer spec. |
| [settings-panel-style-authority](.agents/skills/settings-panel-style-authority/SKILL.md) | Any new visible surface, interaction feedback, scrolling, or motion. Reuse the settings panel's verified patterns first. |
| [lazer-settings-surface-details](.agents/skills/lazer-settings-surface-details/SKILL.md) | Modifying the lazer settings panel, rows, controls, hover/press/motion behavior. Preserves geometry, z-order, input isolation, slide transition contracts. |
| [visual-transition-rules](.agents/skills/visual-transition-rules/SKILL.md) | Adjusting colors, radii, opacity, blur, shadows, spacing, scale. |
| [comment-before-declarations](.agents/skills/comment-before-declarations/SKILL.md) | Editing QML modules that should stay self-documenting. |
| [reactive-measurement-layout-debugging](.agents/skills/reactive-measurement-layout-debugging/SKILL.md) | Layout bugs where measured/preferred/target/actual/clipped sizes diverge. |
| [surface-owner-split-debugging](.agents/skills/surface-owner-split-debugging/SKILL.md) | Regressions after moving a surface's visible owner (hover, editing, content, geometry). |
| [async-layer-sync-lag-debugging](.agents/skills/async-layer-sync-lag-debugging/SKILL.md) | Secondary async/coalesced layer lags behind per-frame main layer during fast animations. |
| [overlay-pointer-event-starvation](.agents/skills/overlay-pointer-event-starvation/SKILL.md) | Inner/lower element stops getting hover/pointer events due to overlapping upper element. |
| [multi-instance-focus-ownership](.agents/skills/multi-instance-focus-ownership/SKILL.md) | Text field works on first open but loses keyboard input on reopen/page switch. |
| [per-frame-surface-resize-jank](.agents/skills/per-frame-surface-resize-jank/SKILL.md) | Expand/collapse stutters because per-frame size hits an expensive commit boundary. Fix: fixed outer surface, animate clipped inner content. |
| [reveal-before-clip](.agents/skills/reveal-before-clip/SKILL.md) | Content inside an expanding surface overflows during grow/shrink. Drive reveal from host progress before clip masks. |
| [browser-media-metadata-fallback](.agents/skills/browser-media-metadata-fallback/SKILL.md) | Web-player (Firefox/Chrome) MPRIS metadata is incomplete, delayed, or churns; lyrics/artwork flicker or vanish. |
| [first-batch-cold-path-prewarm](.agents/skills/first-batch-cold-path-prewarm/SKILL.md) | Search/picker/results list stutters only on the first large match or open, smooth afterwards. |
| [submenu-surface-motion](.agents/skills/submenu-surface-motion/SKILL.md) | Tray menu (BarTrayMenu), submenu panels, or popup deform/retract/morph motion. Preserves occlusion-based reveal, ease-in retract with data retention, visibility-gated morphs. |
