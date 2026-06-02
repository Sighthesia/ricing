# Agent Instructions

## Project

Afloat is a Wayland desktop shell built with **Quickshell** (QML-based compositor shell framework). Entry point: `shell.qml`.

## Architecture

- `shell.qml` — root `ShellRoot` that instantiates all window surfaces
- `modules/` — UI surface modules, each owning one `PanelWindow` type:
  - `bar/` — top status bar, widget system, dockzone surfaces, context menu, widget picker
  - `island/` — dynamic island (collapsed clock + expanded launcher)
  - `background/` — wallpaper and screen-corner overlays
  - `launcher/` — full-screen app launcher overlay
  - `notification/` — transient notification popups
  - `osd/` — volume/brightness/media OSD popup
  - `settings/` — settings panel popup
  - `workspace-hint/` — workspace/window hint OSD (mod-key held)
- `services/` — **singleton QML services** (registered in `services/qmldir`). All services are `singleton` types imported as `Services.*`. Key ones: `IslandService`, `BarLayoutService`, `SettingsService`, `ColorService`, `NiriService`, `VolumeService`, `MediaService`, `WindowHintService`.
- `services/barlayout/` — bar layout JS modules (sections, persistence, drag, model)
- `scripts/` — Python helpers: `afloat-ipc` (IPC via `qs ipc`), `netease_web_lyrics_bridge.py`, `theming/`, `window_hint_trigger.py`

## Running

- Quickshell launches this config: `qs -p /path/to/afloat` (or symlink)
- IPC calls: `scripts/afloat-ipc <target> <function> [args...]`
- QML tests: `qs -p tests/qml` or individual test files via `QtTest.TestCase`
- **After every QML change**, run `timeout 5 qs -p .` and fix any WARN/ERROR lines before considering the task done.

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

| Skill | When to use |
|---|---|
| [glass-liquid-design](.agents/skills/glass-liquid-design/SKILL.md) | Designing or modifying visible QML surfaces, motion, states, or interaction feedback. **This is the project's visual language — load it before any UI work.** |
| [visual-transition-rules](.agents/skills/visual-transition-rules/SKILL.md) | Adjusting QML visual styles, colors, radii, opacity, blur, shadows, spacing, scale. |
| [comment-before-declarations](.agents/skills/comment-before-declarations/SKILL.md) | Editing QML modules that should stay self-documenting. |
| [reactive-measurement-layout-debugging](.agents/skills/reactive-measurement-layout-debugging/SKILL.md) | Diagnosing layout bugs where measured, preferred, target, actual, or clipped sizes diverge. |
| [surface-owner-split-debugging](.agents/skills/surface-owner-split-debugging/SKILL.md) | Debugging regressions after moving a UI surface's visible owner (hover, editing, content, geometry ownership). |
| [async-layer-sync-lag-debugging](.agents/skills/async-layer-sync-lag-debugging/SKILL.md) | A secondary layer on an async/coalesced commit path (compositor blur/mask region, cached copy) lags, stutters, overflows, or pops behind a per-frame main layer during fast animations. |
| [overlay-pointer-event-starvation](.agents/skills/overlay-pointer-event-starvation/SKILL.md) | An inner/lower element stops getting hover/pointer events (no hover, hover popup never opens, or popup flickers open/closed) because an overlapping upper element or fullscreen overlay consumes them. |
| [per-frame-surface-resize-jank](.agents/skills/per-frame-surface-resize-jank/SKILL.md) | An expand/collapse animation stutters because a per-frame size drives an expensive commit boundary (top-level/layer-shell window resize, compositor region, or per-frame model rebuild). Fix: fixed outer surface, animate clipped inner content. |
| [reveal-before-clip](.agents/skills/reveal-before-clip/SKILL.md) | Content inside an expanding/contracting surface overflows or reads as harshly cut during the host's grow/shrink. Drive content reveal (opacity, slide, anchor edge) from the host's reveal progress before relying on a clip mask. |

## Workflow Runtime

This repo includes a just-demand/OpenCode workflow runtime for managing formal tasks:

- Workflow scripts: `.just-demand/scripts/workflow_core.py`
- Task CLI: `python3 .just-demand/scripts/workflow_core.py --root . <command>`
- Workflow skills: `.opencode/skills/just-demand-*` and `.opencode/skills/socratic-clarification`
- Restart OpenCode after changing `.opencode/plugins/`, `.opencode/agent/`, `.opencode/skills/`, or `.opencode/package.json`.

## Git

- Do not commit: `__pycache__/`, `.pyc`, `.pytest_cache/`, `.opencode/node_modules/`, `.cocoindex_code/`
- `.agent-workflow/` state files and `.just-demand/state/` are gitignored.
