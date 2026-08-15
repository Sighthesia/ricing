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
| [glass-liquid-design](.agents/skills/glass-liquid-design/SKILL.md)                                     | Designing or modifying visible QML surfaces, motion, states, or interaction feedback. **This is the project's visual language — load it before any UI work.**                                                                                                            |
| [visual-transition-rules](.agents/skills/visual-transition-rules/SKILL.md)                             | Adjusting QML visual styles, colors, radii, opacity, blur, shadows, spacing, scale.                                                                                                                                                                                      |
| [comment-before-declarations](.agents/skills/comment-before-declarations/SKILL.md)                     | Editing QML modules that should stay self-documenting.                                                                                                                                                                                                                   |
| [reactive-measurement-layout-debugging](.agents/skills/reactive-measurement-layout-debugging/SKILL.md) | Diagnosing layout bugs where measured, preferred, target, actual, or clipped sizes diverge.                                                                                                                                                                              |
| [surface-owner-split-debugging](.agents/skills/surface-owner-split-debugging/SKILL.md)                 | Debugging regressions after moving a UI surface's visible owner (hover, editing, content, geometry ownership).                                                                                                                                                           |
| [async-layer-sync-lag-debugging](.agents/skills/async-layer-sync-lag-debugging/SKILL.md)               | A secondary layer on an async/coalesced commit path (compositor blur/mask region, cached copy) lags, stutters, overflows, or pops behind a per-frame main layer during fast animations.                                                                                  |
| [overlay-pointer-event-starvation](.agents/skills/overlay-pointer-event-starvation/SKILL.md)           | An inner/lower element stops getting hover/pointer events (no hover, hover popup never opens, or popup flickers open/closed) because an overlapping upper element or fullscreen overlay consumes them.                                                                   |
| [multi-instance-focus-ownership](.agents/skills/multi-instance-focus-ownership/SKILL.md)               | A text field or editable control works on first open but stops accepting keyboard input on reopen, page switch, or second mount because multiple live instances or wrapper/child hooks compete for focus ownership.                                                       |
| [per-frame-surface-resize-jank](.agents/skills/per-frame-surface-resize-jank/SKILL.md)                 | An expand/collapse animation stutters because a per-frame size drives an expensive commit boundary (top-level/layer-shell window resize, compositor region, or per-frame model rebuild). Fix: fixed outer surface, animate clipped inner content.                        |
| [reveal-before-clip](.agents/skills/reveal-before-clip/SKILL.md)                                       | When content inside an expanding/contracting surface (dockzone, island, drawer, menu) overflows or reads as harshly cut during the host's grow/shrink. Drive content reveal (opacity, slide, anchor edge) from the host's reveal progress before relying on a clip mask. |
<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer)
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using Codex or another agent-capable tool, additional project-scoped helpers may live in:
- `.agents/skills/` — reusable Trellis skills
- `.codex/agents/` — optional custom subagents

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->
