# Agent Instructions

## Project

Afloat is a Wayland desktop shell built with **Quickshell** (QML-based compositor shell framework).

This branch (`backend-only`) contains only the **backend** layer — services, scripts, and backend tests. The **frontend** (`modules/`, `shell.qml`) was intentionally removed to enable a clean frontend rewrite. Rebuild the UI surface modules against the services below.

## Architecture

- `services/` — **singleton QML services** (registered in `services/qmldir`). All services are `singleton` types imported as `Services.*`. Key ones: `IslandService`, `BarLayoutService`, `SettingsService`, `ColorService`, `NiriService`, `VolumeService`, `MediaService`, `WindowHintService`.
- `services/barlayout/` — bar layout JS modules (sections, persistence, drag, model)
- `scripts/` — Python helpers: `afloat-ipc` (IPC via `qs ipc`), `netease_web_lyrics_bridge.py`, `theming/`, `window_hint_trigger.py`
- `tests/qml/` — backend QML tests (`QtTest.TestCase`), run per test file

## Running

- Quickshell launches this config: `qs -p /path/to/afloat` (or symlink)
- IPC calls: `scripts/afloat-ipc <target> <function> [args...]`
- QML tests: run individual test files via `qs -p tests/qml/tst_*.qml`
- **After every QML change**, run the relevant backend tests and fix any WARN/ERROR lines before considering the task done.

## Conventions

- Every service in `services/` is a **QML singleton** declared in `services/qmldir`. Do not instantiate them; import and reference directly.
- Modules use `Variants { model: Quickshell.screens }` to create per-screen window instances.
- Panel windows use `Quickshell.Wayland` (`WlrLayershell`, `WlrKeyboardFocus`) for layer-shell integration.
- **PanelWindow is not a QML Item** — do not attach `Keys.*` handlers directly; put them on an inner `Item`/`Rectangle` with `focus: true`.
- **PanelWindow with WlrLayershell**: use `implicitWidth`/`implicitHeight`, not `width`/`height` (the latter triggers deprecation warnings).
- JS helper files (`.js`) in services and modules contain pure logic extracted from QML for testability.
- Comment before major QML element declarations (see skill below).

## Skills

Load these for detailed context on specific topics:

| Skill                                                                                                  | When to use                                                                                                                                                                                                                                                              |
| ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [visual-transition-rules](.agents/skills/visual-transition-rules/SKILL.md)                             | Adjusting QML visual styles, colors, radii, opacity, blur, shadows, spacing, scale.                                                                                                                                                                                      |
| [comment-before-declarations](.agents/skills/comment-before-declarations/SKILL.md)                     | Editing QML modules that should stay self-documenting.                                                                                                                                                                                                                   |
| [reactive-measurement-layout-debugging](.agents/skills/reactive-measurement-layout-debugging/SKILL.md) | Diagnosing layout bugs where measured, preferred, target, actual, or clipped sizes diverge.                                                                                                                                                                              |
| [surface-owner-split-debugging](.agents/skills/surface-owner-split-debugging/SKILL.md)                 | Debugging regressions after moving a UI surface's visible owner (hover, editing, content, geometry ownership).                                                                                                                                                           |
| [async-layer-sync-lag-debugging](.agents/skills/async-layer-sync-lag-debugging/SKILL.md)               | A secondary layer on an async/coalesced commit path (compositor blur/mask region, cached copy) lags, stutters, overflows, or pops behind a per-frame main layer during fast animations.                                                                                  |
| [overlay-pointer-event-starvation](.agents/skills/overlay-pointer-event-starvation/SKILL.md)           | An inner/lower element stops getting hover/pointer events (no hover, hover popup never opens, or popup flickers open/closed) because an overlapping upper element or fullscreen overlay consumes them.                                                                   |
| [multi-instance-focus-ownership](.agents/skills/multi-instance-focus-ownership/SKILL.md)               | A text field or editable control works on first open but stops accepting keyboard input on reopen, page switch, or second mount because multiple live instances or wrapper/child hooks compete for focus ownership.                                                      |
| [per-frame-surface-resize-jank](.agents/skills/per-frame-surface-resize-jank/SKILL.md)                 | An expand/collapse animation stutters because a per-frame size drives an expensive commit boundary (top-level/layer-shell window resize, compositor region, or per-frame model rebuild). Fix: fixed outer surface, animate clipped inner content.                        |
| [reveal-before-clip](.agents/skills/reveal-before-clip/SKILL.md)                                       | When content inside an expanding/contracting surface (dockzone, island, drawer, menu) overflows or reads as harshly cut during the host's grow/shrink. Drive content reveal (opacity, slide, anchor edge) from the host's reveal progress before relying on a clip mask. |
