# DymicShell Agent Guide

**DymicShell** is a Quickshell-based Wayland shell.

## Commands

- Run the shell with `qs`.
- Full-shell validation: `timeout 5 qs --path .`
- No repo-local `npm`, `pnpm`, `yarn`, `make`, `just`, `pytest`, `qmllint`, or `qmlformat` command is verified here; do not invent one.

## Structure

- `shell.qml` is the boot entrypoint; keep it to top-level window wiring.
- `modules/` renders UI; `services/` owns shared state, persistence, compositor/process integration, and layout logic.
- `modules/bar/BarContent.qml` is the bar composition root.
- `services/BarLayoutService.qml` is the bar-layout facade; most layout logic lives in `services/barlayout/*.js`.
- `config/Theme.qml`, `config/Colors.qml`, and `config/settings-default.json` are derived/shared inputs; prefer them over hardcoded sizes, colors, and defaults.
- `matugen/config.toml` and `services/WallpaperService.qml` own wallpaper-driven theming.
- `scripts/tampermonkey/netease-web-lyrics.user.js` is the persistent NetEase lyrics path; `scripts/firefox-extensions/netease-web-lyrics/README.md` documents the temporary Firefox fallback.

## Workflow

- Keep runtime writes under `.cache/DymicShell/`.
- When adding or renaming a setting, update both `config/settings-default.json` and `services/SettingsService.qml`.
- `config/Colors.qml` watches `~/.local/state/quickshell/user/generated/colors.json`.
- Prefer the repo-owned matugen config over the user’s global matugen setup.

## QML

- Add a short English comment immediately before each QML element declaration.

## Skills

Load skills on demand; see `.agents/skills/README.md` for grouping.

| Skill                                                                                | When to use                                               |
| ------------------------------------------------------------------------------------ | --------------------------------------------------------- |
| [qml-architecture](.agents/skills/qml-architecture/SKILL.md)                         | QML file layout, imports, and module boundaries           |
| [qml-state](.agents/skills/qml-state/SKILL.md)                                       | Settings, persistence, shared state, and service behavior |
| [qml-components](.agents/skills/qml-components/SKILL.md)                             | Tokens, semantic colors, and base surface patterns        |
| [qml-context-menu](.agents/skills/qml-context-menu/SKILL.md)                         | Bar, tray, and submenu menus                              |
| [qml-token-cleanup](.agents/skills/qml-token-cleanup/SKILL.md)                       | Replacing hardcoded geometry with shared tokens           |
| [qml-visual-language](.agents/skills/qml-visual-language/SKILL.md)                   | Visual identity and cross-component consistency           |
| [qml-indicator-motion](.agents/skills/qml-indicator-motion/SKILL.md)                 | Active indicators and sliding highlights                  |
| [visual-vs-layout-motion-ownership](.agents/skills/visual-vs-layout-motion-ownership/SKILL.md) | Separating visible motion from exported layout geometry   |
| [qml-motion-debug](.agents/skills/qml-motion-debug/SKILL.md)                         | Motion looks wrong even though state changes              |
| [exported-layout-width-ownership](.agents/skills/exported-layout-width-ownership/SKILL.md) | Visible width vs reserved layout width synchronization    |
| [multi-surface-semantic-ownership](.agents/skills/multi-surface-semantic-ownership/SKILL.md) | Root, shell, and content ownership across attached surfaces |
| [runtime-cleanup-chain-interruptions](.agents/skills/runtime-cleanup-chain-interruptions/SKILL.md) | Cleanup callbacks or imports break, so local state resets but stale outer reservation/state survives |
| [baseline-cache-before-transition](.agents/skills/baseline-cache-before-transition/SKILL.md) | Cache a stable pre-transition baseline before live fallback values invalidate on mode entry |
| [single-instance-handoff-motion](.agents/skills/single-instance-handoff-motion/SKILL.md) | Teleport/duplicate-safe cross-host handoff motion         |
| [split-host-exit-synchronization](.agents/skills/split-host-exit-synchronization/SKILL.md) | Synchronizing exit timing across separate geometry owners |
| [list-transition-handoffs](.agents/skills/list-transition-handoffs/SKILL.md)         | Animated list replacement and filter handoffs             |
| [qml-performance-debug](.agents/skills/qml-performance-debug/SKILL.md)               | Jank, frame drops, and layout thrash                      |
| [session-latched-display-state](.agents/skills/session-latched-display-state/SKILL.md) | Stable display state under sparse or weak updates         |
| [weak-signal-bridge-normalization](.agents/skills/weak-signal-bridge-normalization/SKILL.md) | Normalizing incomplete bridge payloads before app state   |
| [reference-attribution](.agents/skills/reference-attribution/SKILL.md)               | Adapting patterns from another repo                       |
| [contour-anchor-before-radius](.agents/skills/contour-anchor-before-radius/SKILL.md) | Fixing bridge silhouette by anchor before radius tuning   |
| [shared-summary-model-delegates](.agents/skills/shared-summary-model-delegates/SKILL.md) | Per-item overview delegates backed by one summary model   |

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
