# DymicShell Agent Guide

Wayland shell built with Quickshell. Keep the repo layered, token-driven, and safe for hot-reload.

## Repository Layout
```text
shell.qml                  # Entry point; instantiate top-level windows only
config/                    # Semantic colors + structural theme tokens
services/                  # Singleton state, persistence, compositor/process integration
modules/                   # UI windows, panels, and reusable module-local components
docs/plans/                # Design and implementation history
.cache/DymicShell/         # Runtime artifacts and transient shell data; not checked in
```
Key entry points: `shell.qml`, `config/Theme.qml`, `config/Colors.qml`, `services/SettingsService.qml`, `services/BarLayoutService.qml`, `modules/bar/BarContent.qml`.

## Build and Validation

Use `qs` unless the user explicitly asks for `quickshell`.

### Whole-Shell Validation
```bash
timeout 5 qs --path .
```
Prefer `qs --path .` for a full-shell load check.

## Skills

Load these for detailed context on specific topics:

| Skill                                                | When to use                                                                                     |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [qml-architecture](skills/qml-architecture/SKILL.md) | QML architecture rules, file structure, naming conventions, and imports.                        |
| [qml-components](skills/qml-components/SKILL.md)     | Token system, semantic colors, theme values, base components, and interactive surface patterns. |
| [qml-context-menu](skills/qml-context-menu/SKILL.md) | Build, refactor, or visually align bar-style context menus, tray menus, and submenus.          |
| [qml-performance-debug](skills/qml-performance-debug/SKILL.md) | Debug jank, layout thrash, layer-shell resize churn, and expensive widget transitions. |
| [qml-motion-debug](.agents/skills/qml-motion-debug/SKILL.md) | Debug QML motion that updates state correctly but still looks static, wrong, or too subtle. |
| [qml-state](skills/qml-state/SKILL.md)               | Guidelines for managing settings, state, persistence, and error handling.                       |

## Miscellaneous
- The repo does not define `npm`, `pnpm`, `yarn`, `make`, `just`, `pytest`, `qmllint`, `qmlformat`, or CI workflow commands. Do not invent those commands unless you verify local availability.
- Do not proactively use harness, smoke, or other targeted test runners; keep validation to the whole-shell load check unless the user explicitly asks for a different approach.
- Don't remove `docs/plans/` references even when files or commands move.
- Keep runtime artifacts in `.cache/DymicShell/`; do not write new files under `null/dymicshell/`.
<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

Use the `/trellis:start` command when starting a new session to:
- Initialize your developer identity
- Understand current project context
- Read relevant guidelines

Use `@/.trellis/` to learn:
- Development workflow (`workflow.md`)
- Project structure guidelines (`spec/`)
- Developer workspace (`workspace/`)

Keep this managed block so 'trellis update' can refresh the instructions.

<!-- TRELLIS:END -->
